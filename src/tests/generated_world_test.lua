local GeneratedWorld = require("src.platform.generated_world")

local Test = {}

function Test.run()
    local level = {
        width = 5,
        height = 5,
        tileSize = 16,
        entrance = { x = 1, y = 1 },
        entities = {
            { kind = "arrow_trap_left", x = 3, y = 2 },
            { kind = "sacrifice_altar", x = 1, y = 4 },
            { kind = "gold_bar", x = 2.5, y = 2.5 },
            { kind = "shop_sign", x = 4, y = 1, properties = { shopType = "General" } },
        },
        tiles = {
            { { kind = "brick" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "ladder_top" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "ladder" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "push_block" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
        },
    }

    local world = GeneratedWorld.fromLevel(level)
    assert(world:has("solid", 0, 0), "Generated bricks must become solid physics cells")
    assert(world:solidAtPoint(3 * 16 + 8, 3 * 16 + 8)
        and world:dynamicSolidAt(3 * 16, 3 * 16, 4 * 16, 4 * 16, true),
        "Push blocks must retain their distinct movable-solid collision class")
    assert(world:has("solid", 3, 2), "Block-replacing traps must preserve terrain collision")
    assert(world:has("solid", 4, 1) and world:solidAtPoint(4 * 16 + 8, 16 + 8),
        "A shop sign must be a solid cell, as its Classic oSolid parent requires")
    assert(world:has("solid", 1, 4) and world:has("solid", 2, 4),
        "Both halves of the sacrifice altar must block movement")
    assert(world:has("ladder", 1, 2) and world:has("ladderTop", 1, 1),
        "Generated ladders must retain their body and one-way top distinction")
    for _, x in ipairs({ 16, 17, 30, 31 }) do
        assert((world:climbableAtPoint(x, 40) ~= nil) == (x > 16 and x < 31),
            "A ladder's AUTO rectangle excludes its transparent outer columns")
    end

    local x, y = GeneratedWorld.spawnPoint(level)
    assert(x == 24 and y == 24, "Player spawn must use the entrance tile center")
end

return Test
