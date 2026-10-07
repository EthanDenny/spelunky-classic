local Item = {}
Item.__index = Item
local Definitions = require("src.platform.item_definitions")
local Holdable = require("src.platform.holdable")
local ItemContents = require("src.platform.item_contents")

function Item.isCarryable(kind)
    return Definitions[kind] and Definitions[kind].carryable or false
end

function Item.isCollectible(kind)
    return Definitions[kind] and Definitions[kind].pickup ~= nil or false
end

function Item.isEquipment(kind)
    local pickup = Definitions[kind] and Definitions[kind].pickup
    return pickup and pickup.equipment or false
end

function Item.pickupSound(kind)
    local pickup = Definitions[kind] and Definitions[kind].pickup
    return pickup and pickup.sound or "pickup"
end

function Item.price(kind, absoluteLevel)
    local base = Definitions[kind] and Definitions[kind].price or 0
    -- scrShopItemsGen adds ten percent per level after level two.
    return base + base * 0.1 * math.max(0, (absoluteLevel or 1) - 2)
end

function Item.announce(kind, run, game)
    local message = Definitions[kind] and Definitions[kind].pickupMessage
    if type(message) == "function" then message = message(game) end
    if message then run:addMessage(message, 120) end
end

function Item.collect(kind, run, player, game)
    local pickup = Definitions[kind] and Definitions[kind].pickup
    if not pickup then return nil end
    if pickup.money then
        run:queueMoney(pickup.money)
        if game and game.recordLoot then game:recordLoot(kind, pickup.money) end
        return
    end
    if pickup.equipment then
        local replaced = Definitions[kind].replaces
        if replaced and (run.equipment[replaced] or player.equipment[replaced]) then
            run.equipment[replaced], player.equipment[replaced] = false, false
            if replaced == "cape" then player.capeOpen = false end
            if game then
                local dropped = game:spawnEntity(replaced, player.x, player.y, { forSale = false })
                dropped.vy = -1
            end
        end
        run.equipment[kind] = true
        player.equipment[kind] = true
        if kind == "cape" then player.capeFrame = 0 end
        Item.announce(kind, run, game)
        return
    end
    if pickup.resource then
        run[pickup.resource] = run[pickup.resource] + pickup.amount
        Item.announce(kind, run, game)
    end
end

function Item.new(entity, metadata, random)
    assert(Item.isCarryable(entity.kind), "Non-carryable entity: " .. tostring(entity.kind))
    metadata = metadata or {}
    local definition = Definitions[entity.kind]
    local self = setmetatable({
        entity = entity,
        kind = entity.kind,
        definition = definition,
        random = random,
        properties = entity.properties or {},
        x = entity.x * 16,
        y = entity.y * 16,
        vx = 0,
        vy = 0,
        gravity = definition.gravity or 0.6,
        xRemainder = 0,
        yRemainder = 0,
        width = metadata.width or 16,
        height = metadata.height or 16,
        heavy = definition.heavy or false,
        weapon = definition.action ~= nil and definition.action ~= "open",
        alive = true,
        held = false,
        safeTimer = 0,
        dropThroughTimer = 0,
        cooldown = 0,
        opened = false,
        visible = true,
        new = true,
        facing = 1,
        stuck = false,
    }, Item)
    if definition.initialize then definition.initialize(self) end
    return self
end

function Item:getCollisionHalfWidth()
    local bounds = self.definition.bounds
    return bounds and bounds[1] or 4
end

function Item:getVerticalBounds()
    local bounds = self.definition.bounds
    if bounds then return bounds[2], bounds[3] end
    return -4, 4
end

function Item:overlapsRectangle(left, top, right, bottom)
    local halfWidth = self:getCollisionHalfWidth()
    local topOffset, bottomOffset = self:getVerticalBounds()
    return left <= self.x + halfWidth and right >= self.x - halfWidth
        and top <= self.y + bottomOffset and bottom >= self.y + topOffset
end

function Item:pickup(player, run)
    if not Holdable.pickup(self, player) then return false end
    local effect = self.definition.firstPickup
    if effect and self.new and run then
        run[effect.resource] = run[effect.resource] + effect.amount
        self.new = false
    end
    return true
end

function Item:updateHeldPosition(player)
    Holdable.position(self, player)
    self.entity.x, self.entity.y = self.x / 16, self.y / 16
end

function Item:throw(player, input, world)
    Holdable.throw(self, player, input, world)
end

function Item:dropWeapon(player)
    Holdable.dropWeapon(self, player)
end

function Item:dropFromHurt(player)
    Holdable.dropFromHurt(self, player)
end

function Item:open(run, random)
    return ItemContents.open(self, run, random)
end

function Item:update(world, player, context)
    if not self.alive then return end
    if self.definition.update then self.definition.update(self, world, player) end
    if not self.alive or not require("src.platform.activity").contains(world, self) then return end
    self.justHit = false
    self.impactSide = nil
    if self.cooldown > 0 then self.cooldown = self.cooldown - 1 end
    if self.held then
        self:updateHeldPosition(player)
        return
    end
    if self.safeTimer > 0 then self.safeTimer = self.safeTimer - 1 end
    self.definition.bodyStep(world, self, player, context)
    self.entity.x, self.entity.y = self.x / 16, self.y / 16
end

return Item
