local Brick = {
    solid = true,
    worldLayer = "solid",
    depth = 100,
    images = {
        brick = "brick", brick_alt = "brick_alt", brick_gold = "brick_gold",
        brick_gold_big = "brick_gold_big", brick_down = "brick_down",
        cave_up = "cave_up", cave_up2 = "cave_up2",
    },
}

function Brick.image(tile)
    return Brick.images[tile.style] or "brick"
end

return Brick
