local Item = {}
Item.__index = Item

local CARRYABLE = {
    rock = true,
    jar = true,
    skull = true,
    chest = true,
    locked_chest = true,
    crate = true,
    gold_idol = true,
    crystal_skull = true,
    key = true,
    die = true,
    bow = true,
    machete = true,
    mattock = true,
    pistol = true,
    shotgun = true,
    teleporter = true,
    web_cannon = true,
}

local HEAVY = {
    chest = true,
    locked_chest = true,
    crate = true,
    gold_idol = true,
    crystal_skull = true,
    die = true,
}

local CARRIED_AT_BODY = {
    gold_idol = true,
    crystal_skull = true,
}

local WEAPON = {
    bow = true,
    machete = true,
    mattock = true,
    pistol = true,
    shotgun = true,
    teleporter = true,
    web_cannon = true,
}

-- oItem uses depth 101 while loose; oSolid uses depth 100. GameMaker draws
-- higher depths first, allowing the foreground pixels of terrain to occlude
-- every loose item. Held items switch to depth 1 and are drawn in front.
local BEHIND_TERRAIN = {
    bomb_bag = true,
    bomb_box = true,
    bow = true,
    cape = true,
    chest = true,
    compass = true,
    crate = true,
    crown = true,
    crystal_skull = true,
    die = true,
    emerald_big = true,
    gloves = true,
    gold_bar = true,
    gold_bars = true,
    gold_idol = true,
    jar = true,
    jetpack = true,
    key = true,
    locked_chest = true,
    machete = true,
    mattock = true,
    mitt = true,
    parachute = true,
    paste = true,
    pistol = true,
    rock = true,
    rope_pile = true,
    ruby_big = true,
    sapphire_big = true,
    shotgun = true,
    skull = true,
    spectacles = true,
    spike_shoes = true,
    spring_shoes = true,
    teleporter = true,
    web_cannon = true,
}

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

function Item.isCarryable(kind)
    return CARRYABLE[kind] or false
end

function Item.rendersBehindTerrain(kind)
    return BEHIND_TERRAIN[kind] or false
end

function Item.new(entity, metadata)
    assert(Item.isCarryable(entity.kind), "Non-carryable entity: " .. tostring(entity.kind))
    metadata = metadata or {}
    return setmetatable({
        entity = entity,
        kind = entity.kind,
        properties = entity.properties or {},
        x = entity.x * 16,
        y = entity.y * 16,
        vx = 0,
        vy = 0,
        xRemainder = 0,
        yRemainder = 0,
        width = metadata.width or 16,
        height = metadata.height or 16,
        heavy = HEAVY[entity.kind] or false,
        weapon = WEAPON[entity.kind] or false,
        held = false,
        safeTimer = 0,
        dropThroughTimer = 0,
    }, Item)
end

function Item:getCollisionHalfWidth()
    return math.min(self.width / 2, self.heavy and 6 or 4)
end

function Item:getVerticalBounds()
    if self.heavy then return -8, 8 end
    return -math.min(4, self.height / 2), math.min(4, self.height / 2)
end

function Item:overlapsRectangle(left, top, right, bottom)
    local halfWidth = self:getCollisionHalfWidth()
    local topOffset, bottomOffset = self:getVerticalBounds()
    return left <= self.x + halfWidth and right >= self.x - halfWidth
        and top <= self.y + bottomOffset and bottom >= self.y + topOffset
end

function Item:pickup(player)
    if self.held then return false end
    self.held = true
    self.vx, self.vy = 0, 0
    self.xRemainder, self.yRemainder = 0, 0
    self:updateHeldPosition(player)
    return true
end

function Item:updateHeldPosition(player)
    self.x = player.x + player.facing * 4
    local crouched = player.state == "ducking" and math.abs(player.vx) < 2
    if self.heavy then
        if CARRIED_AT_BODY[self.kind] then
            self.y = player.y + (crouched and 2 or 0)
        else
            self.y = player.y + (crouched and -2 or -4)
        end
    else
        self.y = player.y + (crouched and 4 or 2)
    end
end

function Item:throw(player, input)
    input = input or {}
    self.held = false
    self.safeTimer = 10
    self.vx = player.facing * (self.heavy and 4 or 8) + player.vx
    self.vy = self.heavy and -2 or -3

    if input.up then
        self.vy = self.heavy and -4 or -9
    elseif input.down then
        if player:isGroundState() then
            self.y = self.y - 2
            self.vx = self.vx * 0.6
            self.vy = 0.5
        else
            self.vy = 3
        end
    end
end

function Item:dropWeapon(player)
    self.held = false
    self.safeTimer = 10
    self.vx = (player.facing * (self.heavy and 4 or 8) + player.vx) * 0.4
    self.vy = 0.5
    self.x = player.x
    self.y = player.y
end

function Item:dropFromHurt(player)
    self.held = false
    self.safeTimer = 10
    self.vx = player.vx
    self.vy = -6
end

function Item:consumePixels(axis, amount)
    local field = axis .. "Remainder"
    self[field] = self[field] + amount
    local pixels = math.floor(math.abs(self[field])) * sign(self[field])
    self[field] = self[field] - pixels
    return pixels
end

function Item:moveHorizontal(world, amount)
    local pixels = self:consumePixels("x", amount)
    local direction = sign(pixels)
    for _ = 1, math.abs(pixels) do
        if world:collidesSolid(self, self.x + direction, self.y) then
            self.xRemainder = 0
            return true
        end
        self.x = self.x + direction
    end
    return false
end

function Item:moveVertical(world, amount)
    local pixels = self:consumePixels("y", amount)
    local direction = sign(pixels)
    for _ = 1, math.abs(pixels) do
        local nextY = self.y + direction
        if world:collidesSolid(self, self.x, nextY) then
            self.yRemainder = 0
            return direction > 0 and "floor" or "ceiling"
        end
        if direction > 0 then
            local landing = world:platformLanding(self, self.y, nextY)
            if landing then
                self.y = landing
                self.yRemainder = 0
                return "floor"
            end
        end
        self.y = nextY
    end
end

function Item:update(world, player)
    if self.held then
        self:updateHeldPosition(player)
        return
    end
    if self.safeTimer > 0 then self.safeTimer = self.safeTimer - 1 end
    self.vy = math.min(8, self.vy + 0.6)
    if self:moveHorizontal(world, self.vx) then self.vx = -self.vx * 0.5 end
    local verticalHit = self:moveVertical(world, self.vy)
    if verticalHit == "floor" then
        self.vy = math.abs(self.vy) > 1 and -self.vy * 0.5 or 0
        self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
    elseif verticalHit == "ceiling" then
        self.vy = math.abs(self.vy) * 0.5
    end
end

return Item
