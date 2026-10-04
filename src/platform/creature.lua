-- Shared body, held-NPC, and player-contact rules for generated-level actors.
-- Kind-specific capabilities live beside the smaller enemies in enemies/.
local Types = require("src.platform.enemies.types")
local Holdable = require("src.platform.holdable")
local PhysicalBody = require("src.platform.physical_body")

local ActorBody = require("src.platform.actor_body")
local Creature = {}
Creature.__index = Creature

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
        STATES = { idle = "idle", walk = "walk", attack = "attack", stunned = "stunned",
            bones = "bones", rise = "rise" },
        sightTimer = 0,
    }, Creature)
    local random = love.math.newRandomGenerator(options.seed or 1)
    creature.random = function(a, b) return random:random(a, b) end
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
    return ActorBody.bounds(self)
end

Creature.overlapsRectangle = ActorBody.overlapsRectangle
Creature.overlapsPlayer = ActorBody.overlapsPlayer

function Creature:setState(state, timer)
    self.state, self.timer = state, timer or 0
end

function Creature:moveHorizontal(world, amount)
    return ActorBody.moveHorizontal(self, world, amount)
end

function Creature:moveVertical(world, amount)
    return ActorBody.moveVertical(self, world, amount)
end

function Creature:groundPhysics(world, gravity, terminalVelocity)
    local hitWall = self:moveHorizontal(world, self.vx)
    local vertical = self:moveVertical(world, self.vy)
    if hitWall then self.vx = -self.vx end
    if vertical == "floor" then self.vy = 0 end
    if vertical == "ceiling" then self.vy = 1 end
    if vertical ~= "floor" then self.vy = math.min(terminalVelocity or 8, self.vy+(gravity or 0.6)) end
    return vertical == "floor" or world:groundBelow(self) ~= nil
end

function Creature:updateGroundPhysics(world)
    local wall = self:moveHorizontal(world, self.vx)
    local vertical = self:moveVertical(world, self.vy)
    if vertical == "floor" then self.vy = 0
    elseif vertical == "ceiling" then self.vy = 1
    else self.vy = math.min(8, self.vy+0.6) end
    return wall, vertical
end

function Creature:web(duration)
    self.webbed = math.max(self.webbed, duration or 60)
end

function Creature:damage(amount, sourceX, hit)
    if not self.alive or self.spec.canDamage and not self.spec.canDamage(self, hit) then return false end
    if self.spec.damage then
        local damaged = self.spec.damage(self, amount, sourceX, hit)
        if self.hp <= 0 and self.spec.sacrifice then self.corpse = true end
        return damaged
    end
    self.hp = self.hp - (amount or 1)
    local stun = self.spec.stunDuration
    if type(stun) == "function" then stun = stun(hit) end
    self.stunned = self.hp > 0 and (stun or 20) or 0
    if sourceX then self.vx = self.x < sourceX and -3 or 3 end
    self.vy = -3
    if self.hp > 0 and self.spec.sacrifice then self.state = "stunned" end
    if self.hp <= 0 then
        self.alive = false
        self.corpse = self.spec.sacrifice ~= nil
        self.state = "dead"
    end
    if self.alive and hit then
        self.vx, self.vy = hit.vx or self.vx, hit.vy or self.vy
    end
    return true
end

function Creature:pickup(player)
    if not (self.alive or self.corpse) or not self.spec.canBeHeld or self.held or self.rescued then return false end
    if not self.spec.holdWhenHealthy and not self.corpse and self.stunned <= 0 then return false end
    self.held, self.impaled = true, false
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

function Creature:checkEmbedded(world, context)
    if self.held or self.rescued or self.kind == "ghost" then return end
    if world:solidAtPoint(self.x, self.y-8) then
        self.hp, self.alive, self.corpse = 0, false, false
        if context and self.spec.sacrifice then context.effects:blood(self.x, self.y-8, 3) end
    end
end

function Creature:step(world, player, context)
    if not (self.alive or self.corpse) then return end
    if self.spec.updateExit and self.spec.updateExit(self) then return end
    if not require("src.platform.activity").enemy(world, self) then return end
    if self.held then
        self:updateHeldPosition(player)
        self.animation = self.animation + 0.5
        if self.spec.heldStep then self.spec.heldStep(self, world, player, context) end
        if self.alive and not self.spec.holdWhenHealthy then
            if self.stunned > 0 then self.stunned = self.stunned - 1
            else
                self.held = false
                self.state = self.spec.recoveryState or "idle"
                if context and context.heldNpc == self then context.heldNpc = nil end
            end
        end
        return
    end
    if self.corpse then
        if self.impaled then return end
        PhysicalBody.stepItem(world, self)
        PhysicalBody.stopInWeb(world, self)
        return
    end
    if self.spec.stepCreature then
        self.spec.stepCreature(self, world, player, context)
        self:checkEmbedded(world, context)
        return
    end
    self.animation = self.animation + (self.spec.creatureAnimationPerTick or 0)
    if self.cooldown > 0 then self.cooldown = self.cooldown - 1 end
    if self.webbed > 0 then self.webbed = self.webbed - 1 return end
    if self.stunned > 0 then
        if self.spec.stunnedStep then
            self.spec.stunnedStep(self, world)
        else
            self.stunned = self.stunned - 1
            self:groundPhysics(world)
        end
        return
    end
    if self.state == "stunned" then self.state = self.spec.recoveryState or "idle" end
    self:updateAI(world, player, context)
    self:checkEmbedded(world, context)
end

function Creature:resolvePlayerContact(player, previousY, context)
    if not self.alive or self.held or (self.spec.sacrifice and self.stunned > 0)
        or self.spec.canContact == false
        or not self:overlapsPlayer(player) then return end
    if self.spec.canReachPlayer and not self.spec.canReachPlayer(self, player) then return end
    if self.spec.resolvePlayerContact then return self.spec.resolvePlayerContact(self, player, previousY, context) end
    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    if player.vy > 0 and previousY + playerBottom <= enemyTop + 3 then
        return ActorBody.stomp(self, player, self.spec.sacrifice)
    end
    if self.spec.contactPlayer then return self.spec.contactPlayer(self, player) end
    return player:hurt(self.x, 1, self.kind, nil, "enemy_contact") and "hurt" or "invincible"
end

function Creature:draw(renderer)
    if not (self.alive or self.corpse) then return end
    if self.spec.drawCreature then return self.spec.drawCreature(self, renderer) end
    renderer:drawEntity({
        kind = self.kind,
        x = (self.x - self.width / 2 + self.drawOriginX) / 16,
        y = (self.y - self.height + self.drawOriginY) / 16,
        properties = self.entity.properties,
    })
end

return Creature
