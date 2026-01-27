utils = require("src/utils")



-- Globals
g_globals = nil
local globalsMake = function()
    local screenW,screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local padding = 0.05
    local offsetX,offsetY = screenW*padding,screenH*padding
    local cellX,cellY = screenW*(1-2*padding)/16,screenH*(1-2*padding)/16

    local playerCols = {
        {1,0,0},
        {0,1,0},
        {0,1,1},
        {1,1,0},
    }

    local s = {
        ox = offsetX,
        oy = offsetY,
        cx = cellX,
        cy = cellY,

        playerCols = playerCols,
    }
    return s
end



-- Menu system.
local s_menu = nil
local s_menus = {
    splash = require("src/splash"),
    menu = require("src/menu"),
    chess = require("src/chess"),
    shooter = require("src/shooter"),
}



-- Fake devices.
ADD_FAKE_DEVICES = false
g_fakeDevice = {
    x = 0,
    y = 0,
    getID = function(self) return -1,-1 end,
    setVibration = function(self, l, r, t) end,
    isGamepadDown = function(self, k) return false end,
    getGamepadAxis = function(self, n)
        if n == "leftx" then return self.x elseif n == "lefty" then return self.y end
        return 0
    end,
}
g_fakeDevice2 = {
    x = 0,
    y = 0,
    getID = function(self) return -2,-2 end,
    setVibration = function(self, l, r, t) end,
    isGamepadDown = function(self, k) return false end,
    getGamepadAxis = function(self, n)
        if n == "leftx" then return self.x elseif n == "lefty" then return self.y end
        return 0
    end,
}



-- Callbacks.
function love.load()
    love.window.setMode(1440, 900)
    --love.window.setFullscreen(true)
    --love.mouse.setVisible(false)
    g_globals = globalsMake()

    s_menu = s_menus["splash"]()
end

function love.update(dt)
    if dt > 1/30 then dt = 1/30 end

    local nextMenu = s_menu:update(dt)
    if nextMenu ~= nil then
        s_menu = s_menus[nextMenu]()
    end
end

function love.keypressed(key, scancode, isRepeat)
    if ADD_FAKE_DEVICES then
        local m1 = {
            e = "a",
            q = "b",
            x = "x",
            c = "y",
            w = "dpup",
            s = "dpdown",
            a = "dpleft",
            d = "dpright",
        }
        local m2 = {
            o = "a",
            u = "b",
            i = "dpup",
            k = "dpdown",
            j = "dpleft",
            l = "dpright",
        }
        local dir = {
            left = { "x", -1, },
            right = { "x", 1, },
            up = { "y", -1, },
            down = { "y", 1, },
        }

        if m1[scancode] then
            love.gamepadpressed(g_fakeDevice, m1[scancode])
        elseif m2[scancode] then
            love.gamepadpressed(g_fakeDevice2, m2[scancode])
        elseif dir[scancode] then
            local k = dir[scancode]
            g_fakeDevice[k[1]] = k[2]
        end
    end
end

function love.keyreleased(key, scancode)
    if ADD_FAKE_DEVICES then
        local dir = {
            left = "x",
            right = "x",
            up = "y",
            down = "y",
        }
        if dir[scancode] then
            local k = dir[scancode]
            g_fakeDevice[k] = 0
        end
    end
end

function love.gamepadpressed(js, button)
    s_menu:gamepadpressed(js, button)
end

function love.joystickadded(js)
    if s_menu.joystickadded then
        s_menu:joystickadded(js)
    end
end

function love.joystickremoved(js)
    if s_menu.joystickremoved then
        s_menu:joystickremoved(js)
    end
end

function love.draw()
    s_menu:draw()
end
