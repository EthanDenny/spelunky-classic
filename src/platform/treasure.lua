-- Loose oTreasure instances have their own gravity and collision response.
-- Generated placements remain at their authored positions until disturbed;
-- freshly released jar treasure starts active and cannot be collected for 20 ticks.
local Treasure = {}
Treasure.__index = Treasure

function Treasure.new(entity, released)
    return setmetatable({
        entity = entity,
        alive = true,
        active = released or false,
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
    return 4
end

function Treasure:getVerticalBounds()
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
    local hitSide = self:move(world, "x", self.vx)
    local hitVertical = self:move(world, "y", self.vy)
    if hitSide then self.vx = -self.vx * 0.5 end
    if hitVertical then
        if self.vy < 0 then
            self.vy = -self.vy * 0.8
        else
            self.vy = 0
            self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
            if self.vx == 0 then self.active = false end
        end
    else
        self.vy = math.min(8, self.vy + 0.6)
    end
    self.entity.x, self.entity.y = self.x / 16, self.y / 16
end

return Treasure
