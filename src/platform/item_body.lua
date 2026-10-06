-- Loose oItem physics and impacts shared by carryables, tools, and NPC bodies.
local Physics = require("src.platform.physical_body")
local Contact = require("src.platform.body_contact")
local ItemBody = {}

function ItemBody.resolveEnemyContacts(body, enemies, context)
    local definition = body.definition
    local speed = definition.hitSpeed or 2
    if body.held or body.opened and body.kind ~= "chest" or body.skipEnemyHitOnce
        or not (body.alive or body.corpse)
        or not Contact.moving(body, speed) then return end
    local reach = definition.flight == "fragile" and 3 or 2
    if not enemies and context then
        enemies = context.combatActors and context:combatActors() or context.enemies
    end
    local function hit(enemy)
        if not enemy or body.hitEnemies and body.hitEnemies[enemy] then return end
        if enemy.kind == "damsel" and (enemy.corpse or enemy.cooldown > 0
            or enemy.held and body.safe) then return end
        -- Contact overrides may consume a hit without dealing damage.
        if definition.enemyContact and definition.enemyContact(body, enemy, context) then return end
        if not Physics.strikeEnemy(body, enemy) then return end
        if enemy.kind == "damsel" then
            enemy.held, enemy.cooldown = false, 10
            if context and context.heldNpc == enemy then context.heldNpc = nil end
            if context and enemy.forSale then
                require("src.platform.shop").anger(context, enemy.x, enemy.y, "YOU'LL PAY FOR YOUR CRIMES!")
            end
        end
        if definition.impactOnce then
            body.hitEnemies = body.hitEnemies or {}
            body.hitEnemies[enemy] = true
        end
        if definition.onEnemyHit then definition.onEnemyHit(body, enemy, context)
        elseif context and context.effects then context.effects:blood(enemy.x, enemy.y-8, 1) end
        if definition.breakOnImpact then
            body.justHit = true
            if context and context.processItemImpact then context:processItemImpact(body) end
            return true
        elseif definition.consumeOnEnemyHit then
            body.opened = true
            body.x, body.y = -1000, -1000
            return true
        end
    end
    if definition.enemyBody then
        hit(Contact.find(body, enemies, reach, false, false,
            { body.x-8, body.y-16, body.x+9, body.y+1 }))
    else
        hit(Contact.find(body, enemies, reach, false, true))
        hit(Contact.find(body, enemies, reach, true, false))
    end
end

function ItemBody.step(world, body, player, context, enemies)
    context = context or world.game
    local definition = body.definition
    Physics.stepItem(world, body)
    if definition.updateLoose then definition.updateLoose(body, world, player) end
    if context and context.processItemImpact then context:processItemImpact(body) end
    local web
    if not definition.webAfterImpact then web = Physics.stopInWeb(world, body) end
    ItemBody.resolveEnemyContacts(body, enemies, context)
    if definition.webAfterImpact then web = Physics.stopInWeb(world, body) end
    body.skipEnemyHitOnce = false
    return web
end

return ItemBody
