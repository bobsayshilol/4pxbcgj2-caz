local rpgImages = {}
for i=0,5 do
    rpgImages[i] = love.graphics.newImage("assets/smokeParticleAssets/whitePuff0" .. i .. ".png")
end

local WeaponTypes = {
    SMG = {
        name = "SMG",
        bps = 10,
        speed = 1500,
        damage = 70,
        vib = { 0.2, 0.3, 0.1 },
        duration = nil, -- infinite
        displayFor = 0.3,
        drawImpact = function(impact)
            local fade = impact.displaying / 0.3 -- must match above
            love.graphics.setColor(1,1,1,fade)
            love.graphics.circle("fill", impact.x,impact.y, 5)
        end,
    },
    Minigun = {
        name = "Minigun",
        bps = 20,
        speed = 2000,
        damage = 120,
        vib = { 0.6, 1.0, 0.1 },
        duration = 12,
        displayFor = 0.3,
        drawImpact = function(impact)
            local fade = impact.displaying / 0.3 -- must match above
            love.graphics.setColor(1,1,1,fade)
            love.graphics.circle("fill", impact.x,impact.y, 8)
        end,
    },
    RPG = {
        name = "RPG",
        bps = 5,
        speed = 3000,
        damage = 500,
        vib = { 1.0, 0.4, 0.08 },
        duration = 12,
        displayFor = 2.5,
        drawImpact = function(impact)
            local fade = impact.displaying / 2.5 -- must match above
            fade = math.sqrt(fade)
            love.graphics.setColor(1,1,1,fade)
            local imgs = rpgImages
            local img = imgs[impact.imgIdx % (1+#imgs)]
            --love.graphics.circle("fill", impact.x,impact.y, 50)
            local r = 200
            local w,h = img:getWidth(),img:getHeight()
            love.graphics.draw(img, impact.x-r/4,impact.y-r/2, r/w,r/h)
        end,
    },
}

local bulletDraw = function(self)
    local lg = love.graphics

    local body = self.body
    lg.push()
    do
        lg.translate(body:getX(),body:getY())
        lg.rotate(self.angle)
        local r = self.shape:getRadius()
        local d = 2
        lg.rectangle("fill", -d*r,-r, (d+2)*r,2*r)
    end
    lg.pop()
end

local bulletDestroy = function(self, impacts)
    local body = self.body
    local x,y = self.body:getX(),self.body:getY()

    body:destroy()

    -- Don't do anything if it's offscreen.
    local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()
    if x < 0 or y < 0 or x > sw or y > sh then
        return
    end

    -- Add an impact effect.
    local impact = {
        displaying = self.typ.displayFor,
        x = x,
        y = y,
        imgIdx = love.math.random(100),
        draw = self.typ.drawImpact,
    }
    table.insert(impacts, impact)

    -- TODO: sound effect?
end

local weaponMake = function(world, typ, pid)
    local weapon = {
        world = world,
        typ = typ,
        pid = pid,

        lastShot = 0,
        duration = typ.duration,

        update = function(self, dt)
            self.lastShot = self.lastShot - dt

            -- Return true if we're still going.
            local empty = false
            if self.duration then
                self.duration = self.duration - dt
                empty = self.duration < 0
            end
            return empty
        end,

        tryShoot = function(self, bullets, x,y, angle)
            local didShoot = self.lastShot <= 0
            if didShoot then
                self.lastShot = 1 / self.typ.bps

                -- Make the new bullet.
                -- TODO: caching
                local body = love.physics.newBody(self.world, x,y, "dynamic")
                local shape = love.physics.newCircleShape(love.graphics.getWidth() / 500)
                local fixture = love.physics.newFixture(body, shape, 0)

                -- We're a bullet, and we collide with everything except for bullets and players and holes.
                fixture:setCategory(PHYS_CATEGORY_BULLET)
                fixture:setMask(PHYS_CATEGORY_HOLE, PHYS_CATEGORY_PLAYER, PHYS_CATEGORY_BULLET)

                -- Get it moving.
                local vx,vy = self.typ.speed*math.cos(angle),self.typ.speed*math.sin(angle)
                body:setLinearVelocity(vx, vy)

                -- Need continuous collision detection.
                body:setBullet(true)

                -- But no impact.
                --fixture:setSensor(true) -- this doesn't work with continuous collisions...

                -- Add it.
                local bullet = {
                    body = body,
                    shape = shape,
                    fixture = fixture,

                    angle = angle,

                    typ = typ,
                    damage = typ.damage,
                    pid = self.pid,
                    hit = false,

                    draw = bulletDraw,
                    destroy = bulletDestroy,
                }
                fixture:setUserData(bullet)
                table.insert(bullets, bullet)

                -- Feedback.
                local js = g_globals.pidToJs[self.pid]
                local vib = self.typ.vib
                js:setVibration(vib[1], vib[2], vib[3])
            end

            return didShoot
        end,
    }
    return weapon
end



return {
    types = WeaponTypes,
    new = weaponMake,
}
