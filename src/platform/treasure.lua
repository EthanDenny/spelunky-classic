-- Loose oTreasure instances have their own gravity and collision response.
-- oTreasure starts ACTIVE even when placed by the level generator. Its Step
-- event writes status=STATIC at rest, not state=STATIC, so gravity continues
-- to respond when the supporting tile disappears.
local Treasure = {}
Treasure.__index = Treasure

-- Source Create-event setCollisionBounds for the saleable oItem objects.
local SHOP_BOUNDS = {
    bomb_bag = { 6, -2, 6 }, bomb_box = { 6, -2, 8 },
    rope_pile = { 6, -5, 5 }, paste = { 6, -2, 6 },
    spectacles = { 6, -6, 6 }, compass = { 6, -6, 6 },
    parachute = { 6, -6, 6 }, cape = { 6, -6, 6 },
    spring_shoes = { 6, -6, 6 }, spike_shoes = { 6, -6, 6 },
    gloves = { 6, -6, 8 }, mitt = { 6, -6, 8 },
    jetpack = { 5, -5, 8 },
}

-- oGoldBars uses a full-height mask; smaller loose treasure uses the
-- four-pixel default below.
local TREASURE_BOUNDS = {
    gold_bars = { 7, -8, 8 },
}

function Treasure.new(entity, released)
    local physical = entity.properties and entity.properties.forSale or false
    return setmetatable({
        entity = entity,
        alive = true,
        active = true,
        physical = physical,
        collisionBounds = physical and assert(SHOP_BOUNDS[entity.kind],
            "Missing shop collision bounds for " .. entity.kind)
            or TREASURE_BOUNDS[entity.kind],
        x = entity.x * 16,
        y = entity.y * 16,
        vx = 0,
        vy = 0,
        pickupDelay = released and 20 or 0,
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

function Treasure:move(world, axis, amount)
    local remainder = axis .. "Remainder"
    self[remainder] = self[remainder] + amount
    local pixels = math.floor(math.abs(self[remainder]))
    local direction = self[remainder] < 0 and -1 or 1
    self[remainder] = self[remainder] - pixels * direction
    for _ = 1, pixels do
        local nextX = self.x + (axis == "x" and direction or 0)
        local nextY = self.y + (axis == "y" and direction or 0)
        if world:collidesSolid(self, nextX, nextY) then
            self[remainder] = 0
            return true
        end
        if axis == "y" and direction > 0 then
            local landing = world:platformLanding(self, self.y, nextY)
            if landing then
                self.y = landing
                self[remainder] = 0
                return true
            end
        end
        self.x, self.y = nextX, nextY
    end
    return false
end

function Treasure:update(world)
    if not self.alive then return end
    if self.pickupDelay > 0 then self.pickupDelay = self.pickupDelay - 1 end
    if not self.active then return end
    -- Classic's oItem Step lifts an item one pixel per tick when its lower
    -- collision bound starts inside the floor (weapon-shop bomb boxes do).
    if self.physical and world:collidesSolid(self, self.x, self.y) then
        self.y = self.y - 1
    end
    local hitSide = self:move(world, "x", self.vx)
    local hitVertical = self:move(world, "y", self.vy)
    if hitSide then self.vx = -self.vx * 0.5 end
    if hitVertical then
        if self.vy < 0 then
            self.vy = -self.vy * 0.8
        else
            self.vy = self.physical and self.vy > 1 and -self.vy * 0.5 or 0
            self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
        end
    else
        self.vy = math.min(8, self.vy + 0.6)
    end
    self.entity.x, self.entity.y = self.x / 16, self.y / 16
end

return Treasure
