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
