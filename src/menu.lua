
local s_games = {
    {
        menu = "chess",
        minPlayers = 2,
        maxPlayers = 4,
        name = "Multiplayer realtime chess",
        desc1 = "Same as ordinary chess, except that you have 2 kings to protect,",
        desc2 = "pawns can move horizontally and vertically, and you can't move",
        desc3 = "the same type of piece twice in a row.",
        desc4 = "D-pad to move, A to select/place a piece, B to unselect, left",
        desc5 = "shoulder to view current move, and right shoulder to move faster.",
    },
    {
        menu = "shooter",
        minPlayers = 1,
        maxPlayers = 4,
        name = "Zombies",
        desc1 = "It's a CoD Zombies clone, 'nuf said.",
        desc2 = "",
        desc3 = "",
        desc4 = "Twin stick shooter controls. Left shoulder to respawn.",
        desc5 = "",
    },
}



local enoughReady = function(states, game)
    local num = 0
    for js,state in pairs(states) do
        if state.ready then num = num + 1 end
    end
    return game.minPlayers <= num and num <= game.maxPlayers
end

local hasFreeID = function(states, game)
    local num = 0
    for js,state in pairs(states) do
        if state.ready then num = num + 1 end
    end
    return num < game.maxPlayers
end

local rebuildIDs = function(states)
    local ready = {}
    -- Clear out old IDs.
    for js,state in pairs(states) do
        state.pid = nil
        if state.ready then
            table.insert(ready, state)
        end
    end
    -- Sort on ready up time.
    local first = function(a,b)
        return a.ready < b.ready
    end
    table.sort(ready, first)
    for pid,state in ipairs(ready) do
        state.pid = pid
    end
end



local update = function(self, dt)
    if self.start then
        -- Pass on info to the game.
        g_globals.jsToPlayerID = {}
        g_globals.pidToJs = {}
        for js,state in pairs(self.jsStates) do
            if state.ready then
                g_globals.jsToPlayerID[js] = state.pid
                g_globals.pidToJs[state.pid] = js
            end
        end
        return s_games[self.gameChoice].menu
    end
    return nil
end

local gamepadpressed = function(self, js, button)
    local state = self.jsStates[js]
    local game = s_games[self.gameChoice]

    if state.pid == nil and button == "a" then
        if hasFreeID(self.jsStates, game) then
            state.ready = love.timer.getTime()
            rebuildIDs(self.jsStates)
        end

    elseif state.pid ~= nil and button == "b" then
        state.ready = false
        state.pid = nil
        rebuildIDs(self.jsStates)

    elseif state.pid == 1 and button == "x" and enoughReady(self.jsStates, game) then
        self.start = true

    elseif state.pid == 1 and (button == "dpleft" or button == "dpright") then
        self.gameChoice = 3 - self.gameChoice -- lazy
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
    --local scale = 3 + math.sin(2*3.14*love.timer.getTime())*0.5

    local drawCentered = function(text, y, scale)
        love.graphics.print(text, (sw-font:getWidth(text)*scale)/2, sh*y-font:getHeight()*scale/2, 0, scale, scale)
    end

    love.graphics.setColor(1, 1, 1, 1)
    local game = s_games[self.gameChoice]
    drawCentered("< " .. game.name .. " >", 0.15, 3)
    drawCentered(game.minPlayers .. " to " .. game.maxPlayers .." players", 0.25, 2)
    drawCentered(game.desc1, 0.35, 2)
    drawCentered(game.desc2, 0.4, 2)
    drawCentered(game.desc3, 0.45, 2)
    drawCentered(game.desc4, 0.5, 2)
    drawCentered(game.desc5, 0.55, 2)
    drawCentered("Press A to ready up", 0.65, 2)
    if enoughReady(self.jsStates, game) then
        drawCentered("Press X to start", 0.7, 2)
    end

    local y = 0.7
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
    menu.start = false
    menu.gameChoice = 1

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
