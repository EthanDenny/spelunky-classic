local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ heavy = true, bounds = { 6, 0, 8 }, action = "open",
    container = { mode = "chest", message = "TREASURE!" } })

Definition.depth = 900

local function rollChest(random)
    if random:random(1, 12) == 1 then
        return { { kind = "bomb", vx = random:random(0, 3) - random:random(0, 3),
            vy = -2, trapped = true } }
    end
    local small = { "emerald", "sapphire", "ruby" }
    local big = { "emerald_big", "sapphire_big", "ruby_big" }
    local rewards = {}
    for _ = 1, random:random(3, 4) do
        rewards[#rewards + 1] = {
            kind = small[random:random(1, 3)],
            vx = random:random(0, 3) - random:random(0, 3), vy = -2,
        }
    end
    if random:random(1, 4) == 1 then
        rewards[#rewards + 1] = {
            kind = big[random:random(1, 3)],
            vx = random:random(0, 3) - random:random(0, 3), vy = -2,
        }
    end
    return rewards
end

Definition.container.roll = rollChest

function Definition.loadRenderAssets(self)
    local spriteRoot = "original-game-reference/source/extracted/spelunky/Sprites/"
    self.itemAnimationSprites.chestOpen = love.graphics.newImage(
        spriteRoot .. "Items/Other/sChestOpen.images/image 0.png")
    self.itemAnimationSprites.chestOpen:setFilter("nearest", "nearest")
end

function Definition.itemImage(renderer, item)
    if item.opened then return renderer.itemAnimationSprites.chestOpen end
end

return Definition
