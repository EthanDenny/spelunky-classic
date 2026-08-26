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
            { kind = "gold_bar", x = 2.5, y = 2.5 },
        },
        tiles = {
            { { kind = "brick" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "ladder_top" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "ladder" }, { kind = "liquid" }, { kind = "empty" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "empty" }, { kind = "falling" }, { kind = "push_block" }, { kind = "empty" } },
            { { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" }, { kind = "empty" } },
        },
    }

    local world = GeneratedWorld.fromLevel(level)
    assert(world:has("solid", 0, 0), "Generated bricks must become solid physics cells")
    assert(world:has("solid", 2, 3), "Generated falling blocks must initially be solid")
    assert(world:has("solid", 3, 3) and world:has("moveableSolid", 3, 3),
        "Push blocks must retain their distinct movable-solid collision class")
    assert(world:has("solid", 3, 2), "Block-replacing traps must preserve terrain collision")
    assert(world:has("ladder", 1, 2) and world:has("ladderTop", 1, 1),
        "Generated ladders must retain their body and one-way top distinction")
    assert(not world:has("solid", 2, 2), "Liquids must not become solid terrain")

    local x, y = GeneratedWorld.spawnPoint(level)
    assert(x == 24 and y == 24, "Player spawn must use the entrance tile center")
end

return Test
