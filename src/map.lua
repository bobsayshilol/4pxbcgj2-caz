

local addBody = function(self, world, x,y)
    local body = love.physics.newBody(world, x,y, "static")
    local bods = self.bodies
    bods[#bods+1] = body
    return body
end
local newFixture = love.physics.newFixture
local newEdgeShape = love.physics.newEdgeShape
local newRectangleShape = love.physics.newRectangleShape



local ROT_NORTH = 1
local ROT_EAST = 2
local ROT_SOUTH = 3
local ROT_WEST = 4
local addSpawner = function(self, world, x,y, sw,sh, rot)
    local spawner = {
        x = x,
        y = y,
        nextTime = 0,
    }

    local spW,spH = sw/20,sw/20 -- should be ~size of enemy
    local rots = { {0,-spH}, {spW,0}, {0,spH}, {-spW,0} } -- faces NESW
    local sizes = { {spW,2}, {2,spH}, {spW,2}, {2,spH} }

    local s = sizes[rot]
    local body = addBody(self, world, spawner.x,spawner.y)
    spawner.body = body
    local fixture = newFixture(body, newRectangleShape(s[1],s[2]))
    fixture:setCategory(PHYS_CATEGORY_WALL)

    local r = rots[rot]
    spawner.entrance = addBody(self, world, spawner.x+r[1],spawner.y+r[2])

    table.insert(self.spawners, spawner)
end



-- Test map.
local mapTest = function(self, world, sw,sh)
    -- Safe zones for player spawn points.
    table.insert(self.spawnPoints, {0.25*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.75*sw,0.25*sh})
    table.insert(self.spawnPoints, {0.25*sw,0.75*sh})
    table.insert(self.spawnPoints, {0.75*sw,0.75*sh})

    -- Add enemy spawners.
    addSpawner(self, world, 1*sw,0.4*sh, sw,sh, ROT_WEST)
    addSpawner(self, world, 0*sw,0.6*sh, sw,sh, ROT_EAST)
    addSpawner(self, world, 0.3*sw,1*sh, sw,sh, ROT_NORTH)
    addSpawner(self, world, 0.7*sw,1*sh, sw,sh, ROT_NORTH)
    addSpawner(self, world, 0.6*sw,0*sh, sw,sh, ROT_SOUTH)

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

    -- Background.
    self.drawBack = function(self,mapX,mapY)
        local lg = love.graphics
        lg.setColor(1,1,1)
    end

    -- Foreground.
    self.drawFront = function(self)
        local lg = love.graphics
        lg.setColor(1,1,1)
    end
end



-- Island.
local mapIsland = function(self, world, sw,sh)
    -- Safe zones for player spawn points.
    table.insert(self.spawnPoints, {0.25*sw,0.3*sh})
    table.insert(self.spawnPoints, {0.8*sw,0.3*sh})
    table.insert(self.spawnPoints, {0.25*sw,0.75*sh})
    table.insert(self.spawnPoints, {0.8*sw,0.75*sh})

    -- Add enemy spawners.
    do
        addSpawner(self, world, 1*sw,0.8*sh, sw,sh, ROT_WEST)
        addSpawner(self, world, 1*sw,0.3*sh, sw,sh, ROT_WEST)
        addSpawner(self, world, 0*sw,0.8*sh, sw,sh, ROT_EAST)
        addSpawner(self, world, 0.3*sw,1*sh, sw,sh, ROT_NORTH)
        addSpawner(self, world, 0.7*sw,1*sh, sw,sh, ROT_NORTH)
        addSpawner(self, world, 0.8*sw,0*sh, sw,sh, ROT_SOUTH)
    end

    -- No navmesh.
    self.navMesh[1] = {{sw/2,sh/2}, {sw/2,sh/2}, {}}

    -- Block off the water.
    do
        local border = addBody(self, world, 0,0)
        newFixture(border, newEdgeShape(0,0.4*sh, 0.18*sw,0.18*sh)):setCategory(PHYS_CATEGORY_HOLE)
        newFixture(border, newEdgeShape(0.18*sw,0.18*sh, 0.4*sw,0)):setCategory(PHYS_CATEGORY_HOLE)
    end

    -- Textures.
    local waterFPS = 30
    local waters = {}
    for i=0,39 do
        local water = love.graphics.newImage("assets/water_128px_frames/" .. string.format("%04i", i) .. ".png")
        water:setWrap("repeat", "repeat")
        waters[i] = water
    end
    local waterFullscreen = love.graphics.newQuad(0,0, sw,sh, waters[0])

    local sandImg = love.graphics.newImage("assets/seamlessTextures/100_1180_seamless.JPG")
    sandImg:setWrap("repeat", "repeat")
    local sandScale = 0.4
    local sandFullscreen = love.graphics.newQuad(0,0, sw/sandScale,sh/sandScale, sandImg)

    local grassImg = love.graphics.newImage("assets/grass-set-00/grass03.png")
    grassImg:setWrap("repeat", "repeat")
    local grassScale = 0.3
    local grassFullscreen = love.graphics.newQuad(0,0, sw/grassScale,sh/grassScale, grassImg)

    local paveImg = love.graphics.newImage("assets/seamlessTextures/100_1453_seamless.JPG")
    paveImg:setWrap("repeat", "repeat")
    local paveScale = 0.2
    local paveFullscreen = love.graphics.newQuad(0,0, sw/paveScale,sh/paveScale, paveImg)

    -- Layout.
    local center = 1.5
    local sandR = 1.25
    local paveR = 0.6
    local cx,cy = (1+center)/2,(1+center)/2

    -- Shader approach.
    local canvas,shader
    if g_use_shaders then
        canvas = love.graphics.newCanvas()
        shader = love.graphics.newShader([[
            uniform Image waterImg;
            uniform Image sandImg;
            uniform Image grassImg;
            uniform Image paveImg;
            uniform float waterR;

            vec4 effect(vec4 color, Image canvas, vec2 texture_coords, vec2 screen_coords) {
                const float sandR = ]] .. sandR .. [[;
                const float paveR = ]] .. paveR .. [[;
                const vec2 cxy = vec2( ]] .. cx .. [[, ]] .. cy .. [[ );
                const float waterScale = 1.0 / 0.1;
                const float sandScale = 1.0 / ]] .. sandScale .. [[;
                const float grassScale = 1.0 / ]] .. grassScale .. [[;
                const float paveScale = 1.0 / ]] .. paveScale .. [[;

                // 2x width of blend region.
                const float blendRegion = 0.05;

                // Work out where we are.
                // TODO: this isn't very efficient, but it works
                float dist = length(texture_coords - cxy);
                vec4 ret = vec4(0,0,0,0);
                if (dist > waterR + blendRegion) {
                    // Water only.
                    ret = Texel(waterImg, texture_coords * waterScale);
                } else if (dist > waterR - blendRegion) {
                    // Blend between water and sand.
                    float t = (dist - (waterR - blendRegion)) / (2 * blendRegion);
                    vec4 a = Texel(waterImg, texture_coords * waterScale);
                    vec4 b = Texel(sandImg, texture_coords * sandScale);
                    ret = mix(b, a, t);

                } else if (dist > sandR + blendRegion) {
                    ret = Texel(sandImg, texture_coords * sandScale);
                } else if (dist > sandR - blendRegion) {
                    float t = (dist - (sandR - blendRegion)) / (2 * blendRegion);
                    vec4 a = Texel(sandImg, texture_coords * sandScale);
                    vec4 b = Texel(grassImg, texture_coords * grassScale);
                    ret = mix(b, a, t);

                } else if (dist > paveR + blendRegion) {
                    ret = Texel(grassImg, texture_coords * grassScale);
                } else if (dist > paveR - blendRegion) {
                    float t = (dist - (paveR - blendRegion)) / (2 * blendRegion);
                    vec4 a = Texel(grassImg, texture_coords * grassScale);
                    vec4 b = Texel(paveImg, texture_coords * paveScale);
                    ret = mix(b, a, t);

                } else {
                    ret = Texel(paveImg, texture_coords * paveScale);
                }
                return ret;
            }
        ]])
    end

    -- Background.
    self.drawBack = function(self,mapX,mapY)
        local lg = love.graphics
        local useShader = g_use_shaders

        local t = love.timer.getTime()
        local wi = math.floor(t * waterFPS) % #waters
        local waterImg = waters[wi]
        local waterR = center + (useShader and 0.03 or 0.01)*math.sin(t*2)

        --useShader = useShader and ((t%2)<1) -- for comparisons

        if useShader then
            shader:send("waterImg", waterImg)
            shader:send("sandImg", sandImg)
            shader:send("grassImg", grassImg)
            shader:send("paveImg", paveImg)
            shader:send("waterR", waterR)
            lg.setShader(shader)
            lg.setColor(1,1,1)
            lg.draw(canvas, 0,0) -- rectangle's aren't textured, so just throw a canvas at it
            lg.setShader()

        elseif true then
            local stencilFunc = function()
                -- Water = 0.
                -- Sand = 1.
                lg.ellipse("fill", sw*cx,sh*cy, sw*waterR,sh*waterR)
                -- Grass = 2.
                lg.ellipse("fill", sw*cx,sh*cy, sw*sandR,sh*sandR)
                -- Pavement = 3.
                lg.ellipse("fill", sw*cx,sh*cy, sw*paveR,sh*paveR)
            end
            lg.stencil(stencilFunc, "increment")

            lg.setColor(1,1,1)

            -- Water = 0.
            lg.setStencilTest("equal", 0)
            lg.draw(waterImg, waterFullscreen, 0,0)
            -- Sand = 1.
            lg.setStencilTest("equal", 1)
            lg.draw(sandImg, sandFullscreen, 0,0, 0, sandScale)
            -- Grass = 2.
            lg.setStencilTest("equal", 2)
            lg.draw(grassImg, grassFullscreen, 0,0, 0, grassScale)
            -- Pavement = 3.
            lg.setStencilTest("equal", 3)
            lg.draw(paveImg, paveFullscreen, 0,0, 0, paveScale)

            lg.setStencilTest()

        else
            -- Water
            lg.setStencilTest("equal", 0)
            lg.draw(waterImg, waterFullscreen, 0,0)
            -- Sand.
            lg.setColor(1,1,0)
            lg.ellipse("fill", sw*cx,sh*cy, sw*waterR,sh*waterR)
            -- Grass.
            lg.setColor(0,0.8,0)
            lg.ellipse("fill", sw*cx,sh*cy, sw*sandR,sh*sandR)
            -- Pavement.
            lg.setColor(0.5,0.5,0.5)
            lg.ellipse("fill", sw*cx,sh*cy, sw*paveR,sh*paveR)
        end
    end

    -- Foreground.
    self.drawFront = function(self)
        local lg = love.graphics
        lg.setColor(1,1,1)
    end
end



-- 2 roofs.
local mapRoofs = function(self, world, sw,sh)
    -- Walkway placements.
    local xl,xr = sw*0.2,sw*0.8
    local ww1y1,ww1y2 = sh/16,sh*3/16
    local ww2y1,ww2y2 = sh*7/16,sh*9/16
    local ww3y1,ww3y2 = sh*13/16,sh*15/16

    -- Safe zones for player spawn points.
    table.insert(self.spawnPoints, {xl/2,0.2*sh})
    table.insert(self.spawnPoints, {sw-xl/2,0.2*sh})
    table.insert(self.spawnPoints, {xl/2,0.8*sh})
    table.insert(self.spawnPoints, {sw-xl/2,0.8*sh})

    -- Add enemy spawners.
    do
        --addSpawner(self, world, 0,(ww1y2+ww2y1)/2, sw,sh, ROT_EAST)
        --addSpawner(self, world, sw,(ww1y2+ww2y1)/2, sw,sh, ROT_WEST)
        --addSpawner(self, world, 0,(ww2y2+ww3y1)/2, sw,sh, ROT_EAST)
        --addSpawner(self, world, sw,(ww2y2+ww3y1)/2, sw,sh, ROT_WEST)

        addSpawner(self, world, 0,0.2*sh, sw,sh, ROT_EAST)
        addSpawner(self, world, 0,0.6*sh, sw,sh, ROT_EAST)
        addSpawner(self, world, xl/2,sh, sw,sh, ROT_NORTH)
        addSpawner(self, world, sw,0.8*sh, sw,sh, ROT_WEST)
        addSpawner(self, world, sw,0.4*sh, sw,sh, ROT_WEST)
        addSpawner(self, world, (xr+sw)/2,0, sw,sh, ROT_SOUTH)
    end

    -- Holes for walkways.
    do
        local lines = {
            -- Top.
            {xl,0, xl,ww1y1, PHYS_CATEGORY_HOLE},
            {xr,0, xr,ww1y1, PHYS_CATEGORY_HOLE},
            {xl,ww1y1, xr,ww1y1, PHYS_CATEGORY_WALL},
            -- Spacer.
            {xl,ww1y2, xr,ww1y2, PHYS_CATEGORY_WALL},
            {xl,ww1y2, xl,ww2y1, PHYS_CATEGORY_HOLE},
            {xr,ww1y2, xr,ww2y1, PHYS_CATEGORY_HOLE},
            {xl,ww2y1, xr,ww2y1, PHYS_CATEGORY_WALL},
            -- Spacer.
            {xl,ww2y2, xr,ww2y2, PHYS_CATEGORY_WALL},
            {xl,ww2y2, xl,ww3y1, PHYS_CATEGORY_HOLE},
            {xr,ww2y2, xr,ww3y1, PHYS_CATEGORY_HOLE},
            {xl,ww3y1, xr,ww3y1, PHYS_CATEGORY_WALL},
            -- Bottom.
            {xl,sh, xl,ww3y2, PHYS_CATEGORY_HOLE},
            {xr,sh, xr,ww3y2, PHYS_CATEGORY_HOLE},
            {xl,ww3y2, xr,ww3y2, PHYS_CATEGORY_WALL},
        }

        local holes = addBody(self, world, 0,0)
        for _,line in ipairs(lines) do
            newFixture(holes, newEdgeShape(line[1],line[2], line[3],line[4])):setCategory(line[5])
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

    local railW = 0.02*sh

    -- Background.
    self.drawBack = function(self,mapX,mapY)
        local lg = love.graphics
        local t = love.timer.getTime()

        -- Floor below.
        lg.push()
        lg.clear(0,0,0)
        do
            lg.translate(-mapX/2,-mapY/2)

            -- Road.
            lg.setColor(1,1,1)
            local rw,rh = sw/20,sh/6
            lg.rectangle("fill", (sw-rw)/2,1*rh, rw,rh)
            lg.rectangle("fill", (sw-rw)/2,3*rh, rw,rh)
            lg.rectangle("fill", (sw-rw)/2,5*rh, rw,rh)

            -- Cars.
            lg.setColor(1,1,1)
            local cw,ch = sw/20,sh/6
            local cy = ((t % 10) - 2) * sh
            lg.rectangle("fill", (xl+sw/2-cw)/2,cy, cw,ch)
            lg.rectangle("fill", (xr+sw/2-cw)/2,4*sh-cy, cw,ch)

            -- Walls.
            local wallPad = 0.05*sw
            lg.setColor(0.6,0.4,0.3)
            lg.rectangle("fill", 0,0, xl+wallPad,sh)
            lg.rectangle("fill", xr-wallPad,0, xr+wallPad,sh)
        end
        lg.pop()

        -- Roofs.
        lg.setColor(0.9,0.8,0.7)
        lg.rectangle("fill", 0,0, xl,sh)
        lg.rectangle("fill", xr,0, xr,sh)

        -- Walkways.
        lg.setColor(0.75,0.75,0.75,0.8)
        lg.rectangle("fill", xl,ww1y1, xr-xl,ww1y2-ww1y1)
        lg.rectangle("fill", xl,ww2y1, xr-xl,ww2y2-ww2y1)
        lg.rectangle("fill", xl,ww3y1, xr-xl,ww3y2-ww3y1)
        lg.setColor(0.5,0.4,0)
        lg.rectangle("fill", xl,ww1y1-railW/2, xr-xl,railW)
        lg.rectangle("fill", xl,ww2y1-railW/2, xr-xl,railW)
        lg.rectangle("fill", xl,ww3y1-railW/2, xr-xl,railW)
    end

    -- Foreground.
    self.drawFront = function(self)
        local lg = love.graphics

        -- Walkways.
        lg.setColor(0.5,0.4,0)
        lg.rectangle("fill", xl,ww1y2-railW/2, xr-xl,railW)
        lg.rectangle("fill", xl,ww2y2-railW/2, xr-xl,railW)
        lg.rectangle("fill", xl,ww3y2-railW/2, xr-xl,railW)
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

        local addBorder = function(x0,y0, x1,y1, cat)
            local fixture = newFixture(border, newEdgeShape(x0,y0, x1,y1))
            -- We're a wall/gap, and we collide with everything.
            fixture:setCategory(cat)
        end

        -- Wall on the outside, hole on the inside.
        local bs = {}
        bs[PHYS_CATEGORY_WALL] = -10
        bs[PHYS_CATEGORY_HOLE] = 1
        for cat,p in pairs(bs) do
            addBorder(p,p, p,sh-p, cat)
            addBorder(p,p, sw-p,p, cat)
            addBorder(p,sh-p, sw-p,sh-p, cat)
            addBorder(sw-p,p, sw-p,sh-p, cat)
        end
    end

    -- Build the map from the choice.
    choice(m, world, sw,sh)
    return m
end



return {
    new = mapCreate,

    mapTest = mapTest,
    mapIsland = mapIsland,
    mapRoofs = mapRoofs,
    all = {
        mapIsland,
        mapRoofs,
    }
}
