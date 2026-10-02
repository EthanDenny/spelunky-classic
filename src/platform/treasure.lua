-- Loose oTreasure instances have their own gravity and collision response.
-- oTreasure starts ACTIVE even when placed by the level generator. Its Step
-- event writes status=STATIC at rest, not state=STATIC, so gravity continues
-- to respond when the supporting tile disappears.
local Treasure = {}
Treasure.__index = Treasure
local PhysicalBody = require("src.platform.physical_body")
local ItemDefinitions = require("src.platform.item_definitions")

function Treasure.new(entity, released, game)
    local definition = ItemDefinitions[entity.kind]
    local pickup = assert(definition and definition.pickup, "Unknown treasure: " .. entity.kind)
    assert(pickup.money, "Non-treasure entity: " .. entity.kind)
    return setmetatable({
        entity = entity,
        kind = entity.kind,
        properties = entity.properties or {},
        definition = definition,
        spec = definition, hp = definition.hp, game = game,
        alive = true,
        active = true,
        collisionBounds = definition.treasureBounds,
        x = entity.x * 16 + (definition.treasureAnchor and definition.treasureAnchor[1] or 0),
        y = entity.y * 16 + (definition.treasureAnchor and definition.treasureAnchor[2] or 0),
        vx = 0,
        vy = 0,
        pickupDelay = definition.collectDelay or 0,
        dropThroughTimer = 0,
        xRemainder = 0,
        yRemainder = 0,
    }, Treasure)
end

function Treasure:getCollisionHalfWidth()
    return self.collisionBounds and self.collisionBounds[1] or 4
end

function Treasure:getVerticalBounds()
    if self.collisionBounds then return self.collisionBounds[2], self.collisionBounds[3] end
    return -4, 4
end

function Treasure:getBounds()
    local half = self:getCollisionHalfWidth()
    local top, bottom = self:getVerticalBounds()
    return self.x-half, self.y+top, self.x+half, self.y+bottom
end

function Treasure:damage(amount, _, hit)
    if not self.alive or not self.hp then return false end
    self.hp = self.hp-amount
    if hit then self.vx, self.vy = hit.vx or self.vx, hit.vy or self.vy end
    if self.hp <= 0 then
        self.alive = false
        if self.definition.onDeath and self.game then self.definition.onDeath(self, self.game) end
    end
    return true
end

function Treasure:syncEntity()
    local anchor = self.definition.treasureAnchor
    self.entity.x = (self.x - (anchor and anchor[1] or 0)) / 16
    self.entity.y = (self.y - (anchor and anchor[2] or 0)) / 16
end

function Treasure:update(world, player)
    if not self.alive then return end
    if self.pickupDelay > 0 then self.pickupDelay = self.pickupDelay - 1 end
    local Activity = require("src.platform.activity")
    if self.hp then
        if not Activity.enemy(world, self) then return end
    elseif not Activity.contains(world, self) then return end
    if not self.active then return end
    if self.definition.updateTreasure then
        self.definition.updateTreasure(self, world, player)
        self:syncEntity()
        return
    end
    -- oTreasure samples side/floor contacts before moveTo, unlike oItem.
    local left = PhysicalBody.probe(world, self, "x", -1)
    local right = PhysicalBody.probe(world, self, "x", 1)
    local bottom = PhysicalBody.probe(world, self, "y", 1)
    PhysicalBody.move(world, self, "x", self.vx)
    PhysicalBody.move(world, self, "y", self.vy)
    if not bottom then self.vy = math.min(8, self.vy + 0.6) end
    if PhysicalBody.probe(world, self, "y", -1) then
        if self.vy < 0 then self.vy = -self.vy * 0.8
        else self.y = self.y + 1 end
    end
    if left or right then self.vx = -self.vx * 0.5 end
    if bottom then
        self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
        self.y = self.y - 1
        if not PhysicalBody.probe(world, self, "y", 1) then self.y = self.y + 1 end
        self.vy = 0
    end
    if left then
        if not right then self.x = self.x + 1 end
    elseif right then self.x = self.x - 1 end
    PhysicalBody.stopInWeb(world, self)
    self:syncEntity()
end

function Treasure:overlapsRectangle(left, top, right, bottom)
    local half = self:getCollisionHalfWidth()
    local a, b = self:getVerticalBounds()
    return left <= self.x + half and right >= self.x - half
        and top <= self.y + b and bottom >= self.y + a
end

return Treasure
