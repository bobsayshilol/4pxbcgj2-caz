
local navmesh = require("src/navmesh")

local ENEMY_SPEED = 150
local ENEMY_ATTACK_EVERY = 0.5
local ENEMY_DAMAGE = 10

local THINK_EVERY = 1
local MAX_ON_SCREEN = 20
local SPAWN_EVERY = 0.6
local PER_SPAWNER_EVERY = 1.8



-- Textures.
local textureEnemies = {}
for i=0,16 do
    local enemy = love.graphics.newImage("assets/tds_zombie/skeleton-move_" .. i .. ".png")
    textureEnemies[i] = enemy
end



local trySpawnEnemy = function(self)
    -- Check that the next spawner is empty.
    local order = self.order
    local spawner = order[#order]
    if not spawner then
        -- None left, remake ordering.
        for i,sp in ipairs(self.spawners) do
            order[i] = sp
        end
        utils.shuffle(order)
        return false

    elseif spawner.nextTime > 0 then
        -- Waiting for this one to empty.
        return false

    else
        -- Take this one.
        order[#order] = nil
        spawner.nextTime = PER_SPAWNER_EVERY
    end

    -- Make the new enemy.
    -- TODO: caching
    local x,y = spawner.x, spawner.y
    local body = love.physics.newBody(self.world, x,y, "dynamic")
    local shape = love.physics.newCircleShape(love.graphics.getWidth() / 100)
    local fixture = love.physics.newFixture(body, shape, 100)

    -- We'll update the position manually.
    body:setFixedRotation(true)
    body:setLinearDamping(1)

    -- We're an enemy, and we collide with everything (except for walls, temporarily).
    fixture:setCategory(PHYS_CATEGORY_ENEMY)
    fixture:setMask(PHYS_CATEGORY_WALL, PHYS_CATEGORY_HOLE)

    -- Spawn the new enemy.
    local enemy = {
        body = body,
        shape = shape,
        fixture = fixture,

        health = self.baseHealth,
        target = nil,
        angle = 0,

        damaging = {},
        nextHit = 0,
    }
    fixture:setUserData(enemy)
    table.insert(self.enemies, enemy)

    -- Start walking to the spawner entrance.
    enemy.target = spawner.entrance
    return true
end



local managerUpdate = function(self, dt)
    self.lastThink = self.lastThink - dt
    if self.lastThink < 0 then
        self.lastThink = THINK_EVERY

        -- Retarget enemies.
        -- TODO: partial updates?
        -- TODO: if needed
    end

    -- Kill off dead enemies.
    for k,enemy in pairs(self.enemies) do
        if enemy.health < 0 then
            -- Take the enemy out of our collections.
            self.enemies[k] = nil
            self.enemiesRemaining = self.enemiesRemaining - 1

            -- Trigger the callback.
            self.onKill(enemy)

            -- Finally destroy the enemy.
            enemy.body:destroy()
        end
    end

    -- Build a lookup for where the closest player is.
    -- TODO: cache this in the thinker
    local playerLookup = navmesh.buildLookup(self.navMesh, self.players)
    self.navMeshDists = playerLookup

    -- Movement.
    local speed = ENEMY_SPEED
    if self.round < 10 then
        speed = speed * (self.round + 10) / 24
    end
    for _,enemy in pairs(self.enemies) do
        do
            local b = enemy.body
            local x,y = b:getX(),b:getY()
            local target = enemy.target
            local dx,dy
            if target then
                -- If there's a target then go to it.
                -- TODO: would need pathfinding for general case
                local tx,ty = target:getX(),target:getY()
                dx,dy = tx-x,ty-y

                -- See if we can finish the entrance "animation".
                local dist = dx*dx+dy*dy
                if dist < 100 then
                    enemy.target = nil

                    -- Restore wall collisions.
                    enemy.fixture:setMask()
                end
            else
                -- Query the navmesh on which way to go.
                dx,dy = navmesh.query(self.navMesh, playerLookup, self.players, x,y)
            end

            if dx ~= nil then
                local angle = math.atan2(dy, dx)
                local vx = speed * math.cos(angle)
                local vy = speed * math.sin(angle)
                enemy.angle = angle
                b:setLinearVelocity(vx, vy)
            end
        end
    end

    -- Attack.
    -- Note: this invalidates playerLookup since players could die here
    for _,enemy in pairs(self.enemies) do
        enemy.nextHit = enemy.nextHit - dt
        if enemy.nextHit < 0 and utils.size(enemy.damaging) > 0 then
            enemy.nextHit = ENEMY_ATTACK_EVERY
            -- TODO: attack effect
            for p,t in pairs(enemy.damaging) do
                p.health = p.health - ENEMY_DAMAGE
            end
        end
    end

    -- Add new ones.
    local active = utils.size(self.enemies)
    self.nextSpawn = self.nextSpawn - dt
    if self.nextSpawn < 0 and self.enemiesRemaining > active and active < MAX_ON_SCREEN then
        if trySpawnEnemy(self) then
            -- Scale spawn time up.
            local every = SPAWN_EVERY
            if self.round < 5 then
                every = every / ((self.round + 5) / 10)
            end
            self.nextSpawn = every
        end
    end

    -- Update spawners.
    for _,sp in pairs(self.spawners) do
        sp.nextTime = sp.nextTime - dt
    end

    return self.enemiesRemaining > 0
end

local managerDraw = function(self)
    local lg = love.graphics
    lg.setColor(1,1,1,1)

    local t = love.timer.getTime()
    local fps = 30
    local ti = math.floor(t * fps) % #textureEnemies
    local img = textureEnemies[ti]
    local scale = 1.6 -- magic number
    local iw,ih = 2*scale/img:getWidth(),2*scale/img:getHeight()

    for _,enemy in pairs(self.enemies) do
        local body = enemy.body
        local x,y = body:getX(),body:getY()
        local r = enemy.shape:getRadius()

        --lg.circle("fill", x,y, r)
        local dy = -0.5*r -- BODGE to match sprite
        lg.push()
        lg.translate(x,y)
        lg.rotate(enemy.angle)
        lg.draw(img, -r,-r+dy, 0, r*iw,r*ih)
        lg.pop()
    end
end

local managerNewRound = function(self)
    -- Setup this round.
    self.round = self.round + 1
    self.enemiesRemaining = self.enemiesThisRound --* #self.players
    self.order = {}
    for _,sp in pairs(self.spawners) do
        sp.nextTime = 0
    end

    -- Increase these for next time round.
    self.baseHealth = self.baseHealth * 1.09
    self.enemiesThisRound = math.min(self.enemiesThisRound + 3, 60)
end

local managerKillAll = function(self)
    -- TODO: duplicates update loop
    for k,enemy in pairs(self.enemies) do
        -- Take the enemy out of our collections.
        self.enemies[k] = nil
        self.enemiesRemaining = self.enemiesRemaining - 1

        -- Trigger the callback.
        self.onKill(enemy)

        -- Finally destroy the enemy.
        enemy.body:destroy()
    end
end

local managerChangeMap = function(self, map)
    self.spawners = map.spawners
    self.navMesh = map.navMesh
    self.order = {}
    self.navMeshDists = nil
end

local managerMake = function(world, players, onKill)
    local manager = {
        world = world,
        players = players,
        navMesh = nil,
        navMeshDists = nil,
        onKill = onKill,
        spawners = nil,
        order = {},

        enemies = {},

        lastThink = 0,
        nextSpawn = 0,
        enemiesRemaining = 0,

        round = 0,
        baseHealth = 100,
        enemiesThisRound = 10,

        update = managerUpdate,
        draw = managerDraw,
        newRound = managerNewRound,
        killAll = managerKillAll,
        changeMap = managerChangeMap,
    }
    return manager
end



return {
    new = managerMake,
}
