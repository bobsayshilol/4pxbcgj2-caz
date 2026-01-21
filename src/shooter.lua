--[[
Twin stick shooter, like blops arcade.
--]]


local DEADZONE_TOLERANCE = 0.2
local MOVE_SPEED = 0.1



-- Weapons.
local WeaponTypes = {
    
}



-- Player infos.
local playerMake = function(id, x, y)
    local player = {
        id = id,
        worldX = x,
        worldY = y,
        angle = 0,

        score = 0,
        health = 100,
        weapon = nil, -- TODO
    }
    return player
end



-- Utils.
local inDeadzone = function(x,y)
    return (math.abs(x) < DEADZONE_TOLERANCE) and (math.abs(y) < DEADZONE_TOLERANCE)
end



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
            player.worldX = player.worldX + MOVE_SPEED * vx * dt
            player.worldY = player.worldY + MOVE_SPEED * vy * dt
            -- TODO: collisions
        end

        -- Gun.
        local firing = js:isGamepadDown("rightshoulder")
        if firing then -- and player.gun:canFire()
            -- TODO
        end
    end

    -- Spawn new enemies.
    -- TODO

    -- Move enemies.
    -- TODO

    -- Move bullets.
    local deadBullets = {}
    for k,bullet in pairs(self.bullets) do
        -- TODO
    end
    for k,bullet in pairs(deadBullets) do
        -- TODO
        self.bullets[k] = nil
    end

    return nil
end

local gamepadpressed = function(self, js, button)
    local playerID = g_globals.jsToPlayerID[js]
    local player = self.players[playerID]
    if not player then return end

    -- TODO
end

local draw = function(self)
    -- Clear screen.
    love.graphics.clear(0, 0, 0, 1)

    local screenW,screenH = love.graphics.getWidth(),love.graphics.getHeight()

    -- Render map.
    -- TODO

    -- Render bullets.
    for _,bullet in pairs(self.bullets) do
        -- TODO
    end

    -- Render players.
    for pid,player in ipairs(self.players) do
        -- TODO
        love.graphics.setColor(1,1,1,1)
        love.graphics.print("Gun " .. player.id, player.worldX*screenW, player.worldY*screenH, player.angle)
    end

    -- Render overlays.
    -- TODO
end



local new = function()
    local game = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,
    }

    -- Create the play area.
    -- TODO

    -- Add players.
    game.players = {}
    local numPlayers = utils.size(g_globals.jsToPlayerID)
    if numPlayers > 0 then game.players[1] = playerMake(1, 0.5,0.5) end
    if numPlayers > 1 then game.players[2] = playerMake(2, 0.5,0.5) end
    if numPlayers > 2 then game.players[3] = playerMake(3, 0.5,0.5) end
    if numPlayers > 3 then game.players[4] = playerMake(4, 0.5,0.5) end

    -- Game state.
    game.enemies = {}
    game.bullets = {}
    game.revives = 4
    game.exit = false

    return game
end

return new
