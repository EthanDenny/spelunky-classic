local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "teleport", price = 10000 })

Definition.depth = 101
Definition.shopOffsetY = 12

function Definition.use(context, _, input)
    local player = context.player
    local tiles = context.effects.random:random(4, 8)
    local x, y = player.x, player.y
    if input.up then
        y = y - 16 * tiles
        while y < 16 do y = y + 16 end
    else
        x = math.max(8, math.min(context.world.width * context.world.tileSize - 8,
            x + player.facing * 16 * tiles))
    end
    for _ = 1, 3 do
        if y <= 16 or not context.world:solidRect(x - 4, y - 4, x + 4, y + 4) then break end
        y = y - 16
    end
    for _ = 1, 3 do
        context.effects:add("teleport_spark", player.x - 4 + context.effects.random:random(0, 8),
            player.y - 4 + context.effects.random:random(0, 8))
    end
    player.x, player.y = x, y
    if player.ball then
        player.ball.x, player.ball.y = x, y
    end
    for _, chain in ipairs(context.chains or {}) do chain.x, chain.y = x, y end
    local Collision = require("src.platform.entity_collision")
    for _, enemy in ipairs(context.enemies) do
        if (enemy.alive or enemy.corpse) and enemy.kind ~= "ghost" and enemy.kind ~= "damsel"
            and Collision.touching(player, enemy, player) then
            context.effects:blood(x, y, 3)
            enemy.hp, enemy.alive, enemy.corpse = enemy.hp-99, false, false
            enemy.state = "dead"
            break
        end
    end
    player:setState("falling")
    context.sounds:play("teleport")
    return 1
end

Definition.pickupMessage = "YOU GOT A TELEPORTER!"
Definition.buyMessage = "A TELEPORTER FOR $%s."

return Definition
