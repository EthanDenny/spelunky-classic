local Contact = require("src.platform.body_contact")
local Fragile = {}

-- oJar and oSkull destroy themselves on fast creature contact even if damage is refused.
-- Their stunned-enemy and damsel rules differ from the oItem parent.
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
        if stunOnly and (enemy.stunned > 0 or enemy.corpse and (enemy.vx ~= 0 or enemy.vy ~= 0)) then
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

function Fragile.update(item, world)
    local context = world.game
    if not context then return end
    -- These fragile objects override the parent enemy collision.
    item.skipEnemyHitOnce = true
    if item.opened or not Contact.moving(item, 2) then return end
    local actors = context:combatActors()
    local enemy = Contact.find(item, actors, 3, false, true)
    local damsel = Contact.find(item, actors, 3, true, true)
    if enemy then hitCreature(item, enemy, context) end
    if damsel then hitCreature(item, damsel, context) end
end

return Fragile
