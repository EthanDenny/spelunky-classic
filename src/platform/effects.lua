-- Visual oBlood, oBone, oSkull, oSmokePuff and oRubbleSmall counterparts. These particles
-- never participate in player, enemy or treasure collision.
local Effects = {}
Effects.__index = Effects

local ASSETS = {
    blood = { prefix = "assets/original/animations/sBlood/", count = 3, origin = 4 },
    bloodTrail = { prefix = "assets/original/animations/sBloodTrail/", count = 7, origin = 4 },
    smoke = { prefix = "assets/original/animations/sSmokePuff/", count = 8, origin = 4 },
    rubble = { path = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sRubbleSmall.images/image 0.png", origin = 4 },
    rubbleLarge = { path = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sRubble.images/image 0.png", origin = 4 },
    bone = { directory = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sBone.images/", count = 8, origin = 4 },
    skull = { path = "assets/original/entities/skull.png", origin = 4 },
    flame = { path = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sFlame.images/image 0.png", origin = 4 },
    flameTrail = { prefix = "assets/original/animations/sFlameTrail/", count = 5, origin = 4 },
}

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
    for kind, spec in pairs(ASSETS) do
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
    local particle = {
        kind = kind, x = x, y = y, vx = vx or 0, vy = vy or 0,
        age = 0, life = kind == "blood" and 60 or kind == "bone" and 60
            or kind == "skull" and 120
            or kind == "flame" and 30 or kind == "flameTrail" and 8
            or (kind == "smoke" and 20 or 45),
    }
    if kind == "blood" or kind == "bone" or kind == "flame" then
        particle.gravity = self.random:random(1, 6) * 0.1
    elseif kind == "skull" then
        particle.gravity = 0.6
    end
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

function Effects:jarBreak(x, y)
    self:add("smoke", x, y, 0, -0.1)
    for _ = 1, 3 do
        self:add("rubble", x - 2, y - 2,
            self.random:random(1, 3) - self.random:random(1, 3),
            -self.random:random(0, 3))
    end
end

function Effects:skullBreak(x, y)
    self:add("smoke", x, y, 0, -0.1)
    for _ = 1, self.random:random(1, 2) do
        self:add("bone", x - 2, y - 2,
            self.random:random(1, 3) - self.random:random(1, 3),
            -self.random:random(0, 3))
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
        if trail.age * 0.8 >= ASSETS.bloodTrail.count then
            table.remove(self.trails, index)
        end
    end
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.age = particle.age + 1
        if particle.kind == "blood" or particle.kind == "bone" or particle.kind == "skull" then
            if particle.life <= 0 then
                table.remove(self.particles, index)
            else
                particle.life = particle.life - 1
                if particle.kind == "blood" and particle.age % 4 == 1 and #self.trails < 12 then
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
                local skullDestroyed = particle.kind == "skull"
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
                    if particle.kind == "blood" then
                        particle.life = math.min(particle.life, 20)
                    elseif particle.kind == "bone" then
                        self:add("smoke", particle.x, particle.y, 0, -0.1)
                        table.remove(self.particles, index)
                        removed = true
                    elseif particle.kind == "skull" then
                        particle.vx = math.abs(particle.vx) < 0.1
                            and 0 or particle.vx * 0.3
                    end
                end
                if skullDestroyed then
                    table.remove(self.particles, index)
                    removed = true
                end
                if not removed and ((particle.kind == "blood" and particle.vy > 6)
                    or particle.x < -16 or particle.y < -16
                    or particle.x > world.width * 16 + 16
                    or particle.y > world.height * 16 + 16) then
                    table.remove(self.particles, index)
                end
            end
        else
            if particle.kind == "flame" and particle.age % 2 == 0 then
                local trails = 0
                for _, active in ipairs(self.particles) do
                    if active.kind == "flameTrail" then trails = trails + 1 end
                end
                if trails < 12 then
                    self:add("flameTrail", particle.x, particle.y)
                end
            end
            if particle.kind == "flame" then
                moveFlame(particle, world)
                particle.vy = math.min(6, particle.vy + particle.gravity)
            else
                particle.x = particle.x + particle.vx
                particle.y = particle.y + particle.vy
            end
            if particle.kind == "smoke" then
                particle.vy = particle.vy + 0.1
            elseif particle.kind ~= "flameTrail" and particle.kind ~= "flame" then
                particle.vy = particle.vy + 0.6
            end
            if particle.age >= particle.life
                or particle.x < -16 or particle.y < -16
                or particle.x > world.width * 16 + 16
                or particle.y > world.height * 16 + 16
                or ((particle.kind == "rubble" or particle.kind == "rubbleLarge")
                    and world:solidAtPoint(particle.x, particle.y)) then
                if particle.kind == "flame" then
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
            math.floor(trail.x), math.floor(trail.y), 0, 1, 1, ASSETS.bloodTrail.origin, ASSETS.bloodTrail.origin)
    end
    for _, particle in ipairs(self.particles) do
        local spec = ASSETS[particle.kind]
        local frame = 1
        if particle.kind == "smoke" then
            frame = math.min(spec.count, math.floor(particle.age * 0.4) + 1)
        elseif particle.kind == "blood" then
            frame = math.min(spec.count, math.floor(particle.age * 0.3) % spec.count + 1)
        elseif particle.kind == "bone" then
            frame = math.floor(particle.age * 0.3) % spec.count + 1
        elseif particle.kind == "flameTrail" then
            frame = math.min(spec.count, math.floor(particle.age * 0.7) + 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprites[particle.kind][frame],
            math.floor(particle.x), math.floor(particle.y), 0, 1, 1, spec.origin, spec.origin)
    end
end

return Effects
