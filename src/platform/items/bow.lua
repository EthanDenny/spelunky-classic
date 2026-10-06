local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "bow", price = 1000,
    firstPickup = { resource = "arrows", amount = 6 },
    bow = { chargePerTick = 0.2,
        maxCharge = 12, cooldown = 10, damage = 1 } })

Definition.depth = 101
Definition.shopOffsetY = 12

function Definition.use(context, item)
    if context.player.state == "ducking" or context.player.whipping then return 1 end
    if context.run.arrows <= 0 then
        context.run:addMessage("I'M OUT OF ARROWS!", 80)
        return 1
    end
    if not item.bowArmed then
        item.bowArmed = true
        item.bowStrength = 0
        context.sounds:play("bowpull")
    end
    return 1
end

function Definition.updateBow(context, input)
    local item = context.heldItem
    if not item or not item.definition.bow or not item.bowArmed then return end
    local spec = item.definition.bow
    local player = context.player
    if input and input.attack and not player:isStunned() and not player:isDead() then
        item.bowStrength = math.min(spec.maxCharge,
            item.bowStrength + spec.chargePerTick)
        return
    end
    local direction = player.facing
    local x = player.x + direction * 14
    if context.world:solidAtPoint(x, player.y) then x = player.x end
    local velocity = player.vx + direction * (1 + item.bowStrength)
    if direction < 0 then velocity = math.min(-1, velocity)
    else velocity = math.max(1, velocity) end
    context.projectiles:spawn("arrow", x,
        player.y + (player.state == "ducking" and 4 or 0),
        velocity, 0, player, { damage = spec.damage, gravity = 0.2,
            radius = 4 })
    context.run.arrows = context.run.arrows - 1
    item.cooldown = spec.cooldown
    item.bowArmed = false
    item.bowStrength = 0
    context.sounds:play("arrowtrap")
    context.sounds:stop("bowpull")
end

function Definition.recoverArrows(context)
    if not context.heldItem or context.heldItem.kind ~= "bow"
        or context.player:isDead() or context.player:isStunned() then return false end
    for _, item in ipairs(context.items) do
        if item.kind == "arrow" and not item.held and not item.opened and not item.stuck
            and math.abs(item.vx) < 1 and math.abs(item.vy) < 1
            and math.abs(item.x - context.player.x) <= 8
            and math.abs(item.y - context.player.y) <= 8 then
            item.opened = true
            item.x, item.y = -1000, -1000
            context.run.arrows = context.run.arrows + 1
            context.sounds:play("pickup")
            return true
        end
    end
    return false
end

function Definition.loadRenderAssets(self)
    self.itemAnimationSprites.bowLeft, self.itemAnimationSprites.bowRight = {}, {}
    local spriteRoot = "original-game-reference/source/extracted/spelunky/Sprites/"
    self.itemAnimationSprites.bowLeft[1] = self.entitySprites.bow_left.image
    self.itemAnimationSprites.bowRight[1] = self.entitySprites.bow.image
    for frame = 1, 3 do
        for _, facing in ipairs({ "Left", "Right" }) do
            local image = love.graphics.newImage(string.format(
                "%sItems/Saleable/sBow%s.images/image %d.png", spriteRoot, facing, frame))
            image:setFilter("nearest", "nearest")
            self.itemAnimationSprites["bow" .. facing][frame + 1] = image
        end
    end
end

function Definition.itemImage(renderer, item, facing)
    local strength = item.held and item.bowStrength or 0
    local frame = strength >= 10 and 4 or strength > 6 and 3 or strength > 2 and 2 or 1
    return renderer.itemAnimationSprites[(facing or item.facing or 1) < 0 and "bowLeft" or "bowRight"][frame]
end

Definition.leftSprite = { group = "Items/Saleable", name = "sBowLeft" }

Definition.pickupMessage = "YOU GOT THE BOW AND ARROWS!"
Definition.buyMessage = "BOW AND ARROWS FOR $%s."

return Definition
