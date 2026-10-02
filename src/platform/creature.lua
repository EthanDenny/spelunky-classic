-- Shared body, held-NPC, and player-contact rules for generated-level actors.
-- Kind-specific capabilities live beside the smaller enemies in enemies/.
local Types = require("src.platform.enemies.types")
local Holdable = require("src.platform.holdable")

local Creature = {}
Creature.__index = Creature

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

function Creature.supports(kind)
    return Types[kind] and Types[kind].creatureConfig ~= nil or false
end

function Creature.new(entity, metadata, options)
    options = options or {}
    local spec = Types[entity.kind]
    assert(spec and spec.creatureConfig, "Unsupported creature: " .. tostring(entity.kind))
    local config = spec.creatureConfig
    metadata = metadata or {}
    local width = config.width or metadata.width or 16
    local height = config.height or metadata.height or 16
    local originX = metadata.originX or 0
    local originY = metadata.originY or 0
    local anchorX, anchorY = entity.x * 16, entity.y * 16
    local insetX = spec.creatureInsetX or 0
    local insetY = spec.creatureInsetY or 0
    local creature = setmetatable({
        entity = entity,
        kind = entity.kind,
        spec = spec,
        config = config,
        x = anchorX - originX + width / 2 - insetX,
        y = anchorY - originY + height - insetY,
        vx = 0,
        vy = 0,
        width = width,
        height = height,
        drawOriginX = originX + insetX,
        drawOriginY = originY + insetY,
        hp = config.hp,
        alive = true,
        facing = options.facing or -1,
        timer = spec.creatureInitialTimer or 15 + ((options.seed or 1) % 30),
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
    if spec.initializeCreature then spec.initializeCreature(creature, options.seed) end
    return creature
end

function Creature:getCollisionHalfWidth()
    local width = self.spec.creatureHalfWidth
    if type(width) == "function" then return width(self) end
    return width or math.max(3, self.width / 2 - 2)
end

function Creature:getVerticalBounds()
    local bounds = self.spec.creatureVerticalBounds
    if type(bounds) == "function" then return bounds(self) end
    if bounds then return bounds[1], bounds[2] end
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
        if world:collidesSolid(self, self.x, nextY) then
            return direction > 0 and "floor" or "ceiling"
        end
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

function Creature:damage(amount, sourceX, hit)
    if not self.alive or self.spec.canDamage and not self.spec.canDamage(self) then return false end
    if self.spec.damage then return self.spec.damage(self, amount, sourceX, hit) end
    self.hp = self.hp - (amount or 1)
    self.stunned = self.hp > 0 and 20 or 0
    if sourceX then self.vx = self.x < sourceX and -3 or 3 end
    self.vy = -3
    if self.hp <= 0 then
        self.alive = false
        self.state = "dead"
    end
    if self.alive and hit then
        self.vx, self.vy = hit.vx or self.vx, hit.vy or self.vy
    end
    return true
end

function Creature:pickup(player)
    if not self.alive or not self.spec.canBeHeld or self.held then return false end
    self.held = true
    self.state = "held"
    self.vx, self.vy = 0, 0
    self:updateHeldPosition(player)
    return true
end

function Creature:updateHeldPosition(player)
    Holdable.position(self, player)
end

function Creature:throw(player, input, world)
    self.y = self.y - 4
    Holdable.throw(self, player, input, world)
    if self.spec.onThrown then self.spec.onThrown(self) end
end

function Creature:updateAI(world, player, context)
    self.spec.creatureStep(self, world, player, context)
end

function Creature:step(world, player, context)
    if not self.alive then return end
    if self.spec.stepCreature then
        self.spec.stepCreature(self, world, player, context)
        return
    end
    self.animation = self.animation + (self.spec.creatureAnimationPerTick or 0)
    if self.cooldown > 0 then self.cooldown = self.cooldown - 1 end
    if self.webbed > 0 then self.webbed = self.webbed - 1 return end
    if self.held then self:updateHeldPosition(player) return end
    if self.stunned > 0 then
        if self.spec.stunnedStep then
            self.spec.stunnedStep(self, world)
        else
            self.stunned = self.stunned - 1
            self:groundPhysics(world)
        end
        return
    end
    self:updateAI(world, player, context)
end

function Creature:resolvePlayerContact(player, previousY)
    if not self.alive or self.held or self.spec.canContact == false
        or not self:overlapsPlayer(player) then return end
    if self.spec.canReachPlayer and not self.spec.canReachPlayer(self, player) then return end
    if self.spec.resolvePlayerContact then return self.spec.resolvePlayerContact(self, player, previousY) end
    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    if player.vy > 0 and previousY + playerBottom <= enemyTop + 3 then
        local damage = player.equipment and player.equipment.spike_shoes and 3 or 1
        self:damage(damage, player.x)
        player.vy = -6
        player:setState("jumping")
        return "stomp"
    end
    if self.spec.contactPlayer then return self.spec.contactPlayer(self, player) end
    return player:hurt(self.x, 1, self.kind) and "hurt" or "invincible"
end

function Creature:draw(renderer)
    if not self.alive then return end
    if self.spec.drawCreature then return self.spec.drawCreature(self, renderer) end
    renderer:drawEntity({
        kind = self.kind,
        x = (self.x - self.width / 2 + self.drawOriginX) / 16,
        y = (self.y - self.height + self.drawOriginY) / 16,
        properties = self.entity.properties,
    })
end

return Creature
