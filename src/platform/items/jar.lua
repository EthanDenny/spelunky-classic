local Traits = require("src.platform.item_traits")

local jarLoot = {
    { odds = 3, kind = "gold_chunk" }, { odds = 6, kind = "gold_nugget" },
    { odds = 12, kind = "emerald_big" }, { odds = 12, kind = "sapphire_big" },
    { odds = 12, kind = "ruby_big" }, { odds = 6, kind = "spider" },
    { odds = 12, kind = "snake" },
}

local Definition = Traits.carry({ flight = "fragile", bounds = { 4, -6, 6 }, hold = { standing = 0, ducking = 4 },
    breakOnImpact = { wall = 3, ceiling = 3, floor = 3, effect = "jar" },
    container = { mode = "chain", rolls = jarLoot,
        effect = "jar" } })

Definition.depth = 100

Definition.breakWhenEmbedded = true
Definition.breakOnBullet = true

-- oJar destroys itself on a fast creature contact even if damage is refused.
-- Its stunned-enemy and damsel rules differ from the oItem parent.
local function hitCreature(item, enemy, context)
    local invincible = enemy.invincible and enemy.invincible ~= 0
    local stunOnly = enemy.kind == "caveman" or enemy.kind == "shopkeeper"
    if enemy.kind == "damsel" then
        if not invincible then context.effects:blood(enemy.x, enemy.y-8, 1) end
        enemy.held = false
        if context.heldNpc == enemy then context.heldNpc = nil end
        enemy.hp = enemy.hp-1
        enemy.vx, enemy.vy = item.vx*0.3, -6
        enemy.state, enemy.stunned = "stunned", 120
        if enemy.hp <= 0 then enemy.alive, enemy.corpse, enemy.state = false, true, "dead" end
    elseif not invincible then
        if stunOnly and (enemy.stunned > 0 or enemy.corpse) then
            -- status 98 keeps its stun counter and vertical motion.
            enemy.vx = item.vx*0.3
        else
            local vy = enemy.vy
            local damaged = enemy:damage(stunOnly and 0 or 1, item.x,
                { kind = "item", fragile = true, vx = item.vx*0.3, vy = stunOnly and -6 or vy })
            if damaged then
                enemy.vx = item.vx*0.3
                if not stunOnly then enemy.vy = vy end
                context.effects:blood(enemy.x, enemy.y-8, 1)
                context.sounds:play("hit")
            end
        end
    end
    item.justHit = true
    context:processItemImpact(item)
end

function Definition.updateLoose(item, world)
    local context = world.game
    if not context then return end
    -- oJar overrides its parent Step, including the parent enemy collision.
    item.skipEnemyHitOnce = true
    if item.opened or (math.abs(item.vx) <= 2 and math.abs(item.vy) <= 2) then return end
    for _, enemy in ipairs(context:combatActors()) do
        if (enemy.alive or enemy.corpse)
            and enemy:overlapsRectangle(item.x-3, item.y-3, item.x+3, item.y+3) then
            hitCreature(item, enemy, context)
            break
        end
    end
end

return Definition
