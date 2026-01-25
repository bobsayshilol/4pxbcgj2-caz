--[[
Twin stick shooter, like blops arcade.
--]]


local DEADZONE_TOLERANCE = 0.2
local MOVE_SPEED = 200
local SCORE_PER_REVIVE = 25000

-- Used inside weapons, can't be local.
PHYS_CATEGORY_WALL = 1      -- UserData = nil
PHYS_CATEGORY_PLAYER = 2    -- UserData = player
PHYS_CATEGORY_ENEMY = 3     -- UserData = enemy
PHYS_CATEGORY_BULLET = 4    -- UserData = bullet
PHYS_CATEGORY_PICKUP = 5    -- UserData = type



-- Weapons.
local weapons = require("src/weapons")
local enemyManager = require("src/enemies")

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
            game.powerUps.nuke = { time = 0 }
        end,
    },
    {
        text = "revive",
        apply = function(game, player)
            game.powerUps.revive = { time = 0 }
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
local playerMake = function(id, x,y, world)
    local body = love.physics.newBody(world, x,y, "dynamic")
    local shape = love.physics.newCircleShape(20)
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

local gameAddScore = function(game, pid, score)
    if game.powerUps.doublePoints then
        score = score * 2
    end

    -- Add to player's score.
    local player = game.players[pid]
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
    local lastKill = game.enemyManager.enemiesRemaining == 0

    -- Random chance to drop something.
    local oneInN = 50
    if lastKill or love.math.random(oneInN - 1) == 1 then
        -- Pick a random powerup.
        local idx = love.math.random(#s_powerUps)
        local powerUp = s_powerUps[idx]

        -- Spawn it.
        local body = love.physics.newBody(game.world, enemy.body:getX(),enemy.body:getY(), "static")
        local fixture = love.physics.newFixture(body, love.physics.newCircleShape(20))

        -- We're a pickup, and we collide with players only.
        fixture:setCategory(PHYS_CATEGORY_PICKUP)
        fixture:setMask(PHYS_CATEGORY_WALL, PHYS_CATEGORY_ENEMY, PHYS_CATEGORY_BULLET, PHYS_CATEGORY_PICKUP)

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



-- Physics.
local physBeginContact = function(self, fixA, fixB, contact)
    -- Note: can't modify world here, so need to remove stuff in the update loop.

    local catA = fixA:getCategory()
    local catB = fixB:getCategory()
    -- Make sure catA<=catB so we only need to do half of the checks.
    if catA > catB then
        fixA,fixB,catA,catB = fixB,fixA,catB,catA
    end

    local udA = fixA:getUserData()
    local udB = fixB:getUserData()

    if catA == PHYS_CATEGORY_WALL and catB == PHYS_CATEGORY_BULLET then
        udB.hit = true

    elseif catA == PHYS_CATEGORY_ENEMY and catB == PHYS_CATEGORY_BULLET then
        udB.hit = true
        if self.powerUps.instakill then
            udA.health = -1
        else
            udA.health = udA.health - udB.damage
        end

        local score = udA.health < 0 and 105 or 5
        gameAddScore(self, udB.pid, score)

    elseif catA == PHYS_CATEGORY_PLAYER and catB == PHYS_CATEGORY_PICKUP then
        udB.player = udA

    else
        --print("collided:", catA, catB)
    end
end
--local physEndContact = function(fixA, fixB, contact) end
--local physPreSolve = function(fixA, fixB, contact) end
--local physPostSolve = function(fixA, fixB, contact, normalimpulse, tangentimpulse) end



-- Callbacks.

local update = function(self, dt)
    -- Check for game over.
    if self.exit then
        return "menu"
    end

    -- Input.
    for pid,player in ipairs(self.players) do
        local js = g_globals.pidToJs[pid]

        local firing = js:isGamepadDown("rightshoulder")

        -- Angle.
        local ax,ay = js:getGamepadAxis("rightx"), js:getGamepadAxis("righty")
        if not inDeadzone(ax, ay) then
            player.angle = math.atan2(ay, ax)
        end

        -- Movement.
        local vx,vy = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if not inDeadzone(vx, vy) then
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
    local over = not self.enemyManager:update(dt)
    if over then
        self.enemyManager:newRound()
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
    if pups.nuke then self.enemyManager:killAll() end
    if pups.revive then self.revives = self.revives + 1 end
    for k,pu in pairs(pups) do
        pu.time = pu.time - dt
        if pu.time < 0 then
            pups[k] = nil
        end
    end

    return nil
end

local gamepadpressed = function(self, js, button)
    local playerID = g_globals.jsToPlayerID[js]
    local player = self.players[playerID]
    if not player then return end

    -- TODO
end

local debugDraw = function(world)
    love.graphics.setColor(1,0,0,1)
    for _, body in pairs(world:getBodies()) do
        for _, fixture in pairs(body:getFixtures()) do
            local shape = fixture:getShape()
            if shape:typeOf("CircleShape") then
                local cx, cy = body:getWorldPoints(shape:getPoint())
                love.graphics.circle("line", cx, cy, shape:getRadius())
            elseif shape:typeOf("PolygonShape") then
                love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
            else
                love.graphics.line(body:getWorldPoints(shape:getPoints()))
            end
        end
    end
end

local draw = function(self)
    -- Clear screen.
    love.graphics.clear(0, 0, 0, 1)

    local screenW,screenH = love.graphics.getWidth(),love.graphics.getHeight()

    -- Render map.
    -- TODO

    -- Render players.
    for pid,player in ipairs(self.players) do
        -- TODO
        love.graphics.setColor(1,1,1,1)
        local x,y = player.body:getX(),player.body:getY()
        love.graphics.print("Gun " .. player.id, x,y, player.angle)
        love.graphics.circle("fill", x,y, player.shape:getRadius())
    end

    -- Render pickups.
    for _,pickup in pairs(self.pickups) do
        love.graphics.print(pickup.powerUp.text, pickup.body:getX(),pickup.body:getY())
    end

    -- Render enemies.
    self.enemyManager:draw()

    -- Render bullets.
    for _,bullet in pairs(self.bullets) do
        bullet:draw()
    end
    for _,impact in pairs(self.impacts) do
        impact:draw()
    end

    -- Render overlays.
    love.graphics.setColor(1,1,1,1)
    love.graphics.print("Round " .. self.enemyManager.round, screenW/2,screenH*2/20)
    love.graphics.print("Remaining " .. self.enemyManager.enemiesRemaining, screenW/2,screenH*3/20)
    love.graphics.print("Revives " .. self.revives, screenW/2,screenH*4/20)

    local p = 0.1
    local corners = {
        {p*screenW, p*screenH},
        {(1-p)*screenW, p*screenH},
        {p*screenW, (1-p)*screenH},
        {(1-p)*screenW, (1-p)*screenH},
    }
    for pid,player in ipairs(self.players) do
        love.graphics.print(pid .. ": " .. player.health .. " " .. player.score, corners[pid][1], corners[pid][2])
    end

    --debugDraw(self.world)
end



local new = function()
    local game = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,
    }

    local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()

    -- Create the play area.
    -- TODO: move this
    game.world = love.physics.newWorld(0, 0, false) -- sleeping bodies breaks collisions for some reason
    game.world:setCallbacks(function(a,b,c) physBeginContact(game,a,b,c) end, nil, nil, nil)
    if true then
        -- Border
        local border = love.physics.newBody(game.world, 0,0, "static")
        local addBorder = function(x0,y0, x1,y1)
            local fixture = love.physics.newFixture(border, love.physics.newEdgeShape(x0,y0, x1,y1))
            -- We're a wall, and we collide with everything.
            fixture:setCategory(PHYS_CATEGORY_WALL)
        end
        local p = 100
        addBorder(p,p, p,sh-p)
        addBorder(p,p, sw-p,p)
        addBorder(p,sh-p, sw-p,sh-p)
        addBorder(sw-p,p, sw-p,sh-p)

        -- TODO: more objects
        local rock = love.physics.newBody(game.world, sw/2,sh/2, "static")
        love.physics.newFixture(rock, love.physics.newRectangleShape(sw/8,sh/4)):setCategory(PHYS_CATEGORY_WALL)
    end

    -- Add players.
    game.players = {}
    local numPlayers = utils.size(g_globals.jsToPlayerID)
    if numPlayers > 0 then game.players[1] = playerMake(1, 0.25*sw,0.25*sh, game.world) end
    if numPlayers > 1 then game.players[2] = playerMake(2, 0.75*sw,0.25*sh, game.world) end
    if numPlayers > 2 then game.players[3] = playerMake(3, 0.25*sw,0.75*sh, game.world) end
    if numPlayers > 3 then game.players[4] = playerMake(4, 0.75*sw,0.75*sh, game.world) end

    -- Enemies.
    local spawners = {}
    if true then
        -- TODO: part of the map
        local addSpawner = function(x,y, rot)
            local spawner = {
                x = x,
                y = y,
                nextTime = 0,
            }
            local body = love.physics.newBody(game.world, spawner.x,spawner.y, "static")
            local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(sw/16,sh/16))
            fixture:setCategory(PHYS_CATEGORY_WALL)
            spawner.body = body
            local rots = { {0,-sh/16}, {sw/16,0}, {0,sh/16}, {-sw/16,0} } -- faces NESW
            local r = rots[rot]
            spawner.entrance = love.physics.newBody(game.world, spawner.x+r[1],spawner.y+r[2], "static")
            table.insert(spawners, spawner)
        end

        addSpawner(1*sw,0.4*sh, 4)
        addSpawner(0*sw,0.6*sh, 2)
        addSpawner(0.3*sw,1*sh, 1)
        addSpawner(0.7*sw,1*sh, 1)
        addSpawner(0.6*sw,0*sh, 3)
    end
    local onKill = function(x,y) gameEnemyKilled(game, x,y) end
    game.enemyManager = enemyManager.new(game.world, game.players, spawners, onKill)

    -- Game state.
    game.bullets = {}
    game.impacts = {}
    game.powerUps = {}
    game.pickups = {}
    game.revives = 4
    game.scoreUntilNextRevive = SCORE_PER_REVIVE
    game.exit = false

    -- TODO: pause states between rounds
    game.enemyManager:newRound()

    return game
end

return new
