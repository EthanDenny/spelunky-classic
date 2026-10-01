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

local function findEntity(level, kind, x, y)
    for _, entity in ipairs(level.entities) do
        if entity.kind == kind and entity.x == x and entity.y == y then
            return entity
        end
    end
end

local function hasBackdrop(level, kind, x, y)
    for _, backdrop in ipairs(level.backdrops or {}) do
        if backdrop.kind == kind and backdrop.x == x and backdrop.y == y then
            return true
        end
    end
    return false
end

local function assertTrapClearance(level)
    local solidEntities = {
        altar_left = true, altar_right = true, sacrifice_altar = true,
        arrow_trap_left = true, arrow_trap_right = true,
    }
    for _, trap in ipairs(level.entities) do
        if trap.kind == "arrow_trap_left" or trap.kind == "arrow_trap_right" then
            local offsets = trap.kind == "arrow_trap_left" and { -1, -2 } or { 1, 2, 3 }
            for _, offset in ipairs(offsets) do
                local x = trap.x + offset
                local tile = level.tiles[trap.y + 1][x + 1]
                assert(tile.kind ~= "brick" and tile.kind ~= "block"
                    and tile.kind ~= "smooth_brick" and tile.kind ~= "push_block",
                    "Arrow trap faces solid terrain")
                for _, entity in ipairs(level.entities) do
                    assert(not (solidEntities[entity.kind] and entity ~= trap
                        and entity.y == trap.y and (entity.x == x
                        or (entity.kind == "sacrifice_altar" and entity.x + 1 == x))),
                        "Arrow trap faces a solid altar or trap")
                end
            end
            for _, entity in ipairs(level.entities) do
                if entity ~= trap and entity.kind ~= "hidden_sapphire"
                    and entity.kind ~= "hidden_emerald" and entity.kind ~= "hidden_ruby"
                    and entity.kind ~= "hidden_item" then
                    assert(not (entity.x >= trap.x and entity.x < trap.x + 1
                        and entity.y >= trap.y and entity.y < trap.y + 1),
                        "Visible entity generated inside an arrow trap")
                end
            end
        end
    end
end

local function assertSpecialRooms()
    local samples = {
        MinesGenerator.generate(1790802984, { levelNumber = 1 }),
        MinesGenerator.generate(1790802985, { levelNumber = 1 }),
        MinesGenerator.generate(1790802645, { levelNumber = 4 }),
    }
    local seen = {}
    for _, level in ipairs(samples) do
        for y = 0, level.height - 1 do
            for x = 0, level.width - 1 do
                local symbol = level.symbols[y + 1][x + 1]
                if symbol == "I" then
                    seen.idol = true
                    assert(findEntity(level, "gold_idol", x + 1, y + 0.75),
                        "Idol must sit at the original offset above its altar")
                elseif symbol == "B" then
                    seen.tiki = true
                    assert(findEntity(level, "giant_tiki_head", x + 1, y + 0.75),
                        "Tiki head must use the original four-pixel vertical offset")
                    assert(hasBackdrop(level, "tiki_body", x, y + 2)
                        and hasBackdrop(level, "tiki_arm_right", x + 2, y + 2)
                        and hasBackdrop(level, "tiki_arm_left", x - 1, y + 2),
                        "Idol-room tiki must have its body and arms")
                elseif symbol == "x" then
                    seen.kali = true
                    assert(findEntity(level, "sacrifice_altar", x, y)
                        and hasBackdrop(level, "kali_body", x - 1, y - 3),
                        "Kali altar must have its original body")
                    local head = findEntity(level, "kali_head", x + 1, y - 4)
                    assert(head and head.properties.variant >= 1
                        and head.properties.variant <= 3,
                        "Kali altar must have one of the original three heads")
                elseif symbol == "T" then
                    seen.ruby = true
                    assert(findEntity(level, "ruby_big", x + 0.5, y + 0.5),
                        "Snake-pit rubies must use the original pixel position")
                elseif symbol == "M" then
                    seen.mattock = true
                    assert(findEntity(level, "mattock", x + 0.5, y + 0.5),
                        "Snake-pit mattock must use the original pixel position")
                end
            end
        end
        for _, spider in ipairs(level.entities) do
            if spider.kind == "giant_spider" then
                seen.spider = true
                assert(findEntity(level, "web", spider.x, spider.y + 1)
                    and findEntity(level, "web", spider.x + 1, spider.y + 1),
                    "Hanging giant spiders must create their two webs")
            end
        end
    end
    for _, kind in ipairs({ "idol", "tiki", "kali", "ruby", "mattock", "spider" }) do
        assert(seen[kind], "Mines samples must exercise " .. kind .. " placement")
    end
end

local function assertShopStockPlacement()
    -- The recorded depth-two shop has rope piles on its smooth-brick floor.
    -- Classic's scrShopItemsGen creates each at xpos+8, ypos+11.
    local level = MinesGenerator.generate(1790807356, { levelNumber = 2 })
    local ropeCount, spectaclesCount = 0, 0
    for _, entity in ipairs(level.entities) do
        if entity.properties.forSale
            and (entity.kind == "rope_pile" or entity.kind == "spectacles") then
            if entity.kind == "rope_pile" then ropeCount = ropeCount + 1
            else spectaclesCount = spectaclesCount + 1 end
            local cellX, cellY = math.floor(entity.x), math.floor(entity.y)
            assert(level.symbols[cellY + 1][cellX + 1] == "i",
                "Shop stock must occupy a stock marker")
            local offsetY = entity.kind == "rope_pile" and 11 or 10
            assert(entity.x == cellX + 0.5 and entity.y == cellY + offsetY / 16,
                "Shop stock must sit centered on the shop floor")
        end
    end
    assert(ropeCount > 0 and spectaclesCount > 0,
        "Recorded shop must include rope piles and spectacles")
end

function MinesGeneratorTest.run()
    assertSpecialRooms()
    assertShopStockPlacement()
    for levelNumber = 1, 4 do
        for seed = 1, 16 do
            local level = MinesGenerator.generate(seed, { levelNumber = levelNumber })
            validateLevel(level)
            assertTrapClearance(level)
        end
    end
    for seed = 1790802984, 1790803008 do
        assertTrapClearance(MinesGenerator.generate(seed, { levelNumber = 1 }))
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
