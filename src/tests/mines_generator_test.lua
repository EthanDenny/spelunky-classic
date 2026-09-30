local MinesGenerator = require("src.world.mines_generator")
local MinesVariants = require("src.world.mines_variants")
local RunState = require("src.game.run_state")

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

    local darkSeed
    for seed = 1, 100 do
        local level = MinesGenerator.generate(seed, { levelNumber = 2 })
        local run = RunState.new(seed)
        MinesVariants.apply(level, run)
        if level.dark then
            darkSeed = seed
            assert(run.hadDarkLevel, "A dark Mines level must mark the run")
            local lamp, scarab = false, false
            for _, entity in ipairs(level.entities) do
                lamp = lamp or entity.kind == "lamp"
                scarab = scarab or entity.kind == "scarab"
            end
            assert(lamp and scarab, "Dark Mines must retain the lamp and scarab")
            break
        end
    end
    assert(darkSeed, "The seed sample must include a dark Mines level")
    local run = RunState.new(darkSeed)
    run.hadDarkLevel = true
    local level = MinesGenerator.generate(darkSeed, { levelNumber = 2 })
    MinesVariants.apply(level, run)
    assert(not level.dark, "A run must not repeat a dark Mines level")
end

return MinesGeneratorTest
