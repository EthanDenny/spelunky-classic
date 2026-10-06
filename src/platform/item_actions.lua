local ItemActions = {}
local MeleeMask = require("src.platform.melee_mask")

local function useGun(context, item)
    if context.player.state == "ducking" then return 1 end
    local cooldown = context.projectiles:fireGun(item.definition.gun,
        context.player, context.player, context.effects.random)
    context.sounds:play("shotgun")
    return cooldown
end

local Bow = require("src.platform.items.bow")
ItemActions.updateBow = Bow.updateBow
ItemActions.recoverArrows = Bow.recoverArrows

local function useMelee(context, item)
    local player = context.player
    if player.whipping then return 1 end
    if not item.definition.melee.canSwingInAir and not player:isGroundState() then return 1 end
    if player:startMelee(item.kind, item.definition.melee.playerSpeed) then
        player.meleeFacing = player.facing
        if item.definition.melee.blockJumpTicks then
            player.cantJumpTimer = item.definition.melee.blockJumpTicks
        end
        item.visible = false
        context.meleeItem = item
        context.meleePreAge = nil
        context.meleeStrikeAge = nil
        player.meleeStrikeAge = nil
        player.meleeVisualPhase = "back"
        return math.ceil(11 / item.definition.melee.playerSpeed)
    end
    return 1
end

local function meleeOverlaps(name, frame, x, y, target)
    return MeleeMask.touching(name, frame, x, y, target)
end

function ItemActions.updateMelee(context)
    local item = context.meleeItem
    if not item then return end
    local player = context.player
    if not item.held or player:isStunned() or player:isDead() then
        item.visible = true
        context.meleeItem = nil
        context.meleePreAge, context.meleeStrikeAge = nil, nil
        player.meleeVisualPhase = nil
        player.meleeStrikeAge = nil
        return
    end
    local spec = item.definition.melee
    local frame = player.animationFrame
    local strikeDuration = math.ceil(3 / spec.strikeSpeed)
    if context.meleePreAge then
        context.meleePreAge = context.meleePreAge + 1
        if context.meleePreAge >= 3 then context.meleePreAge = nil end
    end
    -- Classic checks oMachetePre even when spawning oMattockPre, so the
    -- mattock renews its rear hitbox on every wind-up tick.
    if (not context.meleePreAge or spec.renewWindup) and player.whipping
        and player.attackKind == item.kind and frame < 2 then
        context.meleePreAge = 0
    end
    if context.meleeStrikeAge then
        context.meleeStrikeAge = context.meleeStrikeAge + 1
    elseif player.whipping and player.attackKind == item.kind and frame > 4 then
        context.meleeStrikeAge = 0
        context.sounds:play("whip")
    end
    local striking = context.meleeStrikeAge and context.meleeStrikeAge < strikeDuration
    player.meleeStrikeAge = context.meleeStrikeAge
    local phase = context.meleePreAge and "back" or striking and "front" or nil
    player.meleeVisualPhase = phase
    local name, spriteFrame, x, y = MeleeMask.pose(player, spec, phase,
        context.meleeStrikeAge)
    if name then
        local sourceX = player.x+(player.meleeFacing or player.facing)*(phase == "back" and -16 or 16)
        for _, enemy in ipairs(context.combatActors and context:combatActors() or context.enemies or {}) do
            if (enemy.alive or enemy.corpse) and enemy.kind ~= "ghost"
                and meleeOverlaps(name, spriteFrame, x, y, enemy) then
                if enemy.kind == "shopkeeper" then
                    enemy:damage(spec.keeperWhipDamage or 0, sourceX, { kind = "whip" })
                elseif enemy.spec and enemy.spec.melee then
                    enemy.spec.melee(enemy, context, spec.strike == "slash" and spec.damage or 0)
                else
                    if enemy:damage(spec.damage, sourceX, { kind = "whip", weapon = item.kind, phase = phase })
                        and not (enemy.spec and enemy.spec.bloodless) then
                        context.effects:blood(enemy.x, enemy.y-8, 1)
                    end
                end
            end
        end
        if phase == "front" then
            if spec.cutsWebs then
                -- Classic oWeb has a collision event for oSlash, not oWhip.
                for _, web in ipairs(context.level.entities) do
                    if web.kind == "web" and not web.destroyed then
                        local left, top = web.x * 16, web.y * 16
                        if MeleeMask.overlaps(name, spriteFrame, x, y,
                            left, top, left + 16, top + 16) then
                            context.world:damageWebAtPoint(left + 8, top + 8, 12)
                        end
                    end
                end
                for index = #context.world.dynamicWebs, 1, -1 do
                    local web = context.world.dynamicWebs[index]
                    if MeleeMask.overlaps(name, spriteFrame, x, y,
                        web.x, web.y, web.x + 16, web.y + 16) then
                        context.world:damageWebAtPoint(web.x + 8, web.y + 8, 12)
                    end
                end
            end
            for _, target in ipairs(context.items) do
                if target ~= item and not target.held and not target.opened
                    and target.definition.container and target.definition.container.effect == "jar"
                    and meleeOverlaps(name, spriteFrame, x, y, target) then
                    context:openContainer(target)
                end
            end
        end
    end
    if spec.digs and context.meleeStrikeAge
        and context.meleeStrikeAge >= strikeDuration then
        local x = player.x + (player.meleeFacing or player.facing) * 16
        local y = player.y
        local name = (player.meleeFacing or player.facing) < 0 and "sMattockHitL" or "sMattockHitR"
        local destroyed = context.world:destroySolidAtSprite(name, 2, x, y)
        if #destroyed > 0 then context.world:cleanExplosionTerrain(destroyed) end
        if not context.world.game then
            for _, cell in ipairs(destroyed) do
                context.effects:terrainBreak(cell.pixelX or (cell.x + 0.5) * context.world.tileSize,
                    cell.pixelY or (cell.y + 0.5) * context.world.tileSize, context.world.tileSize, cell.entity)
            end
        end
        if #destroyed > 0 and context.effects.random:random(1, spec.breakChance) == 1 then
            item.held = false
            item.visible = true
            item.opened = true
            item.x, item.y = -1000, -1000
            context.heldItem = nil
            local head = context:spawnEntity("mattock_head", x, y)
            if head then head.vy = -2 end
            context.sounds:play("mattock_break")
        elseif #destroyed > 0 then
            context.sounds:play("crunch")
        end
    end
    if context.meleeStrikeAge and context.meleeStrikeAge >= strikeDuration then
        context.meleeStrikeAge = nil
        player.meleeStrikeAge = nil
        player.meleeVisualPhase = nil
    end
    if not item.held or (not player.whipping and not context.meleeStrikeAge) then
        item.visible = true
        context.meleeItem = nil
        context.meleeStrikeAge = nil
        player.meleeStrikeAge = nil
        player.meleeVisualPhase = nil
    end
end

local handlers = {
    gun = useGun,
    melee = useMelee,
}

function ItemActions.use(context, item, input)
    if context.player:isDead() or context.player:isStunned() then return false end
    if item.definition.useHeld then return item.definition.useHeld(context, item, input) end
    if item.definition.action == "open" and not item.opened and input.up then
        if context.heldItem == item then
            context.heldItem = nil
            item.held = false
        end
        context:openContainer(item)
        context.sounds:play("pickup")
        return true
    end
    if item.weapon and not input.down then
        if item.cooldown > 0 then return true end
        local handler = item.definition.use or handlers[item.definition.action]
        local cooldown = handler(context, item, input)
        if cooldown then
            item.cooldown = cooldown
            return true
        end
    end
    if item.weapon then item:dropWeapon(context.player)
    else item:throw(context.player, input, context.world) end
    context.heldItem = nil
    if context.throwSound then context.throwSound:clone():play() end
    return true
end

return ItemActions
