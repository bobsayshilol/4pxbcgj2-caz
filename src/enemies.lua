
local ENEMY_SPEED = 185
local ENEMY_ATTACK_EVERY = 0.5
local ENEMY_DAMAGE = 10

local THINK_EVERY = 1
local MAX_ON_SCREEN = 20
local SPAWN_EVERY = 0.8
local PER_SPAWNER_EVERY = 1.8



local updateClosestTarget = function(self, enemy)
    if enemy.animating then return end

    local x,y = enemy.body:getX(),enemy.body:getY()
    local bestPlayer = nil
    local bestScore = 1000000000

    for _,player in ipairs(self.players) do
        if player.health > 0 then
            local dx,dy = player.body:getX()-x,player.body:getY()-y
            local dist = dx * dx + dy * dy
            if dist < bestScore then
                bestScore = dist
                bestPlayer = player
            end
        end
    end

    enemy.target = bestPlayer and bestPlayer.body
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
        return
    elseif spawner.nextTime > 0 then
        -- Waiting for this one to empty.
        return
    else
        -- Take this one.
        order[#order] = nil
        spawner.nextTime = PER_SPAWNER_EVERY
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

    -- We're an enemy, and we collide with everything (except for walls, temporarily).
    fixture:setCategory(PHYS_CATEGORY_ENEMY)
    fixture:setMask(PHYS_CATEGORY_WALL)

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

        animating = false,
    }
    fixture:setUserData(enemy)
    table.insert(self.enemies, enemy)

    -- Start walking to the spawner entrance.
    enemy.animating = true
    enemy.target = spawner.entrance
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
            -- Take the enemy out of our collections.
            self.enemies[k] = nil
            self.enemiesRemaining = self.enemiesRemaining - 1

            -- Trigger the callback.
            self.onKill(enemy)

            -- Finally destroy the enemy.
            enemy.body:destroy()
        end
    end

    -- Movement.
    local speed = ENEMY_SPEED
    if self.round < 10 then
        speed = speed * (self.round + 10) / 20
    end
    for _,enemy in pairs(self.enemies) do
        local target = enemy.target
        if target then
            local b = enemy.body
            local x,y = b:getX(),b:getY()
            local dx,dy = target:getX()-x,target:getY()-y
            local angle = math.atan2(dy, dx)
            local vx = speed * math.cos(angle)
            local vy = speed * math.sin(angle)
            enemy.angle = angle
            b:setLinearVelocity(vx, vy)

            -- See if we can finish the entrance "animation".
            local dist = dx*dx+dy*dy
            if enemy.animating and dist < 100 then
                enemy.animating = false

                -- Restore wall collisions.
                enemy.fixture:setMask()

                -- Find a player to chase.
                updateClosestTarget(self, enemy)
            end
        end

        -- Attack.
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
    for _,enemy in pairs(self.enemies) do
        -- TODO
    end
end

local managerNewRound = function(self)
    -- Setup this round.
    self.round = self.round + 1
    self.enemiesRemaining = self.enemiesThisRound --* #self.players

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

local managerMake = function(world, players, spawners, onKill)
    local manager = {
        world = world,
        players = players,
        onKill = onKill,
        spawners = spawners,
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
    }
    return manager
end



return {
    new = managerMake,
}
