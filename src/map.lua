

local addBody = function(self, world, x,y)
    local body = love.physics.newBody(world, x,y, "static")
    table.insert(self.bodies, border)
    return body
end
local newFixture = love.physics.newFixture
local newEdgeShape = love.physics.newEdgeShape
local newRectangleShape = love.physics.newRectangleShape



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
    local body = addBody(self, world, spawner.x,spawner.y)

    local fixture = newFixture(body, newRectangleShape(w,h))
    fixture:setCategory(PHYS_CATEGORY_WALL)
    spawner.body = body

    local rots = { {0,-h}, {w,0}, {0,h}, {-w,0} } -- faces NESW
    local r = rots[rot]
    spawner.entrance = addBody(self, world, spawner.x+r[1],spawner.y+r[2])

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

    -- No navmesh.
    self.navMesh[1] = {{sw/2,sh/2}, {sw/2,sh/2}, {}}

    -- Add some scenery.
    do
        local rock = addBody(self, world, sw/3,sh/2)
        newFixture(rock, newRectangleShape(sw/10,sh/5)):setCategory(PHYS_CATEGORY_WALL)
    end
    do
        local hole = addBody(self, world, sw*2/3,sh/2)
        newFixture(hole, newRectangleShape(sw/10,sh/5)):setCategory(PHYS_CATEGORY_HOLE)
    end
end



-- 2 roofs.
local map2 = function(self, world, sw,sh)
    -- Safe zones for player spawn points.
    table.insert(self.spawnPoints, {0.1*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.9*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.1*sw,0.75*sh})
    table.insert(self.spawnPoints, {0.9*sw,0.75*sh})

    -- Add enemy spawners.
    addSpawner(self, world, 0*sw,0.5*sh, sw/20,sh/20, ROT_EAST)

    -- Holes for walkways.
    local xl,xr = sw/4,sw*3/4
    local ww1y1,ww1y2 = sh/16,sh*3/16
    local ww2y1,ww2y2 = sh*7/16,sh*9/16
    local ww3y1,ww3y2 = sh*13/16,sh*15/16
    do
        local lines = {
            -- Top.
            {xl,0, xl,ww1y1},
            {xr,0, xr,ww1y1},
            {xl,ww1y1, xr,ww1y1},
            -- Spacer.
            {xl,ww1y2, xr,ww1y2},
            {xl,ww1y2, xl,ww2y1},
            {xr,ww1y2, xr,ww2y1},
            {xl,ww2y1, xr,ww2y1},
            -- Spacer.
            {xl,ww2y2, xr,ww2y2},
            {xl,ww2y2, xl,ww3y1},
            {xr,ww2y2, xr,ww3y1},
            {xl,ww3y1, xr,ww3y1},
            -- Bottom.
            {xl,sh, xl,ww3y2},
            {xr,sh, xr,ww3y2},
            {xl,ww3y2, xr,ww3y2},
        }

        local holes = addBody(self, world, 0,0)
        for _,line in ipairs(lines) do
            newFixture(holes, newEdgeShape(line[1],line[2], line[3],line[4])):setCategory(PHYS_CATEGORY_HOLE)
        end
    end

    -- Navmesh.
    do
        local nv = self.navMesh
        local addNav = function(idx, tlx,tly, brx,bry, links)
            local midx,midy = (brx+tlx)/2,(bry+tly)/2
            local extx,exty = (brx-tlx)/2,(bry-tly)/2
            nv[idx] = {{midx,midy}, {extx,exty}, links}
        end

        local nvPad = 0.05*sw

        -- Left.
        local nxl = xl-nvPad
        addNav(1, 0,0, nxl,sh, {2,3,4,5,6,7,8})
        addNav(2, nxl,0, xl,ww1y1, {1,3})
        addNav(3, nxl,ww1y1, xl,ww1y2, {1,2,4,17})
        addNav(4, nxl,ww1y2, xl,ww2y1, {1,3,5})
        addNav(5, nxl,ww2y1, xl,ww2y2, {1,4,6,18})
        addNav(6, nxl,ww2y2, xl,ww3y1, {1,5,7})
        addNav(7, nxl,ww3y1, xl,ww3y2, {1,6,8,19})
        addNav(8, nxl,ww3y2, xl,sh, {1,7})

        -- Right.
        local nxr = xr+nvPad
        addNav(9, nxr,0, sw,sh, {10,11,12,13,14,15,16})
        addNav(10, xr,0, nxr,ww1y1, {9,11})
        addNav(11, xr,ww1y1, nxr,ww1y2, {9,10,12,17})
        addNav(12, xr,ww1y2, nxr,ww2y1, {9,11,13})
        addNav(13, xr,ww2y1, nxr,ww2y2, {9,12,14,18})
        addNav(14, xr,ww2y2, nxr,ww3y1, {9,13,15})
        addNav(15, xr,ww3y1, nxr,ww3y2, {9,14,16,19})
        addNav(16, xr,ww3y2, nxr,sh, {9,15})

        -- Middle.
        addNav(17, xl,ww1y1, xr,ww1y2, {3,11})
        addNav(18, xl,ww2y1, xr,ww2y2, {5,13})
        addNav(19, xl,ww3y1, xr,ww3y2, {7,15})
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
        navMesh = {}, -- {{center}, {extent}, {links}},

        destroy = mapDestroy,
    }

    local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()

    -- Border outside the map to catch bullets.
    do
        local border = addBody(m, world, 0,0)

        local addBorder = function(x0,y0, x1,y1)
            local fixture = newFixture(border, newEdgeShape(x0,y0, x1,y1))
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
    map2 = map2,
}
