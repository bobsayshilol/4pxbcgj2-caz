--[[
Chess, but realtime and up to 4 player.
Players have 12 units, no queens.
Players can't move the same unit twice in a row.
Grid is 16x16 (12 + 2*2)
--]]



-- Pieces.
local PT = {
    Empty = {
        name="Empty",
        draw = function(x,y) end,
        --canMove = function(dx,dy) return false end,
    },
    Pawn = {
        name="Pawn",
        draw = function(x,y) love.graphics.print("Pawn", x, y) end,
        canMove = function(dx,dy)
            dx,dy = math.abs(dx),math.abs(dy)
            return (dx==0 and dy<2) or (dx<2 and dy==0)
        end,
    },
    Rook = {
        name="Rook",
        draw = function(x,y) love.graphics.print("Rook", x, y) end,
        canMove = function(dx,dy)
            return math.abs(dx) == 0 or math.abs(dy) == 0
        end,
    },
    Knight = {
        name="Knight",
        draw = function(x,y) love.graphics.print("Knight", x, y) end,
        canMove = function(dx,dy)
            dx,dy = math.abs(dx),math.abs(dy)
            return (dx==0 and dy==0) or (dx==1 and dy==2) or (dx==2 and dy==1)
        end,
    },
    Bishop = {
        name="Bishop",
        draw = function(x,y) love.graphics.print("Bishop", x, y) end,
        canMove = function(dx,dy)
            return math.abs(dx) == math.abs(dy)
        end,
    },
    King = {
        name="King",
        draw = function(x,y) love.graphics.print("King", x, y) end,
        canMove = function(dx,dy)
            dx,dy = math.abs(dx),math.abs(dy)
            return (dx<2) and (dy<2)
        end,
    },
}
local pieceMake = function(t, o, x,y)
    local p = {
        typ = t,
        owner = o,
        x = x,
        y = y,
        selected = false,
        draw = function(self, x,y)
            if not self.owner then return end -- Empty tiles aren't owned
            local s = 1
            if self.selected then s = 0.5 end
            love.graphics.setColor(s*self.owner.col[1], s*self.owner.col[2], s*self.owner.col[3], 1)
            self.typ.draw(x,y)
        end,
        canMove = function(self, tx,ty)
            return self.typ.canMove(1+tx-self.x, 1+ty-self.y)
        end,
    }
    return p
end



-- Player infos.
local playerMake = function(x, y, col)
    local player = {
        x = x,
        y = y,
        col = col,
        jsID = nil, -- nil=not bound
        selection = nil,
        lastPieceType = nil,
    }
    return player
end



-- Game grid.
local gridMake = function(players)
    local grid = {}

    -- Empty everything.
    for j = 1,16 do
        grid[j] = {}
        for i = 1,16 do
            grid[j][i] = pieceMake(PT.Empty, nil, i,j)
        end
    end

    -- Setup initial pieces.
    local fill = function(p, sx,sy, rx,ry, dx,dy)   -- start, right, down
        local set = function(i, j, t)
            local x,y = sx + rx*i + dx*j, sy + ry*i + dy*j
            grid[y][x] = pieceMake(t, p, x,y)
        end

        for i = 0,11 do set(i, 1, PT.Pawn) end
        set(0, 0, PT.Rook)
        set(1, 0, PT.Knight)
        set(2, 0, PT.Bishop)
        set(3, 0, PT.King)
        set(4, 0, PT.Bishop)
        set(5, 0, PT.Knight)
        set(6, 0, PT.Knight)
        set(7, 0, PT.Bishop)
        set(8, 0, PT.King)
        set(9, 0, PT.Bishop)
        set(10, 0, PT.Knight)
        set(11, 0, PT.Rook)
    end

    local numPlayers = utils.size(players)
    if numPlayers > 0 then fill(players[1], 3,1, 1,0, 0,1) end
    if numPlayers > 1 then fill(players[2], 14,16, -1,0, 0,-1) end
    if numPlayers > 2 then fill(players[3], 1,14, 0,-1, 1,0) end
    if numPlayers > 3 then fill(players[4], 16,3, 0,1, -1,0) end

    return grid
end
local gridGet = function(grid, x, y)
    return grid[1+y][1+x]
end



-- Callbacks.

local update = function(self, dt)
    return nil
end

local gamepadpressed = function(self, js, button)
    local playerID = g_globals.jsToPlayerID[js]
    local player = self.players[playerID]
    if not player then return end

    if button == "a" then
        -- Action.
        if player.selection == nil then
            -- Pick up piece.
            local piece = gridGet(self.grid, player.x, player.y)
            if piece.owner == player and piece.typ ~= player.lastPieceType then
                player.selection = piece
                piece.selected = true
            end

        else
            -- Try and place it.
            local selection = player.selection
            if selection:canMove(player.x, player.y) then
                selection.selected = false
                player.lastPieceType = selection.typ
                player.selection = nil
            end
        end

        return

    elseif button == "b" then
        if player.selection ~= nil then
            player.selection.selected = false
            player.selection = nil
        end

        return
    end

    local dx = 0
    local dy = 0

    if button == "dpright" then
        dx = dx + 1
    elseif button == "dpleft" then
        dx = dx - 1
    elseif button == "dpup" then
        dy = dy - 1
    elseif button == "dpdown" then
        dy = dy + 1
    end

    -- Move the player.
    player.x = utils.clamp(player.x + dx, 0, 15)
    player.y = utils.clamp(player.y + dy, 0, 15)
end

local draw = function(self)
    -- Clear screen.
    love.graphics.clear(0, 0, 0, 1)

    -- Draw the grid.
    local offsetX,offsetY = g_globals.ox, g_globals.oy
    local cellX,cellY = g_globals.cx, g_globals.cy
    for y = 0,15 do
        for x = 0,15 do
            -- Border.
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", offsetX+x*cellX, offsetY+y*cellY, cellX, cellY)
            -- Contents.
            gridGet(self.grid, x, y):draw(offsetX+x*cellX, offsetY+y*cellY)
        end
    end

    -- Draw the player's cursor.
    local playerRadius = math.min(cellX, cellY) / 2
    for _,player in pairs(self.players) do
        love.graphics.setColor(player.col[1], player.col[2], player.col[3], 1)
        love.graphics.circle("line", offsetX+(player.x+0.5)*cellX, offsetY+(player.y+0.5)*cellY, playerRadius)
    end
end



local new = function()
    local game = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,
    }

    -- Add players.
    game.players = {}
    local numPlayers = utils.size(g_globals.jsToPlayerID)
    if numPlayers > 0 then game.players[1] = playerMake(8,0, g_globals.playerCols[1]) end
    if numPlayers > 1 then game.players[2] = playerMake(8,15, g_globals.playerCols[2]) end
    if numPlayers > 2 then game.players[3] = playerMake(0,8, g_globals.playerCols[3]) end
    if numPlayers > 3 then game.players[4] = playerMake(15,8, g_globals.playerCols[4]) end

    -- Create the grid.
    game.grid = gridMake(game.players)

    return game
end

return new
