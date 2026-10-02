-- Visual oBlood, oBone, oSkull, oSmokePuff and oRubbleSmall counterparts. These particles
-- never participate in player, enemy or treasure collision.
local Effects = {}
Effects.__index = Effects

local Types = require("src.platform.effects.types")

local images

local function bloodPixels(velocity, time)
    local magnitude = math.abs(velocity)
    local pixels = math.floor(magnitude)
    local fraction = magnitude - pixels
    if fraction > 0 and time % math.floor(1 / fraction + 0.5) == 0 then
        pixels = pixels + 1
    end
    return velocity < 0 and -pixels or pixels
end

local function bloodBlocked(world, x, y)
    return world:solidRect(x - 4, y - 4, x + 4, y + 4)
end

local function moveBlood(particle, world)
    local xPixels = bloodPixels(particle.vx, world.time or 0)
    local yPixels = bloodPixels(particle.vy, world.time or 0)
    for _ = 1, math.abs(xPixels) do
        local direction = xPixels > 0 and 1 or -1
        if bloodBlocked(world, particle.x + direction, particle.y) then break end
        particle.x = particle.x + direction
    end
    for _ = 1, math.abs(yPixels) do
        local direction = yPixels > 0 and 1 or -1
        if bloodBlocked(world, particle.x, particle.y + direction) then break end
        particle.y = particle.y + direction
    end
end

local function moveFlame(particle, world)
    local xPixels = bloodPixels(particle.vx, world.time or 0)
    local yPixels = bloodPixels(particle.vy, world.time or 0)
    for _ = 1, math.abs(xPixels) do
        local direction = xPixels > 0 and 1 or -1
        if bloodBlocked(world, particle.x + direction, particle.y) then
            particle.vx = -particle.vx * 0.5
            break
        end
        particle.x = particle.x + direction
    end
    for _ = 1, math.abs(yPixels) do
        local direction = yPixels > 0 and 1 or -1
        if bloodBlocked(world, particle.x, particle.y + direction) then
            if direction < 0 then
                particle.vy = -particle.vy * 0.8
            else
                particle.vy = particle.vy > 1 and -particle.vy * 0.5 or 0
                particle.life = math.min(particle.life, particle.age + 12)
            end
            break
        end
        particle.y = particle.y + direction
    end
end

function Effects.loadAssets()
    if images then return images end
    images = {}
    for kind, spec in pairs(Types) do
        images[kind] = {}
        for index = 1, spec.count or 1 do
            local path = spec.path or spec.directory
                and string.format("%simage %d.png", spec.directory, index - 1)
                or string.format("%s%03d.png", spec.prefix, index - 1)
            local image = love.graphics.newImage(path)
            image:setFilter("nearest", "nearest")
            images[kind][index] = image
        end
    end
    return images
end

function Effects.new(seed)
    return setmetatable({
        particles = {},
        trails = {},
        random = love.math.newRandomGenerator(seed or 1),
    }, Effects)
end

function Effects:add(kind, x, y, vx, vy)
    local definition = assert(Types[kind], "Unknown effect: " .. tostring(kind))
    local particle = {
        kind = kind, x = x, y = y, vx = vx or 0, vy = vy or 0,
        age = 0, life = definition.life,
    }
    if definition.randomGravity then
        particle.gravity = self.random:random(1, 6) * 0.1
    elseif definition.gravity then particle.gravity = definition.gravity end
    if definition.initialVy then particle.vy = definition.initialVy end
    self.particles[#self.particles + 1] = particle
    return particle
end

function Effects:explosion(x, y)
    for _ = 1, 3 do
        self:add("flame", x, y,
            self.random:random() * 4 - self.random:random() * 4,
            -1 - self.random:random() * 2)
    end
end

function Effects:terrainBreak(x, y, tileSize)
    local half = (tileSize or 16) / 2
    self:add("rubbleLarge", x + self.random:random(-half, half),
        y + self.random:random(-half, half))
    for _ = 1, 2 do
        self:add("rubble", x + self.random:random(-half, half),
            y + self.random:random(-half, half))
    end
end

function Effects:blood(x, y, count)
    local active = 0
    for _, particle in ipairs(self.particles) do
        if particle.kind == "blood" then active = active + 1 end
    end
    for _ = 1, count or 1 do
        if active >= 16 then break end
        self:add("blood", x, y,
            self.random:random() * 4 - self.random:random() * 4,
            -1 - self.random:random() * 2)
        active = active + 1
    end
end

local function breakVelocity(random, side)
    if side == "left" then return random:random(1, 3) end
    if side == "right" then return -random:random(1, 3) end
    return random:random(1, 3) - random:random(1, 3)
end

function Effects:jarBreak(x, y, side)
    self:add("smoke", x, y, 0, -0.1)
    for _ = 1, 3 do
        self:add("rubble", x - 2, y - 2,
            breakVelocity(self.random, side),
            (side == "ceiling" and 1 or -1) * self.random:random(0, 3))
    end
end

function Effects:skullBreak(x, y, side)
    self:add("smoke", x, y, 0, -0.1)
    for _ = 1, self.random:random(1, 2) do
        self:add("bone", x - 2, y - 2,
            breakVelocity(self.random, side),
            (side == "ceiling" and 1 or -1) * self.random:random(0, 3))
    end
end

function Effects:skeletonBreak(x, y)
    for _ = 1, 3 do
        self:add("bone", x, y,
            self.random:random() * 4 - self.random:random() * 4,
            -1 - self.random:random() * 2)
    end
    self:add("skull", x, y,
        self.random:random(0, 3) - self.random:random(0, 3),
        -self.random:random(1, 3))
end

function Effects:update(world)
    for index = #self.trails, 1, -1 do
        local trail = self.trails[index]
        trail.age = trail.age + 1
        if trail.age * 0.8 >= Types.bloodTrail.count then
            table.remove(self.trails, index)
        end
    end
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.age = particle.age + 1
        local spec = Types[particle.kind]
        if spec.motion == "detritus" then
            if particle.life <= 0 then
                table.remove(self.particles, index)
            else
                particle.life = particle.life - 1
                if spec.trail and particle.age % 4 == 1 and #self.trails < 12 then
                    self.trails[#self.trails + 1] = {
                        x = particle.x, y = particle.y, age = 0,
                    }
                end
                -- oBlood's first alarm enables detritus bounce before its first step.
                moveBlood(particle, world)
                if particle.vy < 6 then particle.vy = particle.vy + particle.gravity end
                local hitCeiling = particle.vy < 0
                    and bloodBlocked(world, particle.x, particle.y - 1)
                local hitSide = bloodBlocked(world, particle.x - 1, particle.y)
                    or bloodBlocked(world, particle.x + 1, particle.y)
                local onFloor = bloodBlocked(world, particle.x, particle.y + 1)
                -- oSkull is an item: hard impacts break it, and gentle landings slow it.
                local skullDestroyed = spec.fragile
                    and (hitCeiling or (hitSide and math.abs(particle.vx) > 2)
                        or (onFloor and particle.vy > 3))
                if hitCeiling then
                    particle.vy = -particle.vy * 0.8
                end
                if hitSide then
                    particle.vx = -particle.vx * 0.5
                end
                local removed = false
                if onFloor then
                    particle.vy = particle.vy > 1 and -particle.vy * 0.5 or 0
                    if spec.floorLife then
                        particle.life = math.min(particle.life, spec.floorLife)
                    elseif spec.removeOnFloor then
                        self:add("smoke", particle.x, particle.y, 0, -0.1)
                        table.remove(self.particles, index)
                        removed = true
                    elseif spec.floorFriction then
                        particle.vx = math.abs(particle.vx) < 0.1
                            and 0 or particle.vx * spec.floorFriction
                    end
                end
                if skullDestroyed then
                    table.remove(self.particles, index)
                    removed = true
                end
                if not removed and ((spec.maxFallSpeed and particle.vy > spec.maxFallSpeed)
                    or particle.x < -16 or particle.y < -16
                    or particle.x > world.width * 16 + 16
                    or particle.y > world.height * 16 + 16) then
                    table.remove(self.particles, index)
                end
            end
        else
            if spec.motion == "flame" and particle.age % 2 == 0 then
                local trails = 0
                for _, active in ipairs(self.particles) do
                    if active.kind == "flameTrail" then trails = trails + 1 end
                end
                if trails < 12 then
                    self:add("flameTrail", particle.x, particle.y)
                end
            end
            if spec.motion == "flame" then
                moveFlame(particle, world)
                particle.vy = math.min(6, particle.vy + particle.gravity)
            else
                particle.x = particle.x + particle.vx
                particle.y = particle.y + particle.vy
            end
            if spec.resetVertical then particle.vy = 0
            elseif spec.motion ~= "flame" then particle.vy = particle.vy + (spec.gravity or 0) end
            if particle.age >= particle.life
                or particle.x < -16 or particle.y < -16
                or particle.x > world.width * 16 + 16
                or particle.y > world.height * 16 + 16
                or (spec.stopAtTerrain and world:solidAtPoint(particle.x, particle.y)) then
                if spec.smokeOnDeath then
                    self:add("smoke", particle.x, particle.y, 0, -0.1)
                end
                table.remove(self.particles, index)
            end
        end
    end
end

function Effects:draw()
    local sprites = Effects.loadAssets()
    for _, trail in ipairs(self.trails) do
        local frame = math.floor(trail.age * 0.8) + 1
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprites.bloodTrail[frame],
            math.floor(trail.x), math.floor(trail.y), 0, 1, 1, Types.bloodTrail.origin, Types.bloodTrail.origin)
    end
    for _, particle in ipairs(self.particles) do
        local spec = Types[particle.kind]
        local frame = 1
        if spec.frameSpeed then
            local ageFrame = math.floor(particle.age * spec.frameSpeed)
            frame = spec.loop and ageFrame % spec.count + 1 or math.min(spec.count, ageFrame + 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprites[particle.kind][frame],
            math.floor(particle.x), math.floor(particle.y), 0, 1, 1, spec.origin, spec.origin)
    end
end

return Effects
