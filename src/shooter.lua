--[[
Twin stick shooter, like blops arcade.
--]]


local DEADZONE_TOLERANCE = 0.2
local MOVE_SPEED = 200

-- Used inside weapons, can't be local.
PHYS_CATEGORY_WALL = 1      -- UserData = nil
PHYS_CATEGORY_PLAYER = 2    -- UserData = player
PHYS_CATEGORY_ENEMY = 3     -- UserData = ???
PHYS_CATEGORY_BULLET = 4    -- UserData = bullet



-- Weapons.
local weapons = require("src/weapons")



-- Player infos.
local playerMake = function(id, x,y, world)
    local body = love.physics.newBody(world, x,y, "dynamic")
    local shape = love.physics.newCircleShape(20)
    local fixture = love.physics.newFixture(body, shape)

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



-- Physics.
local physBeginContact = function(self, fixA, fixB, contact)
    -- Note: can't modify world here, so need to remove stuff in the update loop.

    local catA = fixA:getCategory()
    local catB = fixB:getCategory()
    local udA = fixA:getUserData()
    local udB = fixB:getUserData()

    if catA == PHYS_CATEGORY_BULLET and catB == PHYS_CATEGORY_WALL then
        udA.hit = true
    elseif catA == PHYS_CATEGORY_WALL and catB == PHYS_CATEGORY_BULLET then
        udB.hit = true
    else
        print("collided:", catA, catB)
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

        -- Angle.
        local ax,ay = js:getGamepadAxis("rightx"), js:getGamepadAxis("righty")
        if not inDeadzone(ax, ay) then
            player.angle = math.atan2(ay, ax)
        end

        -- Movement.
        local vx,vy = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if not inDeadzone(vx, vy) then
            local x,y = player.body:getX(),player.body:getY()
            x = x + MOVE_SPEED * vx * dt
            y = y + MOVE_SPEED * vy * dt
            player.body:setPosition(x, y)
        end

        -- Gun.
        local gun = player.powerUpWeapon or player.defaultWeapon
        local empty = gun:update(dt)
        if empty then
            player.powerUpWeapon = nil
            gun = player.defaultWeapon
        end

        local firing = js:isGamepadDown("rightshoulder")
        if firing then
            gun:tryShoot(self.bullets, player.body:getX(),player.body:getY(), player.angle)
        end
    end

    -- Physics.
    self.world:update(dt)

    -- Spawn new enemies.
    -- TODO

    -- Move enemies.
    -- TODO

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

    -- Render bullets.
    for _,bullet in pairs(self.bullets) do
        bullet:draw()
    end
    for _,impact in pairs(self.impacts) do
        impact:draw()
    end

    -- Render overlays.
    -- TODO

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
    game.world:setCallbacks(function(a,b,c) physBeginContact(self,a,b,c) end, nil, nil, nil)
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

    -- Game state.
    game.enemies = {}
    game.bullets = {}
    game.impacts = {}
    game.revives = 4
    game.exit = false

    return game
end

return new
