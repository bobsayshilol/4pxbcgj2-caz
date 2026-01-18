local update = function(self, dt)
    return "main"
end

local gamepadpressed = function(self, playerID, button)
end

local draw = function(self)
    love.graphics.clear(0, 0, 0, 1)
end



local new = function()
    local splash = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,
    }
    return splash
end

return new
