local WeaponTypes = {
    SMG = {
        name = "SMG",
        bps = 10,
        speed = 1500,
        damage = 70,
        vib = { 0.2, 0.4, 0.1 },
        duration = nil, -- infinite
        --love.graphics.newImage("assets/"), -- TODO
        displayFor = 0.8,
        drawBullet = function(self)
            local fade = self.displaying / 0.8
            love.graphics.setColor(1,1,1,fade)
            love.graphics.circle("fill", self.x,self.y, 5)
        end,
    },
    Minigun = {
        name = "Minigun",
        bps = 20,
        speed = 2000,
        damage = 90,
        vib = { 0.6, 1.0, 0.1 },
        duration = 8,
        --love.graphics.newImage("assets/"), -- TODO
        displayFor = 0.8,
        drawBullet = function(self)
            local fade = self.displaying / 0.8
            love.graphics.setColor(1,1,1,fade)
            love.graphics.circle("fill", self.x,self.y, 8)
        end,
    },
    RPG = {
        name = "RPG",
        bps = 5,
        speed = 3000,
        damage = 400,
        vib = { 1.0, 0.4, 0.08 },
        duration = 10,
        --love.graphics.newImage("assets/"), -- TODO
        displayFor = 2.5,
        drawBullet = function(self)
            local fade = self.displaying / 2.5
            love.graphics.setColor(1,1,1,fade)
            love.graphics.circle("fill", self.x,self.y, 50)
        end,
    },
}

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

                    damage = typ.damage,
                    shooter = self.pid,
                    hit = false,

                    draw = function(self)
                        local x,y = self.body:getX(),self.body:getY()
                        --bullet.angle
                        love.graphics.circle("fill", x,y, self.shape:getRadius())
                    end,

                    destroy = function(self, impacts)
                        local x,y = self.body:getX(),self.body:getY()

                        -- Don't do anything if it's offscreen.
                        local sw,sh = love.graphics.getWidth(),love.graphics.getHeight()
                        if x < 0 or y < 0 or x > sw or y > sh then
                            return
                        end

                        -- Add an impact effect.
                        local impact = {
                            displaying = typ.displayFor,
                            x = x,
                            y = y,
                            draw = typ.drawBullet,
                        }
                        table.insert(impacts, impact)

                        -- TODO: sound effect?

                        self.body:destroy()
                    end,
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
