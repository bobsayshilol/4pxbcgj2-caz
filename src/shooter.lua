--[[
Twin stick shooter, like blops arcade.
--]]


local DEADZONE_TOLERANCE = 0.2
local MOVE_SPEED = 200
local SCORE_PER_REVIVE = 25000
local DROP_AFTER_MIN = 20
local DROP_AFTER_MAX = 50

-- Used inside weapons, can't be local.
PHYS_CATEGORY_WALL = 1      -- UserData = nil
PHYS_CATEGORY_HOLE = 2      -- UserData = nil
PHYS_CATEGORY_PLAYER = 3    -- UserData = player
PHYS_CATEGORY_ENEMY = 4     -- UserData = enemy
PHYS_CATEGORY_BULLET = 5    -- UserData = bullet
PHYS_CATEGORY_PICKUP = 6    -- UserData = type

local STAGE_BREATHER = 1
local STAGE_FIGHTING = 2
local STAGE_DEAD = 3
local STAGE_OVER = 4
local STAGE_CHANGE_MAP_OUT = 5
local STAGE_CHANGE_MAP_IN = 6

local CHANGE_MAP_FADE_TIME = 4
local CHANGE_MAP_EVERY = 10
local BREATHER_TIME = 5


-- Weapons.
local weapons = require("src/weapons")
local enemyManager = require("src/enemies")
local maps = require("src/map")



-- Power ups.
local POWERUP_DISPLAY_FOR = 8
local s_powerUps = {
    {
        text = "double points", -- TODO: sprites
        apply = function(game, player)
            game.powerUps.doublePoints = { time = 12 }
        end,
    },
    {
        text = "instakill",
        apply = function(game, player)
            game.powerUps.instakill = { time = 10 }
        end,
    },
    {
        text = "nuke",
        apply = function(game, player)
            game.enemyManager:killAll()
            for _,p in ipairs(game.players) do
                game:addScore(p, 500)
            end
        end,
    },
    {
        text = "revive",
        apply = function(game, player)
            game.revives = game.revives + 1
        end,
    },
    {
        text = "heal",
        apply = function(game, player)
            for _,p in ipairs(game.players) do
                if p.health > 0 then
                    p.health = 100
                end
            end
        end,
    },
    {
        text = "minigun",
        apply = function(game, player)
            player.powerUpWeapon = weapons.new(game.world, weapons.types.Minigun, player.id)
        end,
    },
    {
        text = "rpg",
        apply = function(game, player)
            player.powerUpWeapon = weapons.new(game.world, weapons.types.RPG, player.id)
        end,
    },
}



-- Player infos.
local playerMake = function(id, world)
    local body = love.physics.newBody(world, 0,0, "dynamic")
    local shape = love.physics.newCircleShape(love.graphics.getWidth() / 75)
    local fixture = love.physics.newFixture(body, shape, 100)

    -- We'll update the position manually.
    body:setFixedRotation(true)
    body:setLinearDamping(1)

    -- We're a player, and we collide with everything except bullets.
    fixture:setCategory(PHYS_CATEGORY_PLAYER)
    fixture:setMask(PHYS_CATEGORY_BULLET)

    local player = {
        id = id,

        body = body,
        shape = shape,
        fixture = fixture,

        angle = 0,

        score = 0,
        kills = 0,
        health = 100,
        defaultWeapon = weapons.new(world, weapons.types.SMG, id),
        powerUpWeapon = nil,
    }

    -- Store the player in the ud.
    fixture:setUserData(player)

    return player
end



-- Utils.
local inDeadzone = function(x,y)
    return (math.abs(x) < DEADZONE_TOLERANCE) and (math.abs(y) < DEADZONE_TOLERANCE)
end

local gameAddScore = function(game, player, score)
    if game.powerUps.doublePoints then
        score = score * 2
    end

    -- Add to player's score.
    player.score = player.score + score

    -- Add an extra revive.
    game.scoreUntilNextRevive = game.scoreUntilNextRevive - score
    if game.scoreUntilNextRevive < 0 then
        game.scoreUntilNextRevive = SCORE_PER_REVIVE
        game.revives = game.revives + 1
    end
end

local gameEnemyKilled = function(game, enemy)
    -- Last enemy always drops something.
    local shouldDrop = game.enemyManager.enemiesRemaining == 0

    -- Random chance to drop something too.
    if not shouldDrop then
        game.nextDrop = game.nextDrop - 1
        if game.nextDrop == 0 then
            game.nextDrop = love.math.random(DROP_AFTER_MIN, DROP_AFTER_MAX)
            shouldDrop = true
        end
    end

    if shouldDrop then
        -- Pick a random powerup.
        local idx = love.math.random(#s_powerUps)
        local powerUp = s_powerUps[idx]

        -- Spawn it.
        local body = love.physics.newBody(game.world, enemy.body:getX(),enemy.body:getY(), "static")
        local fixture = love.physics.newFixture(body, love.physics.newCircleShape(love.graphics.getWidth() / 75))

        -- We're a pickup, and we collide with players only.
        fixture:setCategory(PHYS_CATEGORY_PICKUP)
        fixture:setMask(PHYS_CATEGORY_WALL, PHYS_CATEGORY_HOLE, PHYS_CATEGORY_ENEMY, PHYS_CATEGORY_BULLET, PHYS_CATEGORY_PICKUP)

        -- We're only for detection, no physics.
        fixture:setSensor(true)

        local pickup = {
            powerUp = powerUp,

            body = body,

            time = POWERUP_DISPLAY_FOR,
            player = nil, -- set when player picks this up
        }
        table.insert(game.pickups, pickup)
        fixture:setUserData(pickup)
    end
end

local gameChangeMap = function(self)
    -- Bin the old one.
    if self.map then
        self.map:destroy()
    end

    -- Clear up any markers and drops.
    for k,bullet in pairs(self.bullets) do
        bullet:destroy(self.impacts)
        self.bullets[k] = nil
    end
    for k,impact in pairs(self.impacts) do
        self.impacts[k] = nil
    end
    for k,pu in pairs(self.pickups) do
        pu.body:destroy()
        self.pickups[k] = nil
    end

    -- Cycle to next map.
    local all = maps.all
    local idx = self.mapIdx + 1
    if idx > #all then idx = 1 end

    local map = maps.new(self.world, all[idx])
    self.map = map
    self.mapIdx = idx

    -- Move players to the new spawns.
    local sp = map.spawnPoints
    for pid,player in ipairs(self.players) do
        local spp = sp[pid]
        player.body:setPosition(spp[1],spp[2])
    end
    self.enemyManager:changeMap(map)
end



-- Physics.
local physBeginContact = function(self, fixA, fixB, contact)
    -- Note: can't modify world here, so need to remove stuff in the update loop.

    local catA = fixA:getCategory()
    local catB = fixB:getCategory()
    -- Make sure catA<=catB so we only need to do half of the checks.
    if catA > catB then
        fixA,fixB,catA,catB = fixB,fixA,catB,catA
    end

    if catA == PHYS_CATEGORY_WALL and catB == PHYS_CATEGORY_BULLET then
        local bullet = fixB:getUserData()
        bullet.hit = true

    elseif catA == PHYS_CATEGORY_ENEMY and catB == PHYS_CATEGORY_BULLET then
        local enemy = fixA:getUserData()
        local bullet = fixB:getUserData()

        bullet.hit = true
        if self.powerUps.instakill then
            enemy.health = -1
        else
            enemy.health = enemy.health - bullet.damage
        end

        local player = self.players[bullet.pid]
        local dead = enemy.health < 0
        gameAddScore(self, player, dead and 105 or 5)

        if dead then
            player.kills = player.kills + 1
        end

    elseif catA == PHYS_CATEGORY_PLAYER and catB == PHYS_CATEGORY_PICKUP then
        local player = fixA:getUserData()
        local pickup = fixB:getUserData()

        pickup.player = player

    elseif catA == PHYS_CATEGORY_PLAYER and catB == PHYS_CATEGORY_ENEMY then
        local player = fixA:getUserData()
        local enemy = fixB:getUserData()

        enemy.damaging[player] = true

    else
        --print("collided:", catA, catB)
    end
end

local physEndContact = function(self, fixA, fixB, contact)
    -- Note: can't modify world here, so need to remove stuff in the update loop.

    local catA = fixA:getCategory()
    local catB = fixB:getCategory()
    -- Make sure catA<=catB so we only need to do half of the checks.
    if catA > catB then
        fixA,fixB,catA,catB = fixB,fixA,catB,catA
    end

    if catA == PHYS_CATEGORY_PLAYER and catB == PHYS_CATEGORY_ENEMY then
        local player = fixA:getUserData()
        local enemy = fixB:getUserData()

        enemy.damaging[player] = nil

    end
end



-- Callbacks.

local update = function(self, dt)
    -- Check for game over.
    local fighting = false
    do
        local stage = self.stage
        self.stageTimer = self.stageTimer + dt
        if stage == STAGE_BREATHER then
            if self.stageTimer > BREATHER_TIME then
                self.stageTimer = 0
                self.enemyManager:newRound()
                self.stage = STAGE_FIGHTING
            end

        elseif stage == STAGE_CHANGE_MAP_OUT then
            if self.stageTimer > CHANGE_MAP_FADE_TIME then
                gameChangeMap(self)
                self.stageTimer = 0
                self.stage = STAGE_CHANGE_MAP_IN
            end
        elseif stage == STAGE_CHANGE_MAP_IN then
            if self.stageTimer > CHANGE_MAP_FADE_TIME then
                -- Jump straight to finished breather.
                self.stageTimer = BREATHER_TIME
                self.stage = STAGE_BREATHER
            end

        elseif stage == STAGE_DEAD then
            if self.stageTimer > 10 then
                self.stageTimer = 0
                self.stage = STAGE_OVER
            end

        elseif stage == STAGE_OVER then
            return "menu"

        else
            fighting = true

        end
    end

    -- Input.
    for pid,player in ipairs(self.players) do
        local isDead = player.health <= 0
        local js = g_globals.pidToJs[pid]

        local firing = js:isGamepadDown("rightshoulder") and not isDead

        -- Angle.
        local ax,ay = js:getGamepadAxis("rightx"), js:getGamepadAxis("righty")
        if not inDeadzone(ax, ay) then
            player.angle = math.atan2(ay, ax)
        end

        -- Movement.
        local vx,vy = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if not inDeadzone(vx, vy) and not isDead then
            local speed = MOVE_SPEED
            --if firing then speed = speed * 0.75 end

            local len = math.sqrt(vx * vx + vy * vy)
            local x,y = player.body:getX(),player.body:getY()
            local vvx = speed * vx / len
            local vvy = speed * vy / len
            player.body:setLinearVelocity(vvx, vvy)
        else
            player.body:setLinearVelocity(0, 0)
        end

        -- Gun.
        local gun = player.powerUpWeapon or player.defaultWeapon
        local empty = gun:update(dt)
        if empty then
            player.powerUpWeapon = nil
            gun = player.defaultWeapon
        end

        if firing then
            gun:tryShoot(self.bullets, player.body:getX(),player.body:getY(), player.angle)
        end
    end

    -- Physics.
    self.world:update(dt)

    -- Remove bullets.
    for k,impact in pairs(self.impacts) do
        impact.displaying = impact.displaying - dt
        if impact.displaying < 0 then
            self.impacts[k] = nil
        end
    end
    for k,bullet in pairs(self.bullets) do
        if bullet.hit then
            bullet:destroy(self.impacts)
            self.bullets[k] = nil -- apparently this is safe
        end
    end

    -- Enemies.
    if fighting then
        local over = not self.enemyManager:update(dt)
        if over then
            if (self.enemyManager.round % CHANGE_MAP_EVERY) == 0 then
                self.stage = STAGE_CHANGE_MAP_OUT
            else
                self.stage = STAGE_BREATHER
            end
            self.stageTimer = 0
        end
    end

    -- Pickups.
    for k,pu in pairs(self.pickups) do
        pu.time = pu.time - dt
        local player = pu.player
        if player then
            pu.powerUp.apply(self, player)
        end
        if player or pu.time < 0 then
            pu.body:destroy()
            self.pickups[k] = nil
        end
    end

    -- Power ups.
    local pups = self.powerUps
    for k,pu in pairs(pups) do
        pu.time = pu.time - dt
        if pu.time < 0 then
            pups[k] = nil
        end
    end

    -- Check for player deaths.
    if fighting then
        local allDead = self.revives == 0
        for _,player in ipairs(self.players) do
            if player.health <= 0 then
                player.health = 0
            else
                allDead = false
            end
        end
        if allDead then
            self.stage = STAGE_DEAD
            self.stageTimer = 0
        end
    end

    return nil
end

local gamepadpressed = function(self, js, button)
    local playerID = g_globals.jsToPlayerID[js]
    local player = self.players[playerID]
    if not player then return end

    if button == "leftshoulder" and player.health <= 0 and self.revives > 0 then
        self.revives = self.revives - 1
        player.health = 100
    end
end

local debugDraw = function(self)
    local lg = love.graphics
    local world = self.world
    lg.setColor(1,0,0,1)
    for _, body in pairs(world:getBodies()) do
        for _, fixture in pairs(body:getFixtures()) do
            local shape = fixture:getShape()
            if shape:typeOf("CircleShape") then
                local cx, cy = body:getWorldPoints(shape:getPoint())
                lg.circle("line", cx, cy, shape:getRadius())
            elseif shape:typeOf("PolygonShape") then
                lg.polygon("line", body:getWorldPoints(shape:getPoints()))
            else
                lg.line(body:getWorldPoints(shape:getPoints()))
            end
        end
    end

    local navMeshDists = self.enemyManager.navMeshDists
    if navMeshDists then
        local navMesh = self.map.navMesh
        local N = #navMeshDists
        for i=1,N do
            local c = navMesh[i][1]
            local d = math.floor(navMeshDists[i])
            lg.print(d, c[1],c[2])
        end
    end
end

local draw = function(self)
    local lg = love.graphics

    -- Clear screen.
    lg.clear(0, 0, 0, 1)

    local screenW,screenH = lg.getWidth(),lg.getHeight()
    local players = self.players
    local numPlayers = #players

    -- World rendering start.
    lg.push()

    local avgX,avgY = 0,0
    for pid=1,numPlayers do
        local body = players[pid].body
        local x,y = body:getX(),body:getY()
        x = x/screenW - 0.5
        y = y/screenH - 0.5
        avgX = avgX + x / numPlayers
        avgY = avgY + y / numPlayers
    end

    -- Zoom in a bit and follow the players.
    -- HACK: this feels like the wrong order of operations, but it works
    lg.translate(screenW/2,screenH/2)
    lg.scale(1.1)
    lg.translate(-screenW/2,-screenH/2)
    local mapX,mapY = -avgX*screenW/10,-avgY*screenH/10
    lg.translate(mapX,mapY)

    -- Render map background.
    self.map:drawBack(mapX,mapY)

    -- Render players.
    local pCols = g_globals.playerCols
    for pid,player in ipairs(players) do
        -- TODO
        local col = pCols[pid]
        lg.setColor(col[1],col[2],col[3])
        local x,y = player.body:getX(),player.body:getY()
        lg.print("Gun " .. player.id, x,y, player.angle)
        lg.circle("fill", x,y, player.shape:getRadius())
    end

    -- Render pickups.
    for _,pickup in pairs(self.pickups) do
        lg.print(pickup.powerUp.text .. " " .. math.floor(pickup.time), pickup.body:getX(),pickup.body:getY())
    end

    -- Render enemies.
    self.enemyManager:draw()

    -- Render over players.
    self.map:drawFront()

    -- Render bullets.
    lg.setColor(1,1,1)
    for _,bullet in pairs(self.bullets) do
        bullet:draw()
    end
    for _,impact in pairs(self.impacts) do
        impact:draw()
    end

    -- World rendering end.
    lg.pop()



    -- Apply fade if changing level.
    if self.stage == STAGE_CHANGE_MAP_OUT or self.stage == STAGE_CHANGE_MAP_IN then
        local t = self.stageTimer / CHANGE_MAP_FADE_TIME
        if self.stage == STAGE_CHANGE_MAP_IN then t = 1 - t end
        lg.setColor(0,0,0,t)
        lg.rectangle("fill", 0,0, screenW,screenH)
    end

    -- Render overlays.
    lg.setColor(1,1,1,1)
    lg.print("Round " .. self.enemyManager.round, screenW/2,screenH*2/20)
    lg.print("Remaining " .. self.enemyManager.enemiesRemaining, screenW/2,screenH*3/20)
    lg.print("Revives " .. self.revives, screenW/2,screenH*4/20)

    local p = 0.1
    local corners = {
        {p*screenW, p*screenH},
        {(1-p)*screenW, p*screenH},
        {p*screenW, (1-p)*screenH},
        {(1-p)*screenW, (1-p)*screenH},
    }
    for pid,player in ipairs(players) do
        lg.print(pid .. ": " .. player.health .. " " .. player.kills .. " " .. player.score, corners[pid][1], corners[pid][2])
    end

    do
        local stage = self.stage
        if stage == STAGE_FIGHTING and self.stageTimer < 3 then
            lg.print("ROUND " .. self.enemyManager.round, screenW/2,screenH/2, 0, 5)
        elseif stage == STAGE_DEAD then
            lg.print("GAME OVER", screenW/2,screenH/4, 0, 5)
            local y = screenH/3
            lg.print("Player | Kills | Score", screenW/2,y, 0, 3)
            y = y + 50
            for pid,player in ipairs(players) do
                lg.print(pid .. " | " .. player.kills .. " | " .. player.score, screenW/2,y, 0, 3)
                y = y + 50
            end
            y = y + 50
            lg.print("Made it to round " .. self.enemyManager.round, screenW/2,y, 0, 2)
        end
    end

    if g_debugging then
        debugDraw(self)
    end
end



local new = function()
    local game = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,

        addScore = gameAddScore,
    }

    -- Create the play area.
    game.world = love.physics.newWorld(0, 0, false) -- sleeping bodies breaks collisions for some reason
    game.world:setCallbacks(
        function(a,b,c) physBeginContact(game,a,b,c) end,
        function(a,b,c) physEndContact(game,a,b,c) end,
        nil, nil
    )

    -- Add players.
    game.players = {}
    local numPlayers = utils.size(g_globals.jsToPlayerID)
    for i=1,numPlayers do
        game.players[i] = playerMake(i, game.world)
    end

    -- Enemies.
    local onKill = function(x,y) gameEnemyKilled(game, x,y) end
    game.enemyManager = enemyManager.new(game.world, game.players, onKill)

    -- Game state.
    game.bullets = {}
    game.impacts = {}
    game.powerUps = {}
    game.pickups = {}
    game.revives = numPlayers
    game.scoreUntilNextRevive = SCORE_PER_REVIVE
    game.stage = STAGE_BREATHER
    game.stageTimer = 0
    game.nextDrop = love.math.random(DROP_AFTER_MIN, DROP_AFTER_MAX)

    -- Go to the first map.
    game.mapIdx = 0
    gameChangeMap(game)

    return game
end

return new
