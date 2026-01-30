local update = function(self, dt)
    return self.done and "menu"
end

local gamepadpressed = function(self, playerID, button)
    self.done = true
end

local draw = function(self)
    local lg = love.graphics
    lg.clear(0,0,0)

    local sw,sh = lg.getWidth(),lg.getHeight()
    local font = lg.getFont()

    local drawCentered = function(text, x,y, scale, r)
        lg.push()
        lg.translate(x*sw,y*sh)
        lg.rotate(r)
        lg.print(text, -font:getWidth(text)*scale/2, -font:getHeight()*scale/2, 0, scale, scale)
        lg.pop()
    end

    local scale = function(base, a, phase)
        return base + a*math.sin(2*3.14*(love.timer.getTime() + phase))
    end

    drawCentered("CHESS", 0.4,0.3, scale(6, 1.5, 0), -3.14/8)
    drawCentered("AND ZOMBIES", 0.6,0.5, scale(3, 1, -0.2), 3.14/8)

    drawCentered("Press any button", 0.5,0.8, 2, 0)
end



local new = function()
    local splash = {
        update = update,
        gamepadpressed = gamepadpressed,
        draw = draw,

        done = nil,
    }
    return splash
end

return new
