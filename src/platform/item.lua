local Item = {}
Item.__index = Item

local CARRYABLE = {
    arrow = true,
    rock = true,
    jar = true,
    skull = true,
    chest = true,
    locked_chest = true,
    crate = true,
    gold_idol = true,
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
    die = true,
}

local CARRIED_AT_BODY = {
    gold_idol = true,
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

-- Source Create-event setCollisionBounds, relative to each item's origin.
-- Carryables not listed here use (-4, -4, 4, 4).
local COLLISION_BOUNDS = {
    jar = { 4, -6, 6 },
    mattock = { 4, -6, 6 },
    chest = { 6, 0, 8 },
    locked_chest = { 6, -2, 8 },
    crate = { 6, 0, 8 },
    die = { 6, 0, 8 },
}

local COLLECTIBLE_VALUE = {
    gold_bar = 500,
    gold_bars = 1500,
    emerald_big = 1600,
    sapphire_big = 1800,
    ruby_big = 2000,
    gold_idol = 5000,
    scarab = 5000,
}

local EQUIPMENT = {
    spectacles = true,
    compass = true,
    parachute = true,
    paste = true,
    gloves = true,
    mitt = true,
    cape = true,
    jetpack = true,
    spike_shoes = true,
    spring_shoes = true,
    kapala = true,
    udjat_eye = true,
}

local SUPPLY = {
    bomb_bag = { bombs = 3 },
    bomb_box = { bombs = 12 },
    rope_pile = { ropes = 3 },
}

local PRICES = {
    bomb_bag = 2500, bomb_box = 10000, rope_pile = 2500,
    pistol = 5000, machete = 5000, bow = 5000, web_cannon = 10000,
    shotgun = 10000, mattock = 8000, teleporter = 15000,
    spring_shoes = 4000, spike_shoes = 4000, spectacles = 2500,
    compass = 2500, gloves = 8000, mitt = 8000, cape = 12000,
    jetpack = 20000, paste = 3000, parachute = 2500,
}

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

function Item.isCarryable(kind)
    return CARRYABLE[kind] or false
end

function Item.isCollectible(kind)
    return COLLECTIBLE_VALUE[kind] ~= nil or EQUIPMENT[kind] or SUPPLY[kind]
end

function Item.isEquipment(kind)
    return EQUIPMENT[kind] or false
end

function Item.price(kind, absoluteLevel)
    local base = PRICES[kind] or 2500
    return math.floor(base * (1 + math.max(0, (absoluteLevel or 1) - 1) * 0.05) / 100) * 100
end

function Item.collect(kind, run, player)
    if COLLECTIBLE_VALUE[kind] then
        run.money = run.money + COLLECTIBLE_VALUE[kind]
        return "COLLECTED $" .. COLLECTIBLE_VALUE[kind]
    end
    if EQUIPMENT[kind] then
        run.equipment[kind] = true
        player.equipment[kind] = true
        return string.upper((kind:gsub("_", " "))) .. " ACQUIRED"
    end
    local supply = SUPPLY[kind]
    if supply then
        run.bombs = run.bombs + (supply.bombs or 0)
        run.ropes = run.ropes + (supply.ropes or 0)
        return supply.bombs and "+" .. supply.bombs .. " BOMBS" or "+" .. supply.ropes .. " ROPES"
    end
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
        cooldown = 0,
        durability = entity.kind == "mattock" and 50 or nil,
        opened = false,
        facing = 1,
        stuck = false,
    }, Item)
end

function Item:getCollisionHalfWidth()
    local bounds = COLLISION_BOUNDS[self.kind]
    return bounds and bounds[1] or 4
end

function Item:getVerticalBounds()
    local bounds = COLLISION_BOUNDS[self.kind]
    if bounds then return bounds[2], bounds[3] end
    return -4, 4
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
    self.stuck = false
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
    self.stuck = false
    self.facing = player.facing
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
    if player.equipment and player.equipment.mitt then
        self.vx = self.vx * 1.5
        self.vy = self.vy * 1.25
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

function Item:open(run)
    if self.opened then return nil end
    if self.kind == "locked_chest" and not run.hasKey then return nil, "IT'S LOCKED" end
    if self.kind == "locked_chest" then
        run.hasKey = false
        run.equipment.udjat_eye = true
        self.opened = true
        return "udjat_eye", "THE UDJAT EYE"
    elseif self.kind == "crate" then
        self.opened = true
        local choices = { "bomb_bag", "rope_pile", "shotgun", "mattock", "cape" }
        return choices[((math.floor(self.x + self.y) % #choices) + 1)], "CRATE OPENED"
    elseif self.kind == "chest" then
        self.opened = true
        return "gold_bars", "TREASURE!"
    elseif self.kind == "jar" then
        self.opened = true
        return (math.floor(self.x + self.y) % 5 == 0) and "snake" or "emerald_big", "JAR SMASHED"
    end
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
    self.justHit = false
    self.impactSide = nil
    if self.cooldown > 0 then self.cooldown = self.cooldown - 1 end
    if self.held then
        self:updateHeldPosition(player)
        return
    end
    if self.stuck then return end
    if self.safeTimer > 0 then self.safeTimer = self.safeTimer - 1 end
    local grounded = self.vy >= 0 and self.vy < 1
        and world:collidesSolid(self, self.x, self.y + 1)
    self.vy = grounded and 0 or math.min(8, self.vy + 0.6)
    local horizontalHit = self:moveHorizontal(world, self.vx)
    if horizontalHit then
        local impactVx = self.vx
        self.vx = -self.vx * 0.5
        if self.kind == "arrow" and math.abs(self.vx) > 6 then
            self.stuck = true
            self.x = self.x + sign(impactVx) * 2
            self.vx, self.vy = 0, 0
            return
        end
        if (self.kind == "jar" and math.abs(impactVx) > 3)
            or (self.kind == "skull" and math.abs(impactVx) > 2) then
            self.justHit = true
            self.impactSide = impactVx > 0 and "right" or "left"
        end
    end
    local impactSpeed = math.abs(self.vy)
    local verticalHit = self:moveVertical(world, self.vy)
    local onFloor = verticalHit == "floor"
        or (self.vy >= 0 and (world:collidesSolid(self, self.x, self.y + 1)
            or world:platformLanding(self, self.y, self.y + 1)))
    if verticalHit == "floor" then
        self.justHit = self.justHit or ((self.kind == "jar" or self.kind == "skull")
            and impactSpeed > 3)
            or (self.kind ~= "jar" and impactSpeed >= 4)
        if self.justHit and not self.impactSide then self.impactSide = "floor" end
        self.vy = math.abs(self.vy) > 1 and -self.vy * 0.5 or 0
    end
    if onFloor then
        -- oItem applies friction whenever colBot is true, including ticks on
        -- which the item is already resting and no vertical collision occurs.
        self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
    end
    if verticalHit == "ceiling" then
        if (self.kind == "jar" and self.vy < -3)
            or (self.kind == "skull" and self.vy < 0) then
            self.justHit = true
            if not self.impactSide then self.impactSide = "ceiling" end
        end
        self.vy = math.abs(self.vy) * 0.5
    end
end

return Item
