local World = require("src.platform.world")

local function create()
    local world = World.new(40, 24, 16)
    world:fill("solid", 0, 22, 40, 2)
    world:fill("solid", 0, 0, world.width, 1)
    world:fill("solid", 0, 1, 1, world.height - 1)
    world:fill("solid", world.width - 1, 1, 1, world.height - 1)

    world:fill("solid", 2, 18, 7, 1)
    world:fill("solid", 9, 19, 2, 3)

    world:fill("solid", 12, 17, 7, 1)
    world:fill("solid", 12, 12, 7, 1)
    world:remove("solid", 15, 17)
    world:remove("solid", 15, 12)
    world:fill("ladder", 15, 13, 1, 9)
    world:set("ladderTop", 15, 12)
    world:set("ladderTop", 15, 17)

    world:fill("solid", 20, 19, 5, 1)
    world:fill("rope", 23, 9, 1, 10)

    world:fill("solid", 27, 16, 4, 1)
    world:fill("solid", 31, 13, 6, 1)
    world:fill("solid", 36, 14, 1, 8)

    return world
end

return create
