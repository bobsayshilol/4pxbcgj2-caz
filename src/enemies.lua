
local ENEMY_SPEED = 1
local THINK_EVERY = 5
local MAX_ON_SCREEN = 3



local trySpawnEnemy = function(self)
    -- Find an empty spawner.
    local spawner = nil
    -- TODO: randomise order
    for _,sp in ipairs(self.spawners) do
        -- TODO: proper querying
    end

    -- HACK: just use the spawner for now
    spawner = self.spawners[1]
    spawner.x = spawner.x + love.math.random()
    spawner.y = spawner.y + love.math.random()

    if not spawner then
        return
    end

    -- Make the new enemy.
    -- TODO: caching
    local body = love.physics.newBody(self.world, spawner.x,spawner.y, "dynamic")
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
        target = nil, -- TODO
    }

    -- TODO

    fixture:setUserData(enemy)
    table.insert(self.enemies, enemy)
    return true
end



local managerUpdate = function(self, dt)
    self.lastThink = self.lastThink - dt
    if self.lastThink < 0 then
        self.lastThink = THINK_EVERY

        -- Retarget enemies.
        -- TODO
    end

    -- Update directions.
    -- TODO

    -- Kill off dead enemies.
    for k,enemy in pairs(self.enemies) do
        if enemy.health < 0 then
            enemy.body:destroy()
            self.enemies[k] = nil
        end
    end

    -- Add new ones.
    local active = utils.size(self.enemies)
    if self.enemiesRemaining > active and active < MAX_ON_SCREEN then
        if trySpawnEnemy(self) then
            self.enemiesRemaining = self.enemiesRemaining - 1
        end
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
    self.enemiesRemaining = self.numEnemiesPerPlayer * self.numPlayers

    -- Increase these for next time round.
    self.baseHealth = self.baseHealth * 1.1
    self.numEnemiesPerPlayer = self.numEnemiesPerPlayer + 1
end

local managerMake = function(world, numPlayers, spawners)
    local manager = {
        world = world,
        numPlayers = numPlayers,
        spawners = spawners,

        enemies = {},

        lastThink = 0,
        enemiesRemaining = 0,

        round = 1,
        baseHealth = 100,
        numEnemiesPerPlayer = 10,

        update = managerUpdate,
        draw = managerDraw,
        newRound = managerNewRound,
    }
    return manager
end



return {
    new = managerMake,
}
