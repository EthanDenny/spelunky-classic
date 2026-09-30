-- Visual oBlood, oSmokePuff and oRubbleSmall counterparts. These particles
-- never participate in player, enemy or treasure collision.
local Effects = {}
Effects.__index = Effects

local ASSETS = {
    blood = { prefix = "assets/original/animations/sBlood/", count = 3, origin = 4 },
    smoke = { prefix = "assets/original/animations/sSmokePuff/", count = 8, origin = 4 },
    rubble = { path = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sRubbleSmall.images/image 0.png", origin = 4 },
}

local images

function Effects.loadAssets()
    if images then return images end
    images = {}
    for kind, spec in pairs(ASSETS) do
        images[kind] = {}
        for index = 1, spec.count or 1 do
            local path = spec.path or string.format("%s%03d.png", spec.prefix, index - 1)
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
        random = love.math.newRandomGenerator(seed or 1),
    }, Effects)
end

function Effects:add(kind, x, y, vx, vy)
    local particle = {
        kind = kind, x = x, y = y, vx = vx or 0, vy = vy or 0,
        age = 0, life = kind == "blood" and 60 or (kind == "smoke" and 20 or 45),
    }
    self.particles[#self.particles + 1] = particle
    return particle
end

function Effects:blood(x, y, count)
    for _ = 1, count or 1 do
        self:add("blood", x, y,
            self.random:random() * 8 - self.random:random() * 8,
            -1 - self.random:random() * 2)
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

function Effects:update(world)
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.age = particle.age + 1
        particle.x = particle.x + particle.vx
        particle.y = particle.y + particle.vy
        if particle.kind == "blood" then
            particle.vy = math.min(6, particle.vy + 0.6)
        elseif particle.kind == "smoke" then
            particle.vy = particle.vy + 0.1
        else
            particle.vy = particle.vy + 0.6
        end
        if particle.age >= particle.life
            or particle.x < -16 or particle.y < -16
            or particle.x > world.width * 16 + 16
            or particle.y > world.height * 16 + 16
            or (particle.kind == "rubble" and world:solidAtPoint(particle.x, particle.y)) then
            table.remove(self.particles, index)
        end
    end
end

function Effects:draw()
    local sprites = Effects.loadAssets()
    for _, particle in ipairs(self.particles) do
        local spec = ASSETS[particle.kind]
        local frame = 1
        if particle.kind == "smoke" then
            frame = math.min(spec.count, math.floor(particle.age * 0.4) + 1)
        elseif particle.kind == "blood" then
            frame = math.min(spec.count, math.floor(particle.age * 0.3) % spec.count + 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprites[particle.kind][frame],
            math.floor(particle.x), math.floor(particle.y), 0, 1, 1, spec.origin, spec.origin)
    end
end

return Effects
