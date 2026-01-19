local allReady = function(states)
    local all = true
    for js,state in pairs(states) do
        all = all and state.ready
    end
    return all and utils.size(states) >= 2
end

local freeID = function(states)
    local ids = {}
    ids[1] = true
    ids[2] = true
    ids[3] = true
    ids[4] = true
    for js,state in pairs(states) do
        if state.pid then
            ids[state.pid] = nil
        end
    end
    for pid,_ in pairs(ids) do
        return pid
    end
    return nil
end



local update = function(self, dt)
    if allReady(self.jsStates) then
        -- Pass on info to the game.
        g_globals.jsToPlayerID = {}
        for js,state in pairs(self.jsStates) do
            g_globals.jsToPlayerID[js] = state.pid
        end
        return "game"
    end
    return nil
end

local gamepadpressed = function(self, js, button)
    local state = self.jsStates[js]
    if state.pid == nil and button == "a" then
        local pid = freeID(self.jsStates)
        if pid then
            state.ready = true
            state.pid = pid
        end
    elseif state.pid ~= nil and button == "b" then
        state.ready = false
        state.pid = nil
    end
end

local joystickadded = function(self, js)
    self.jsStates[js] = {
        ready = false,
        pid = nil,
    }
end

local joystickremoved = function(self, js)
    self.jsStates[js] = nil
end

local draw = function(self)
    love.graphics.clear(0, 0, 0, 1)

    local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()
    local font = love.graphics.getFont()
    local scale = 3 + math.sin(2*3.14*love.timer.getTime())*0.5

    local drawCentered = function(text, y, scale)
        love.graphics.print(text, (sw-font:getWidth(text)*scale)/2, sh*y-font:getHeight()*scale/2, 0, scale, scale)
    end

    love.graphics.setColor(1, 1, 1, 1)
    drawCentered("A GAME THING", 0.3, scale)
    drawCentered("Press A to ready up", 0.45, 2)

    local y = 0.5
    for js,state in pairs(self.jsStates) do
        y = y + 0.05
        local id,iid = js:getID()
        if state.ready then
            local pid = state.pid
            local cols = g_globals.playerCols[pid]
            love.graphics.setColor(cols[1], cols[2], cols[3], 1)
            drawCentered("Controller '" .. id .. "' is player " .. pid, y, 2)
        else
            love.graphics.setColor(1, 1, 1, 1)
            drawCentered("Controller '" .. id .. "' not ready", y, 2)
        end
    end
end



local new = function()
    local menu = {
        update = update,
        gamepadpressed = gamepadpressed,
        joystickadded = joystickadded,
        joystickremoved = joystickremoved,
        draw = draw,
    }
    menu.jsStates = {}

    -- Add existing joysticks.
    for _,js in pairs(love.joystick.getJoysticks()) do
        menu:joystickadded(js)
    end
    if ADD_FAKE_DEVICES then
        menu:joystickadded(g_fakeDevice)
        menu:joystickadded(g_fakeDevice2)
    end

    return menu
end

return new
