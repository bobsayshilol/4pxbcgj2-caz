
local ENEMY_SPEED = 185
local THINK_EVERY = 1
local MAX_ON_SCREEN = 20



local updateClosestTarget = function(self, enemy)
    local x,y = enemy.body:getX(),enemy.body:getY()
    local bestPlayer = nil
    local bestScore = 1000000000

    for _,player in ipairs(self.players) do
        local dx,dy = player.body:getX()-x,player.body:getY()-y
        local dist = dx * dx + dy * dy
        if dist < bestScore then
            bestScore = dist
            bestPlayer = player
        end
    end

    enemy.target = bestPlayer
end



local trySpawnEnemy = function(self)
    -- Find an empty spawner.
    local spawner = nil
    -- TODO: randomise order
    for _,sp in ipairs(self.spawners) do
        -- TODO: proper querying
    end

    -- HACK: just use the spawner for now
    spawner = self.spawners[1]

    if not spawner then
        return
    end

    -- Make the new enemy.
    -- TODO: caching
    local x,y = spawner.x + love.math.random(), spawner.y + love.math.random()
    local body = love.physics.newBody(self.world, x,y, "dynamic")
    local shape = love.physics.newCircleShape(15)
    local fixture = love.physics.newFixture(body, shape, 100)

    -- We'll update the position manually.
    body:setFixedRotation(true)
    body:setLinearDamping(1)

    -- We're an enemy, and we collide with everything.
    fixture:setCategory(PHYS_CATEGORY_ENEMY)
    --fixture:setMask() -- TODO: need to disable walls when spawning

    -- Spawn the new enemy.
    local enemy = {
        body = body,
        shape = shape,
        fixture = fixture,

        health = self.baseHealth,
        target = nil,
        angle = 0,
    }
    fixture:setUserData(enemy)
    table.insert(self.enemies, enemy)

    -- Set it to follow a target.
    updateClosestTarget(self, enemy)
    return true
end



local managerUpdate = function(self, dt)
    self.lastThink = self.lastThink - dt
    if self.lastThink < 0 then
        self.lastThink = THINK_EVERY

        -- Retarget enemies.
        -- TODO: partial updates?
        for _,enemy in pairs(self.enemies) do
            updateClosestTarget(self, enemy)
        end
    end

    -- Kill off dead enemies.
    for k,enemy in pairs(self.enemies) do
        if enemy.health < 0 then
            enemy.body:destroy()
            self.enemies[k] = nil
            self.enemiesRemaining = self.enemiesRemaining - 1
        end
    end

    -- Movement.
    for _,enemy in pairs(self.enemies) do
        local target = enemy.target
        if target then
            local x,y = enemy.body:getX(),enemy.body:getY()
            local dx,dy = target.body:getX()-x,target.body:getY()-y
            local angle = math.atan2(dy, dx)
            local vx = ENEMY_SPEED * math.cos(angle)
            local vy = ENEMY_SPEED * math.sin(angle)
            enemy.angle = angle
            enemy.body:setLinearVelocity(vx, vy)
        end
    end

    -- Add new ones.
    local active = utils.size(self.enemies)
    if self.enemiesRemaining > active and active < MAX_ON_SCREEN then
        trySpawnEnemy(self)
    end

    return self.enemiesRemaining > 0
end

local managerDraw = function(self)
    for _,enemy in pairs(self.enemies) do
        -- TODO
    end
end

local managerNewRound = function(self)
    -- Setup this round.
    self.round = self.round + 1
    self.enemiesRemaining = self.enemiesThisRound --* #self.players

    -- Increase these for next time round.
    self.baseHealth = self.baseHealth * 1.08
    self.enemiesThisRound = self.enemiesThisRound + 3
end

local managerMake = function(world, players, spawners)
    local manager = {
        world = world,
        players = players,
        spawners = spawners,

        enemies = {},

        lastThink = 0,
        enemiesRemaining = 0,

        round = 0,
        baseHealth = 100,
        enemiesThisRound = 25,

        update = managerUpdate,
        draw = managerDraw,
        newRound = managerNewRound,
    }
    return manager
end



return {
    new = managerMake,
}
