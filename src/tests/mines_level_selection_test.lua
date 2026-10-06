local Test = {}

local function hasEntity(level, kind)
    for _, entity in ipairs(level.entities) do
        if entity.kind == kind then return true end
    end
    return false
end

local function assertSelectedLevel(level, subtype)
    assert(level.selectedSubtype == subtype, "Selected Mines type must be visible in level data")
    if subtype == "standard" then
        assert(not level.hasIdol and not level.hasAltar and not level.hasSnakePit
            and not level.hasShop and not level.dark,
            "Standard must not contain a special Mines feature")
    elseif subtype == "idol" then
        assert(level.hasIdol and hasEntity(level, "gold_idol"),
            "Idol selection must generate an actual idol room")
    elseif subtype == "altar" then
        assert(level.hasAltar and hasEntity(level, "sacrifice_altar"),
            "Kali selection must generate an actual altar room")
    elseif subtype == "snake_pit" then
        assert(level.hasSnakePit and hasEntity(level, "mattock"),
            "Snake Pit selection must generate its pit and mattock")
    elseif subtype == "shop" then
        assert(level.hasShop and hasEntity(level, "shopkeeper"),
            "Shop selection must generate a staffed shop")
    elseif subtype == "dark" then
        assert(level.dark and hasEntity(level, "lamp"),
            "Dark selection must generate a dark level with its lamp")
    end
end

local function assertProgressionPair(playtest)
    -- These runs exercise selection in 1-2, 1-3, and the guaranteed 1-4 fallback.
    for _, seed in ipairs({ 3, 1, 7 }) do
        playtest.subtypeIndex, playtest.levelNumber = 1, 1
        playtest:generateSelectedLevel(seed, true)
        local chestCount, keyCount = 0, 0
        for depth = 1, 4 do
            local chests, keys = 0, 0
            for _, entity in ipairs(playtest.level.entities) do
                if entity.kind == "locked_chest" or entity.kind == "key" then
                    assert(depth > 1, "The Udjat pair must not appear in Mines 1-1")
                    assert(not playtest.world:solidAtPoint(entity.x * 16, entity.y * 16),
                        "The Udjat chest and key must spawn outside solid terrain")
                    if entity.kind == "locked_chest" then
                        chests = chests + 1
                        assert(playtest.world:solidAtPoint(entity.x * 16,
                            (math.floor(entity.y) + 1) * 16),
                            "The locked chest must spawn on solid ground")
                    else
                        keys = keys + 1
                    end
                end
            end
            assert(chests == keys, "The locked chest must generate with its key")
            chestCount, keyCount = chestCount + chests, keyCount + keys
            assert(chestCount <= 1 and keyCount <= 1,
                "A Mines run must not generate another Udjat chest or key")
            if depth < 4 then playtest:advanceLevel() end
        end
        assert(chestCount == 1 and keyCount == 1,
            "Every Mines run must generate the Udjat pair by 1-4")
        playtest:keypressed("r", "r", false)
        assert(hasEntity(playtest.level, "locked_chest") and hasEntity(playtest.level, "key"),
            "A fresh run at Mines 1-4 must restore the Udjat pair")
    end
end

function Test.run(app)
    local preview = app.screens.world_generation
    preview:loadAssets()
    preview.subtypeSelector:select(1)
    preview.levelNumber = 1
    assert(preview:generate(8675309))
    preview:draw()
    local layout = preview:getLayout()
    local itemHeight = layout.subtype.height / #preview.subtypeSelector.items
    local function clickSubtype(index)
        preview:mousepressed(layout.subtype.x + 10,
            layout.subtype.y + (index - 0.5) * itemHeight, 1)
    end

    clickSubtype(2)
    assertSelectedLevel(preview.level, "standard")
    clickSubtype(3)
    assertSelectedLevel(preview.level, "idol")
    local idolSeed = preview.seed
    preview:keypressed("r", "r", false)
    assert(preview.seed ~= idolSeed, "Generate must find the next matching seed")
    assertSelectedLevel(preview.level, "idol")
    clickSubtype(4)
    assert(preview.levelNumber == 2, "Kali rooms require Mines 1-2 or later")
    assertSelectedLevel(preview.level, "altar")
    for _, subtype in ipairs({ "snake_pit", "shop", "dark" }) do
        preview:keypressed("right", "right", false)
        assertSelectedLevel(preview.level, subtype)
    end
    preview:draw()
    preview:changeLevelNumber(-1)
    assert(preview.levelNumber == 1 and preview.level.selectedSubtype == "random",
        "An unavailable type must clear when previewing Mines 1-1")

    local playtest = app.screens.full_level_playtest
    playtest:loadAssets()
    assertProgressionPair(playtest)
    playtest.subtypeIndex = 1
    playtest.levelNumber = 1
    playtest.run = nil
    playtest:generateLevel(8675309)
    for _, subtype in ipairs({ "standard", "idol", "altar", "snake_pit", "shop", "dark" }) do
        playtest:keypressed("]", "]", false)
        assertSelectedLevel(playtest.level, subtype)
    end
    assert(playtest.levelNumber == 2, "Playtest must move to an eligible depth")
    playtest:draw()
    local darkSeed = playtest.seed
    playtest:keypressed("r", "r", false)
    assert(playtest.seed == darkSeed, "Reset must preserve the selected seed")
    assertSelectedLevel(playtest.level, "dark")
    playtest:keypressed("n", "n", false)
    assert(playtest.seed ~= darkSeed, "Next seed must find a new matching level")
    assertSelectedLevel(playtest.level, "dark")
    playtest:advanceLevel()
    assert(playtest.levelNumber == 3 and playtest.level.selectedSubtype == "random",
        "Normal exit progression must leave the test-only type filter")

    preview.subtypeSelector:select(1)
    preview.levelNumber = 1
    preview.level = nil
    preview.seed = nil
    playtest.subtypeIndex = 1
    playtest.levelNumber = 1
    playtest.run = nil
    playtest:generateLevel(8675309)
    playtest.player.health = 1
    playtest.run.health = 1
    playtest.run.bombs = 0
    playtest.run.money = 7500
    playtest:keypressed("r", "r", false)
    assert(playtest.seed == 8675309 and playtest.levelNumber == 1
        and playtest.player.health == 4 and playtest.run.bombs == 4
        and playtest.run.money == 0,
        "Restarting the selected Mines level must restore starting health, bombs, and gold")
end

return Test
