local Brick = {
    inheritsSolidDestroy = true, solid = true,
    worldLayer = "solid",
    depth = 100,
    images = {
        brick = "brick", brick_alt = "brick_alt", brick_gold = "brick_gold",
        brick_gold_big = "brick_gold_big", brick_down = "brick_down",
        cave_up = "cave_up", cave_up2 = "cave_up2",
    },
}

function Brick.onDestroyed(game, event, x, y)
    local style = event.tile and event.tile.style
    if style ~= "brick_gold" and style ~= "brick_gold_big" then return end
    local random = game.effects.random
    for index = 1, style == "brick_gold_big" and 4 or 3 do
        local gold = game:spawnEntity(index == 4 and "gold_nugget" or "gold_chunk",
            x+random:random(0,4)-random:random(0,4), y+random:random(0,4)-random:random(0,4))
        gold.vx = random:random(0,3)-random:random(0,3)
        gold.vy = random:random(2,4)
    end
end

function Brick.image(tile)
    return Brick.images[tile.style] or "brick"
end

return Brick
