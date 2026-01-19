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
    main = require("src/main"),
    game = require("src/game"),
}



-- Fake devices.
ADD_FAKE_DEVICE = false
g_fakeDevice = {
    getID = function(self) return -1,-1 end,
    setVibration = function(self, l, r, t) end,
}
g_fakeDevice2 = {
    getID = function(self) return -2,-1 end,
    setVibration = function(self, l, r, t) end,
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
    local nextMenu = s_menu:update(dt)
    if nextMenu ~= nil then
        s_menu = s_menus[nextMenu]()
    end
end

function love.keypressed(key, scancode, isRepeat)
    if ADD_FAKE_DEVICES then
        if scancode == "e" then
            love.gamepadpressed(g_fakeDevice, "a")
        elseif scancode == "q" then
            love.gamepadpressed(g_fakeDevice, "b")
        elseif scancode == "w" then
            love.gamepadpressed(g_fakeDevice, "dpup")
        elseif scancode == "s" then
            love.gamepadpressed(g_fakeDevice, "dpdown")
        elseif scancode == "a" then
            love.gamepadpressed(g_fakeDevice, "dpleft")
        elseif scancode == "d" then
            love.gamepadpressed(g_fakeDevice, "dpright")

        elseif scancode == "o" then
            love.gamepadpressed(g_fakeDevice2, "a")
        elseif scancode == "u" then
            love.gamepadpressed(g_fakeDevice2, "b")
        elseif scancode == "i" then
            love.gamepadpressed(g_fakeDevice2, "dpup")
        elseif scancode == "k" then
            love.gamepadpressed(g_fakeDevice2, "dpdown")
        elseif scancode == "j" then
            love.gamepadpressed(g_fakeDevice2, "dpleft")
        elseif scancode == "l" then
            love.gamepadpressed(g_fakeDevice2, "dpright")
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
