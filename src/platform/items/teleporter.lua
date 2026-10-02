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
    player:setState("falling")
    for _, enemy in ipairs(context.enemies) do
        if enemy.alive and enemy:overlapsRectangle(x - 4, y - 4, x + 4, y + 4) then
            context.effects:blood(enemy.x, enemy.y, 3)
            enemy:damage(99, x)
        end
    end
    context.sounds:play("teleport")
    return 1
end

return Definition
