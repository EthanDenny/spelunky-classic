local MinesGenerator = require("src.world.mines_generator")

local MinesGeneratorTest = {}

local function signature(level)
    local parts = {
        level.startRoomX,
        level.endRoomX,
        level.endRoomY,
    }

    for y = 1, 4 do
        for x = 1, 4 do
            parts[#parts + 1] = level.roomPath[y][x]
            parts[#parts + 1] = level.roomTemplates[y][x]
        end
    end

    for y = 1, level.height do
        for x = 1, level.width do
            local tile = level.tiles[y][x]
            parts[#parts + 1] = tile.kind
            parts[#parts + 1] = tile.style or ""
        end
    end

    for _, entity in ipairs(level.entities) do
        parts[#parts + 1] = entity.kind
        parts[#parts + 1] = entity.x
        parts[#parts + 1] = entity.y
    end

    return table.concat(parts, ":")
end

local function assertSolidBorder(level)
    for x = 1, level.width do
        assert(level.tiles[1][x].kind == "brick", "Open top border")
        assert(level.tiles[level.height][x].kind == "brick", "Open bottom border")
    end

    for y = 1, level.height do
        assert(level.tiles[y][1].kind == "brick", "Open left border")
        assert(level.tiles[y][level.width].kind == "brick", "Open right border")
    end
end

local function validateLevel(level)
    assert(level.width == 42 and level.height == 34, "Incorrect original room dimensions")
    assert(level.entrance, "Generated mines level has no entrance")
    assert(level.exit, "Generated mines level has no exit")
    assertSolidBorder(level)

    local roomCount = 0
    for y = 1, 4 do
        for x = 1, 4 do
            assert(#level.roomTemplates[y][x] == 80, "Expanded room is not 10 x 8")
            roomCount = roomCount + 1
        end
    end
    assert(roomCount == 16, "Mines level must contain 16 rooms")
end

function MinesGeneratorTest.run()
    for levelNumber = 1, 4 do
        for seed = 1, 16 do
            validateLevel(MinesGenerator.generate(seed, { levelNumber = levelNumber }))
        end
    end

    local first = MinesGenerator.generate(8675309, { levelNumber = 4 })
    local repeated = MinesGenerator.generate(8675309, { levelNumber = 4 })
    assert(signature(first) == signature(repeated), "Mines generation is not deterministic")
end

return MinesGeneratorTest
