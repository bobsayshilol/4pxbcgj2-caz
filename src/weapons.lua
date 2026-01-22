local WeaponTypes = {
    SMG = {
        name = "SMG",
        bps = 10,
        speed = 1500,
        vib = { 0.2, 0.5, 0.1},
    },
}

local weaponMake = function(world, typ, pid)
    local weapon = {
        world = world,
        typ = typ,
        pid = pid,

        lastShot = 0,

        update = function(self, dt)
            self.lastShot = self.lastShot - dt
        end,

        tryShoot = function(self, bullets, x,y, angle)
            if self.lastShot <= 0 then
                self.lastShot = 1 / self.typ.bps

                -- Make the new bullet.
                -- TODO: caching
                local body = love.physics.newBody(self.world, x,y, "dynamic")
                local shape = love.physics.newCircleShape(3)
                local fixture = love.physics.newFixture(body, shape, 0)

                -- We're a bullet, and we collide with everything except for bullets and players.
                fixture:setCategory(PHYS_CATEGORY_BULLET)
                fixture:setMask(PHYS_CATEGORY_PLAYER, PHYS_CATEGORY_BULLET)

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

                    shooter = self.pid,
                    hit = false,

                    draw = function(self)
                        local x,y = self.body:getX(),self.body:getY()
                        --bullet.angle
                        love.graphics.circle("fill", x,y, self.shape:getRadius())
                    end,
                }
                fixture:setUserData(bullet)
                table.insert(bullets, bullet)

                -- Feedback.
                local js = g_globals.pidToJs[self.pid]
                local vib = self.typ.vib
                js:setVibration(vib[1], vib[2], vib[3])

                return true
            end
            return false
        end,
    }
    return weapon
end



return {
    types = WeaponTypes,
    new = weaponMake,
}
