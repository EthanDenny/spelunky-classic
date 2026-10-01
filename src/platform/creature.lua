local Creature = {}
Creature.__index = Creature
local GiantSpider = require("src.platform.giant_spider")

local skeletonSprites

local function loadSkeletonSprites()
    if skeletonSprites then return skeletonSprites end
    skeletonSprites = { walk = {} }
    local idle = love.graphics.newImage(
        "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Skeleton/sSkeletonLeft.images/image 0.png")
    idle:setFilter("nearest", "nearest")
    skeletonSprites.idle = idle
    for index = 0, 4 do
        local image = love.graphics.newImage(string.format(
            "assets/original/animations/sSkeletonWalkLeft/%03d.png", index))
        image:setFilter("nearest", "nearest")
        skeletonSprites.walk[#skeletonSprites.walk + 1] = image
    end
    return skeletonSprites
end

local CONFIG = {
    caveman = { ai = "ground", hp = 3, speed = 1.1 },
    skeleton = { ai = "ground", hp = 1, speed = 1.0 },
    ghost = { ai = "flyer", hp = 999, speed = 0.75, aggressive = true, lethal = true },
    giant_spider = { hp = 10, width = 32 },
    damsel = { ai = "damsel", hp = 4, speed = 1.2, npc = true },
    shopkeeper = { ai = "shopkeeper", hp = 20, speed = 2.8, aggressive = true, npc = true },
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
    -- oGhost's 24px sprite has a smaller mask at (4, 0)-(12, 16).
    local insetX = entity.kind == "ghost" and 4 or 0
    local insetY = entity.kind == "ghost" and 8 or 0
    local x = anchorX - originX + width / 2 - insetX
    local y = anchorY - originY + height - insetY
    local creature = setmetatable({
        entity = entity,
        kind = entity.kind,
        config = config,
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        width = width,
        height = height,
        drawOriginX = originX + insetX,
        drawOriginY = originY + insetY,
        hp = config.hp,
        alive = true,
        facing = options.facing or -1,
        timer = entity.kind == "skeleton" and 20 or 15 + ((options.seed or 1) % 30),
        animation = 0,
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
    if creature.kind == "giant_spider" then GiantSpider.initialize(creature, options.seed) end
    return creature
end

function Creature:getCollisionHalfWidth()
    if self.kind == "giant_spider" and self.state == "hang" then return 16 end
    if self.kind == "damsel" or self.kind == "ghost" then return 4 end
    return math.max(3, self.width / 2 - 2)
end

function Creature:getVerticalBounds()
    -- oGiantSpiderHang masks its whole 16px sprite; oGiantSpider masks only
    -- the lower 16px of its 32px animation (setCollisionBounds(2,16,30,32)).
    if self.kind == "giant_spider" then return -16, 0 end
    if self.kind == "damsel" then return -12, 0 end
    if self.kind == "ghost" then return -16, 0 end
    return -self.height, 0
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

function Creature:groundPhysics(world, gravity, terminalVelocity)
    self.vy = math.min(terminalVelocity or 8, self.vy + (gravity or 0.6))
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
    if self.kind == "ghost" then return false end
    self.hp = self.hp - (amount or 1)
    if self.kind == "giant_spider" then
        if self.hp <= 0 then self.alive, self.state = false, "dead" end
        return true
    end
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
    if ai == "ground" and self.kind == "skeleton" then
        if self.timer > 0 then
            self.timer = self.timer - 1
            self.vx = 0
        else
            self.vx = self.facing * self.config.speed
        end
        local before = self.vx
        self:groundPhysics(world)
        if before ~= 0 and self.vx ~= before then self.facing = -self.facing end
        return
    elseif ai == "flyer" then
        if player and dist2 < 180 * 180 then
            self.facing = player.x < self.x and -1 or 1
            self.vx = self.vx * 0.8 + sign(player.x - self.x) * self.config.speed * 0.2
            self.vy = self.vy * 0.8 + sign(player.y - self.y) * self.config.speed * 0.15
            self:moveHorizontal(world, self.vx)
            self:moveVertical(world, self.vy)
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
    if self.kind == "giant_spider" then
        GiantSpider.step(self, world, player, context)
        return
    end
    if self.kind == "skeleton" then self.animation = self.animation + 1 end
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
    local amount = self.kind == "giant_spider" and 2 or 1
    return player:hurt(self.x, amount, self.kind) and "hurt" or "invincible"
end

function Creature:draw(renderer)
    if not self.alive then return end
    if self.kind == "giant_spider" then
        GiantSpider.draw(self)
        return
    end
    if self.kind == "skeleton" then
        local sprites = loadSkeletonSprites()
        local image = self.vx == 0 and sprites.idle
            or sprites.walk[(math.floor(self.animation * 0.5) % #sprites.walk) + 1]
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, math.floor(self.x), math.floor(self.y - self.height),
            0, self.facing < 0 and 1 or -1, 1, 8, 0)
        return
    end
    renderer:drawEntity({
        kind = self.kind,
        x = (self.x - self.width / 2 + self.drawOriginX) / 16,
        y = (self.y - self.height + self.drawOriginY) / 16,
        properties = self.entity.properties,
    })
end

return Creature
