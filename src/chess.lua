--[[
Chess, but realtime and up to 4 player.
Players have 12 units, no queens.
Players can't move the same unit twice in a row.
Grid is 16x16 (12 + 2*2)
--]]

local DISABLED_MOVE_TIME = 3 -- seconds

local IMAGE_TYPE = "W3" -- or W



-- Pieces.
local PT = {
    Empty = {
        name="Empty",
        image = nil,
        --canMove = function(dx,dy) return false end,
    },
    Pawn = {
        name="Pawn",
        image = love.graphics.newImage("assets/chess/pawn" .. IMAGE_TYPE .. ".png"),
        canMove = function(dx,dy)
            dx,dy = math.abs(dx),math.abs(dy)
            return (dx==0 and dy<2) or (dx<2 and dy==0)
        end,
        canTake = function(dx,dy)
            return math.abs(dx) == math.abs(dy)
        end
    },
    Rook = {
        name="Rook",
        image = love.graphics.newImage("assets/chess/rook" .. IMAGE_TYPE .. ".png"),
        canMove = function(dx,dy)
            return math.abs(dx) == 0 or math.abs(dy) == 0
        end,
    },
    Knight = {
        name="Knight",
        image = love.graphics.newImage("assets/chess/knight" .. IMAGE_TYPE .. ".png"),
        canMove = function(dx,dy)
            dx,dy = math.abs(dx),math.abs(dy)
            return (dx==0 and dy==0) or (dx==1 and dy==2) or (dx==2 and dy==1)
        end,
    },
    Bishop = {
        name="Bishop",
        image = love.graphics.newImage("assets/chess/bishop" .. IMAGE_TYPE .. ".png"),
        canMove = function(dx,dy)
            return math.abs(dx) == math.abs(dy)
        end,
    },
    King = {
        name="King",
        image = love.graphics.newImage("assets/chess/king" .. IMAGE_TYPE .. ".png"),
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
        disabledCountdown = DISABLED_MOVE_TIME,
        selected = false,
        draw = function(self, x,y, cellX,cellY)
            if not self.owner then return end -- Empty tiles aren't owned
            local s = 1
            if self.selected then s = 0.5 end
            love.graphics.setColor(s*self.owner.col[1], s*self.owner.col[2], s*self.owner.col[3], 1)
            local image = self.typ.image
            love.graphics.draw(image, x,y, 0, cellX/image:getWidth(),cellY/image:getHeight())

            -- Draw over to show countdown.
            if self.disabledCountdown > 0 then
                love.graphics.setColor(self.owner.col[1], self.owner.col[2], self.owner.col[3], 0.4)
                local remaining = cellY * self.disabledCountdown / DISABLED_MOVE_TIME
                love.graphics.rectangle("fill", x, y + remaining, cellX, cellY - remaining)
            end
        end,
        canMove = function(self, tx,ty)
            local dx,dy = 1+tx-self.x, 1+ty-self.y
            return self.typ.canMove(dx,dy)
        end,
        canTake = function(self, tx,ty)
            local dx,dy = 1+tx-self.x, 1+ty-self.y
            if self.typ.canTake then
                return self.typ.canTake(dx,dy)
            else
                return self.typ.canMove(dx, dy)
            end
        end
    }
    return p
end



-- Player infos.
local playerMake = function(id, x, y, col)
    local player = {
        id = id,
        x = x,
        y = y,
        col = col,
        kings = 2,
        selection = nil,
        lastPieceType = nil,
    }
    return player
end
local playerDead = function(player)
    return player.kings == 0
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
local gridTake = function(grid, from, to)
    grid[from.y][from.x] = pieceMake(PT.Empty, nil, from.x,from.y)
    grid[to.y][to.x] = pieceMake(from.typ, from.owner, to.x,to.y)
end



-- Callbacks.

local update = function(self, dt)
    if self.exit then
        return "menu"
    elseif self.winner then
        return nil
    end

    -- Update countdowns.
    for j = 1,16 do
        for i = 1,16 do
            local p = self.grid[j][i]
            if p.disabledCountdown > 0 then
                p.disabledCountdown = p.disabledCountdown - dt
            end
        end
    end

    return nil
end

local checkGameOver = function(self)
    local alivePlayers = {}
    for _,player in ipairs(self.players) do
        if not playerDead(player) then
            table.insert(alivePlayers, player)
        end
    end
    if #alivePlayers == 1 then
        self.winner = alivePlayers[1]
    end
end

local gamepadpressed = function(self, js, button)
    local playerID = g_globals.jsToPlayerID[js]
    local player = self.players[playerID]

    if (not player) or playerDead(player) then
        return
    elseif self.winner == player then
        -- Only the winner can finish the game.
        if button == "x" then
            self.exit = true
        end
        return
    end

    if button == "a" then
        -- Action.
        if player.selection == nil then
            -- Pick up piece.
            local piece = gridGet(self.grid, player.x, player.y)
            if piece.owner == player and piece.typ ~= player.lastPieceType and piece.disabledCountdown <= 0 then
                player.selection = piece
                piece.selected = true
            end

        else
            -- Try and place it.
            local selection = player.selection
            local x,y = player.x,player.y -- HACK: 0-based

            if x+1==selection.x and y+1==selection.y then
                -- No movement, reset selection
                selection.selected = false
                player.selection = nil
                return
            end

            local target = gridGet(self.grid, x,y)
            local isEmpty = target.typ == PT.Empty
            local canMove = isEmpty and selection:canMove(x, y)
            -- Don't allow taking pieces that are being moved by another player.
            local canTake = (not isEmpty) and (target.owner ~= player) and selection:canTake(x, y) and not target.selected

            -- HACK: these need special casing to check for blocking pieces
            if (canMove or canTake) and (selection.typ == PT.Bishop or selection.typ == PT.Rook) then
                local good = true
                local dx,dy = utils.sign(x+1-selection.x),utils.sign(y+1-selection.y)
                local m = math.abs(x+1-selection.x)
                if dx == 0 then
                    m = math.abs(y+1-selection.y)
                end
                if canTake then m = m - 1 end
                for t=1,m do
                    good = good and gridGet(self.grid, selection.x-1 + t*dx, selection.y-1 + t*dy).typ == PT.Empty
                end
                canMove = canMove and good
                canTake = canTake and good
            end

            if canMove or canTake then
                -- Reset selection state.
                selection.selected = false
                player.lastPieceType = selection.typ
                player.selection = nil

                -- Do the move.
                gridTake(self.grid, selection, target)

                -- Buzz the attackee's controller.
                local wasKing = target.typ == PT.King
                if canTake then
                    local tjs = g_globals.pidToJs[target.owner.id]
                    if wasKing then
                        tjs:setVibration(0, 1, 0.1) -- high buzz
                    else
                        tjs:setVibration(0.5, 0, 0.2) -- low buzz
                    end
                end

                -- Trigger events.
                if wasKing then
                    target.owner.kings = target.owner.kings - 1
                    checkGameOver(self)
                end
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

    if js:isGamepadDown("rightshoulder") then
        dx = dx * 3
        dy = dy * 3
    end

    -- Move the player.
    player.x = utils.clamp(player.x + dx, 0, 15)
    player.y = utils.clamp(player.y + dy, 0, 15)
end

local draw = function(self)
    -- Clear screen.
    love.graphics.clear(0, 0, 0, 1)

    local screenW,screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- Draw the grid.
    local offsetX,offsetY = g_globals.ox, g_globals.oy
    local cellX,cellY = g_globals.cx, g_globals.cy
    for y = 0,15 do
        for x = 0,15 do
            -- Border.
            local grey = 0.8
            love.graphics.setColor(grey,grey,grey,1)
            love.graphics.rectangle(((x + y) % 2 == 0) and "fill" or "line", offsetX+x*cellX, offsetY+y*cellY, cellX, cellY)
            -- Contents.
            gridGet(self.grid, x, y):draw(offsetX+x*cellX, offsetY+y*cellY, cellX,cellY)
        end
    end

    -- Draw the player's cursor.
    local kingsPos = {{screenW/2,0}, {screenW/2,screenH-offsetY}, {0,screenH/2}, {screenW-offsetX,screenH/2}}
    local playerRadius = math.min(cellX, cellY) / 2
    for _,player in ipairs(self.players) do
        if not playerDead(player) then
            love.graphics.setColor(player.col[1], player.col[2], player.col[3], 1)
            love.graphics.circle("line", offsetX+(player.x+0.5)*cellX, offsetY+(player.y+0.5)*cellY, playerRadius)
            local pos = kingsPos[player.id]
            love.graphics.print("" .. player.kings, pos[1], pos[2], 0, 2)
        end
    end

    -- Show game stats.
    if self.winner then
        love.graphics.setColor(self.winner.col[1], self.winner.col[2], self.winner.col[3], 1)
        love.graphics.print("Player " .. self.winner.id .. " wins!", screenW / 2, screenH / 3, 0, 5)
        love.graphics.print("Press X to return", screenW / 2, screenH * 2/3, 0, 3)
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
    if numPlayers > 0 then game.players[1] = playerMake(1, 8,0, g_globals.playerCols[1]) end
    if numPlayers > 1 then game.players[2] = playerMake(2, 8,15, g_globals.playerCols[2]) end
    if numPlayers > 2 then game.players[3] = playerMake(3, 0,8, g_globals.playerCols[3]) end
    if numPlayers > 3 then game.players[4] = playerMake(4, 15,8, g_globals.playerCols[4]) end

    -- Create the grid.
    game.grid = gridMake(game.players)

    -- Game state.
    game.winner = nil
    game.exit = false

    return game
end

return new
