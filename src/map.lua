
local ROT_NORTH = 1
local ROT_EAST = 2
local ROT_SOUTH = 3
local ROT_WEST = 4
local addSpawner = function(self, world, x,y, w,h, rot)
    local spawner = {
        x = x,
        y = y,
        nextTime = 0,
    }
    local body = love.physics.newBody(world, spawner.x,spawner.y, "static")
    table.insert(self.bodies, border)

    local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(w,h))
    fixture:setCategory(PHYS_CATEGORY_WALL)
    spawner.body = body

    local rots = { {0,-h}, {w,0}, {0,h}, {-w,0} } -- faces NESW
    local r = rots[rot]
    spawner.entrance = love.physics.newBody(world, spawner.x+r[1],spawner.y+r[2], "static")
    table.insert(self.bodies, spawner.entrance)
    table.insert(self.spawners, spawner)
end



local map1 = function(self, world, sw,sh)
    -- Safe zones for player spawn points.
    table.insert(self.spawnPoints, {0.25*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.75*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.25*sw,0.75*sh})
    table.insert(self.spawnPoints, {0.75*sw,0.75*sh})

    -- Add enemy spawners.
    addSpawner(self, world, 1*sw,0.4*sh, sw/16,sh/16, ROT_WEST)
    addSpawner(self, world, 0*sw,0.6*sh, sw/16,sh/16, ROT_EAST)
    addSpawner(self, world, 0.3*sw,1*sh, sw/16,sh/16, ROT_NORTH)
    addSpawner(self, world, 0.7*sw,1*sh, sw/16,sh/16, ROT_NORTH)
    addSpawner(self, world, 0.6*sw,0*sh, sw/16,sh/16, ROT_SOUTH)

    -- Add some scenery.
    do
        local rock = love.physics.newBody(world, sw/3,sh/2, "static")
        love.physics.newFixture(rock, love.physics.newRectangleShape(sw/10,sh/5)):setCategory(PHYS_CATEGORY_WALL)
    end
    do
        local hole = love.physics.newBody(world, sw*2/3,sh/2, "static")
        love.physics.newFixture(hole, love.physics.newRectangleShape(sw/10,sh/5)):setCategory(PHYS_CATEGORY_HOLE)
    end
end



local mapDestroy = function(self)
    for _,body in pairs(self.bodies) do
        body:destroy()
    end
end

local mapCreate = function(world, choice)
    local m = {
        bodies = {},

        spawners = {},
        spawnPoints = {},

        destroy = mapDestroy,
    }

    local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()

    -- Border outside the map to catch bullets.
    do
        local border = love.physics.newBody(world, 0,0, "static")
        table.insert(m.bodies, border)

        local addBorder = function(x0,y0, x1,y1)
            local fixture = love.physics.newFixture(border, love.physics.newEdgeShape(x0,y0, x1,y1))
            -- We're a wall, and we collide with everything.
            fixture:setCategory(PHYS_CATEGORY_WALL)
        end

        local p = -10
        addBorder(p,p, p,sh-p)
        addBorder(p,p, sw-p,p)
        addBorder(p,sh-p, sw-p,sh-p)
        addBorder(sw-p,p, sw-p,sh-p)
    end

    -- Build the map from the choice.
    choice(m, world, sw,sh)
    return m
end



return {
    new = mapCreate,

    map1 = map1,
}
