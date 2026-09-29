local Creature = {}
Creature.__index = Creature

local CONFIG = {
    caveman = { ai = "ground", hp = 3, speed = 1.1 },
    skeleton = { ai = "ground", hp = 1, speed = 1.0 },
    zombie = { ai = "ground", hp = 1, speed = 0.7 },
    hawkman = { ai = "ground", hp = 4, speed = 1.5, aggressive = true },
    yeti = { ai = "ground", hp = 5, speed = 1.0, aggressive = true },
    frog = { ai = "hopper", hp = 1, speed = 2.0 },
    fire_frog = { ai = "hopper", hp = 1, speed = 2.2, explosive = true },
    vampire = { ai = "flyer", hp = 6, speed = 1.5, aggressive = true },
    ufo = { ai = "flyer", hp = 1, speed = 1.0, shooter = true },
    ghost = { ai = "flyer", hp = 999, speed = 0.75, aggressive = true, lethal = true },
    alien = { ai = "ground", hp = 1, speed = 1.1, aggressive = true },
    magma_man = { ai = "hopper", hp = 200, speed = 2.0, aggressive = true, burning = true },
    piranha = { ai = "aquatic", hp = 1, speed = 1.4, aggressive = true, width = 8, height = 8 },
    dead_fish = { ai = "aquatic", hp = 1, speed = 0 },
    monkey = { ai = "ground", hp = 1, speed = 1.4, aggressive = true },
    mantrap = { ai = "stationary", hp = 3, aggressive = true },
    jaws = { ai = "stationary", hp = 4, aggressive = true },
    giant_spider = { ai = "hopper", hp = 10, speed = 3, aggressive = true, width = 32 },
    tomb_lord = { ai = "boss", hp = 20, speed = 1.2, aggressive = true, width = 32, height = 32 },
    alien_boss = { ai = "boss", hp = 10, speed = 1.1, aggressive = true, width = 32, height = 32 },
    yeti_king = { ai = "boss", hp = 30, speed = 1.0, aggressive = true, width = 32, height = 32 },
    olmec = { ai = "olmec", hp = 1, speed = 0, aggressive = true, invincible = true, width = 64, height = 64 },
    damsel = { ai = "damsel", hp = 4, speed = 1.2, npc = true },
    shopkeeper = { ai = "shopkeeper", hp = 20, speed = 2.8, aggressive = true, npc = true },
    tunnel_man = { ai = "stationary", hp = 20, speed = 0, npc = true },
    worshipper = { ai = "ground", hp = 3, speed = 0.8 },
}

function Creature.supports(kind)
    return CONFIG[kind] ~= nil
end

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

local function distanceSquared(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

function Creature.new(entity, metadata, options)
    options = options or {}
    local config = assert(CONFIG[entity.kind], "Unsupported creature: " .. tostring(entity.kind))
    metadata = metadata or {}
    local width = config.width or metadata.width or 16
    local height = config.height or metadata.height or 16
    local originX = metadata.originX or 0
    local originY = metadata.originY or 0
    local anchorX, anchorY = entity.x * 16, entity.y * 16
    local x = anchorX - originX + width / 2
    local y = anchorY - originY + height
    return setmetatable({
        entity = entity,
        kind = entity.kind,
        config = config,
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        width = width,
        height = height,
        drawOriginX = originX,
        drawOriginY = originY,
        hp = config.hp,
        alive = true,
        facing = options.facing or -1,
        timer = 15 + ((options.seed or 1) % 30),
        cooldown = 0,
        stunned = 0,
        webbed = 0,
        held = false,
        rescued = false,
        angry = options.angry or false,
        forSale = entity.properties and entity.properties.forSale,
        shopType = entity.properties and entity.properties.shopType,
        state = "idle",
        dropThroughTimer = 0,
    }, Creature)
end

function Creature:getCollisionHalfWidth()
    return math.max(3, self.width / 2 - 2)
end

function Creature:getVerticalBounds()
    return -self.height + 2, 0
end

function Creature:getBounds()
    local half = self:getCollisionHalfWidth()
    local top, bottom = self:getVerticalBounds()
    return self.x - half, self.y + top, self.x + half, self.y + bottom
end

function Creature:overlapsRectangle(left, top, right, bottom)
    local a, b, c, d = self:getBounds()
    return left < c and right > a and top < d and bottom > b
end

function Creature:overlapsPlayer(player)
    local half = player:getCollisionHalfWidth()
    local top, bottom = player:getVerticalBounds()
    return self:overlapsRectangle(player.x - half, player.y + top,
        player.x + half, player.y + bottom)
end

function Creature:moveHorizontal(world, amount)
    local direction = sign(amount)
    for _ = 1, math.floor(math.abs(amount) + 0.5) do
        if world:collidesSolid(self, self.x + direction, self.y) then return true end
        self.x = self.x + direction
    end
    return false
end

function Creature:moveVertical(world, amount)
    local direction = sign(amount)
    for _ = 1, math.floor(math.abs(amount) + 0.5) do
        local nextY = self.y + direction
        if world:collidesSolid(self, self.x, nextY) then return direction > 0 and "floor" or "ceiling" end
        if direction > 0 then
            local landing = world:platformLanding(self, self.y, nextY)
            if landing then self.y = landing return "floor" end
        end
        self.y = nextY
    end
end

function Creature:groundPhysics(world)
    self.vy = math.min(8, self.vy + 0.6)
    local hitWall = self:moveHorizontal(world, self.vx)
    local vertical = self:moveVertical(world, self.vy)
    if hitWall then self.vx = -self.vx end
    if vertical == "floor" then self.vy = 0 end
    if vertical == "ceiling" then self.vy = 1 end
    return vertical == "floor" or world:groundBelow(self) ~= nil
end

function Creature:web(duration)
    self.webbed = math.max(self.webbed, duration or 60)
end

function Creature:damage(amount, sourceX)
    if not self.alive then return false end
    if self.kind == "ghost" or self.config.invincible then return false end
    self.hp = self.hp - (amount or 1)
    self.stunned = self.hp > 0 and 20 or 0
    if sourceX then self.vx = self.x < sourceX and -3 or 3 end
    self.vy = -3
    if self.hp <= 0 then
        self.alive = false
        self.state = "dead"
    end
    return true
end

function Creature:pickup(player)
    if not self.alive or self.kind ~= "damsel" or self.held then return false end
    self.held = true
    self.state = "held"
    self.vx, self.vy = 0, 0
    self:updateHeldPosition(player)
    return true
end

function Creature:updateHeldPosition(player)
    self.x = player.x + player.facing * 3
    self.y = player.y + 3
end

function Creature:throw(player, input)
    self.held = false
    self.state = "stunned"
    self.stunned = 90
    self.vx = player.facing * 5 + player.vx
    self.vy = input and input.up and -7 or -3
end

function Creature:updateAI(world, player, context)
    local ai = self.config.ai
    local dist2 = player and distanceSquared(self, player) or math.huge
    if ai == "stationary" then
        self.vx = 0
    elseif ai == "aquatic" then
        local target = player and player.x or self.x
        self.facing = target < self.x and -1 or 1
        self.vx = self.facing * self.config.speed
        self:moveHorizontal(world, self.vx)
        if not world:cellAt("liquid", self.x, self.y - 3) then self.vy = self.vy + 0.3 end
        self:moveVertical(world, self.vy)
        return
    elseif ai == "flyer" then
        if player and dist2 < 180 * 180 then
            self.facing = player.x < self.x and -1 or 1
            self.vx = self.vx * 0.8 + sign(player.x - self.x) * self.config.speed * 0.2
            self.vy = self.vy * 0.8 + sign(player.y - self.y) * self.config.speed * 0.15
            self:moveHorizontal(world, self.vx)
            self:moveVertical(world, self.vy)
            if self.config.shooter and self.cooldown == 0 and context and context.projectiles then
                context.projectiles:spawn("bullet", self.x, self.y - 5,
                    sign(player.x - self.x) * 7, sign(player.y - self.y) * 0.5, self,
                    { damage = 1, life = 50 })
                self.cooldown = 60
            end
        end
        return
    elseif ai == "hopper" then
        local grounded = self:groundPhysics(world)
        self.timer = self.timer - 1
        if grounded and self.timer <= 0 then
            self.facing = player and player.x < self.x and -1 or 1
            self.vx = self.facing * self.config.speed
            self.vy = self.kind == "giant_spider" and -5 or -4
            self.timer = 20
        end
        return
    elseif ai == "olmec" then
        self.timer = self.timer - 1
        if player and self.vy <= 0 then
            self.vx = sign(player.x - self.x) * 0.8
            self:moveHorizontal(world, self.vx)
        end
        if player and math.abs(player.x - self.x) < 40 and self.timer <= 0 then
            self.vy = 8
            self.timer = 45
        end
        local landed = self:moveVertical(world, self.vy)
        if landed == "floor" then
            world:destroyTerrain(self.x, self.y, 28)
            self.vy = -2
        else
            self.vy = self.vy + 0.5
        end
        return
    elseif ai == "shopkeeper" then
        self.angry = self.angry or (context and context.run and context.run.shopkeeperAnger > 0)
        if not self.angry then
            self.facing = player and player.x < self.x and -1 or 1
            self.vx = 0
        elseif player then
            self.facing = player.x < self.x and -1 or 1
            self.vx = self.facing * self.config.speed
            if self.cooldown == 0 and dist2 < 120 * 120 and context and context.projectiles then
                for spread = -1, 1 do
                    context.projectiles:spawn("pellet", self.x, self.y - 7,
                        self.facing * 10, spread * 0.45, self, { damage = 1, life = 24 })
                end
                self.cooldown = 30
            end
        end
    elseif ai == "damsel" then
        self.timer = self.timer - 1
        if self.timer <= 0 then
            self.facing = -self.facing
            self.timer = 90
        end
        self.vx = self.facing * 0.35
    elseif ai == "boss" then
        self.facing = player and player.x < self.x and -1 or 1
        self.vx = self.facing * self.config.speed
        if player and dist2 < 70 * 70 and self.cooldown == 0 then
            if self.kind == "alien_boss" and context and context.projectiles then
                for spread = -1, 1 do
                    context.projectiles:spawn("bullet", self.x, self.y - 12,
                        self.facing * 7, spread * 0.6, self, { damage = 1, life = 60 })
                end
            elseif self.kind == "tomb_lord" and context and context.projectiles then
                context.projectiles:spawn("bullet", self.x, self.y - 12,
                    self.facing * 5, -1.5, self, { damage = 2, gravity = 0.15, life = 80 })
            else
                self.vy = -5
            end
            self.cooldown = 40
        end
    else
        if player and (self.config.aggressive or dist2 < 80 * 80) then
            self.facing = player.x < self.x and -1 or 1
        elseif self.timer <= 0 then
            self.facing = -self.facing
            self.timer = 45
        end
        self.timer = self.timer - 1
        self.vx = self.facing * self.config.speed
    end
    self:groundPhysics(world)
end

function Creature:step(world, player, context)
    if not self.alive then return end
    if self.kind == "olmec" and world:cellAt("lava", self.x, self.y - 2) then
        self.alive = false
        self.state = "defeated"
        return
    end
    if self.cooldown > 0 then self.cooldown = self.cooldown - 1 end
    if self.webbed > 0 then self.webbed = self.webbed - 1 return end
    if self.held then self:updateHeldPosition(player) return end
    if self.stunned > 0 then
        self.stunned = self.stunned - 1
        self:groundPhysics(world)
        return
    end
    self:updateAI(world, player, context)
end

function Creature:resolvePlayerContact(player, previousY)
    if not self.alive or self.held or self.kind == "damsel" or not self:overlapsPlayer(player) then return end
    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    if player.vy > 0 and previousY + playerBottom <= enemyTop + 3 then
        local damage = player.equipment and player.equipment.spike_shoes and 3 or 1
        self:damage(damage, player.x)
        player.vy = -6
        player:setState("jumping")
        return "stomp"
    end
    if self.config.lethal then
        player.invincibleTimer = 0
        return player:hurt(self.x, player.health, "ghost") and "hurt" or "invincible"
    end
    if self.config.burning then
        return player:burn(self.x) and "hurt" or "invincible"
    end
    local amount = (self.kind == "giant_spider" or self.config.ai == "boss") and 2 or 1
    return player:hurt(self.x, amount, self.kind) and "hurt" or "invincible"
end

function Creature:draw(renderer)
    if not self.alive then return end
    renderer:drawEntity({
        kind = self.kind,
        x = (self.x - self.width / 2 + self.drawOriginX) / 16,
        y = (self.y - self.height + self.drawOriginY) / 16,
        properties = self.entity.properties,
    })
end

return Creature
