--[[
Chess, but realtime and up to 4 player.
Players have 12 units, no queens.
Players can't move the same unit twice in a row.
Grid is 16x16 (12 + 2*2)
--]]



-- Globals
local g_settings = nil
local settingsMake = function()
    local screenW,screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local padding = 0.05
    local offsetX,offsetY = screenW*padding,screenH*padding
    local cellX,cellY = screenW*(1-2*padding)/16,screenH*(1-2*padding)/16

    local s = {
        ox = offsetX,
        oy = offsetY,
        cx = cellX,
        cy = cellY,
    }
    return s
end



-- Utils.
local clamp = function(x, l, h)
    return math.max(math.min(x, h), l)
end
local size = function(t)
    local i = 0
    for _ in pairs(t) do i = i + 1 end
    return i
end



-- Pieces.
local PT = {
    Empty = {
        name="Empty",
        draw = function(x,y) end,
    },
    Pawn = {
        name="Pawn",
        draw = function(x,y) love.graphics.print("Pawn", x, y) end,
    },
    Rook = {
        name="Rook",
        draw = function(x,y) love.graphics.print("Rook", x, y) end,
    },
    Knight = {
        name="Knight",
        draw = function(x,y) love.graphics.print("Knight", x, y) end,
    },
    Bishop = {
        name="Bishop",
        draw = function(x,y) love.graphics.print("Bishop", x, y) end,
    },
    King = {
        name="King",
        draw = function(x,y) love.graphics.print("King", x, y) end,
    },
}
local pieceMake = function(t, o)
    local p = {
        typ = t,
        owner = o,
        selected = false,
        draw = function(self, x,y)
            if not self.owner then return end -- Empty tiles aren't owned
            local s = 1
            if self.selected then s = 0.5 end
            love.graphics.setColor(s*self.owner.col[1], s*self.owner.col[2], s*self.owner.col[3], 1)
            self.typ.draw(x,y)
        end
    }
    return p
end



-- Player infos.
local g_players = {}
local playerAdd = function(pID, x, y, col)
    local player = {
        x = x,
        y = y,
        col = col,
        jsID = nil, -- nil=not bound
        selection = nil,
        lastPieceType = nil,
    }
    g_players[pID] = player
end
local playerGet = function(pID)
    return g_players[pID]
end



-- Game grid.
local g_grid = {}
local gridMake = function()
    -- Empty everything.
    for j = 1,16 do
        g_grid[j] = {}
        for i = 1,16 do
            g_grid[j][i] = pieceMake(PT.Empty, nil)
        end
    end

    -- Setup initial pieces.
    local fill = function(p, sx,sy, rx,ry, dx,dy)   -- start, right, down
        local set = function(i, j, t)
            local x,y = sx + rx*i + dx*j, sy + ry*i + dy*j
            g_grid[y][x] = pieceMake(t, p)
        end

        for i = 0,11 do set(i, 1, PT.Pawn) end
        set(0, 0, PT.Rook)
        set(1, 0, PT.Knight)
        set(2, 0, PT.Bishop)
        set(3, 0, PT.King)
        set(4, 0, PT.Bishop)
        set(5, 0, PT.Knight)
        set(6, 0, PT.Rook)
        set(7, 0, PT.Knight)
        set(8, 0, PT.Bishop)
        set(9, 0, PT.King)
        set(10, 0, PT.Bishop)
        set(11, 0, PT.Knight)
    end
    fill(playerGet(1), 3,1, 1,0, 0,1)
    fill(playerGet(2), 14,16, -1,0, 0,-1)
    fill(playerGet(3), 1,14, 0,-1, 1,0)
    fill(playerGet(4), 16,3, 0,1, -1,0)
end
local gridGet = function(x, y)
    return g_grid[1+y][1+x]
end



-- Joystick mapping to player ID.
local g_jsToID = {}
local jsAdd = function(js)
    -- Check for replugging event.
    for pID,info in pairs(g_players) do
        if info.jsID == js:getID() then
            g_jsToID[js] = pID
            return
        end
    end

    -- Add new joystick.
    for pID,info in pairs(g_players) do
        if info.jsID == nil then
            info.jsID = js:getID()
            g_jsToID[js] = pID
            return
        end
    end

    -- No spaces left.
    g_jsToID[js] = nil
end
local jsRemove = function(js)
    g_jsToID[js] = nil
end
local jsGet = function(playerID)
    for js,pID in pairs(g_jsToID) do
        if pID == playerID then
            return js
        end
    end
    return nil
end



-- Callbacks and logic.
function love.load()
    love.window.setMode(1440, 900)
    --love.window.setFullscreen(true)
    --love.mouse.setVisible(false)
    g_settings = settingsMake()

    -- Add players.
    playerAdd(1, 8,0, {1,0,0})
    playerAdd(2, 8,15, {0,1,0})
    playerAdd(3, 0,8, {0,0,1})
    playerAdd(4, 15,8, {0,1,1})

    -- Create the grid.
    gridMake()
end

function love.update(dt)
    -- Cap dt to prevent large jumps when resuming from suspend
    local MAX_DT = 1 / 30
    if dt > MAX_DT then dt = MAX_DT end
end

function love.gamepadpressed(js, button)
    local playerID = g_jsToID[js]
    if not playerID then return end
    local player = g_players[playerID]

    local dx = 0
    local dy = 0

    if button == "a" then
        -- Action.
        if player.selection == nil then
            -- Pick up piece.
            local piece = gridGet(player.x, player.y)
            if piece.owner == player and piece.typ ~= player.lastPieceType then
                player.selection = piece
                piece.selected = true
            end

        else
            -- Try and place it.
            -- TODO: checks
            local selection = player.selection
            player.selection = nil
            selection.selected = false
            player.lastPieceType = selection.typ
        end

    elseif button == "dpright" then
        dx = dx + 1
    elseif button == "dpleft" then
        dx = dx - 1
    elseif button == "dpup" then
        dy = dy - 1
    elseif button == "dpdown" then
        dy = dy + 1
    end

    -- Move the player.
    player.x = clamp(player.x + dx, 0, 15)
    player.y = clamp(player.y + dy, 0, 15)
end

function love.joystickadded(js)
    jsAdd(js)
end

function love.joystickremoved(js)
    jsRemove(js)
end

function love.draw()
    -- Clear screen.
    love.graphics.clear(0, 0, 0, 1)

    -- Draw the grid.
    local offsetX,offsetY = g_settings.ox, g_settings.oy
    local cellX,cellY = g_settings.cx, g_settings.cy
    for y = 0,15 do
        for x = 0,15 do
            -- Border.
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", offsetX+x*cellX, offsetY+y*cellY, cellX, cellY)
            -- Contents.
            gridGet(x, y):draw(offsetX+x*cellX, offsetY+y*cellY)
        end
    end

    -- Draw the player's cursor.
    local playerRadius = math.min(cellX, cellY) / 2
    for _,player in pairs(g_players) do
        love.graphics.setColor(player.col[1], player.col[2], player.col[3], 1)
        love.graphics.circle("line", offsetX+(player.x+0.5)*cellX, offsetY+(player.y+0.5)*cellY, playerRadius)
    end
end
