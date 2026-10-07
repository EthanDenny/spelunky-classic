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

local function assertMapPreview(app)
    app:showScreen("full_level_playtest")
    local game = app.currentScreen
    game.levelNumber, game.subtypeIndex = 1, 1
    game:generateSelectedLevel(8675309, true)
    local level, player, tick = game.level, game.player, game.world.time
    local x, y, bombs, ropes = player.x, player.y, game.run.bombs, game.run.ropes
    app:keypressed("tab", "tab", false)
    app:update(1)
    assert(game.world.time == tick and player.x == x and player.y == y,
        "The whole-map preview must pause the live level")
    for _, key in ipairs({ "a", "s", "x", "z", "up" }) do
        app:keypressed(key, key, false)
        app:keyreleased(key, key)
    end
    assert(game.run.bombs == bombs and game.run.ropes == ropes and not game.exiting,
        "Preview controls must not spend tools or enter exits")
    local width, height = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(width, height)
    local function capture()
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        app:draw()
        love.graphics.pop()
        return canvas:newImageData()
    end
    local plain = capture()
    app:keypressed("f2", "f2", false)
    local path = capture()
    local changed = 0
    for py = 64, height-41, 4 do
        for px = 0, width-1, 4 do
            local r, g, b = plain:getPixel(px, py)
            local pr, pg, pb = path:getPixel(px, py)
            if math.abs(r-pr)+math.abs(g-pg)+math.abs(b-pb) > 0.03 then changed = changed+1 end
        end
    end
    assert(changed > 100, "Room-path colors must render over the whole-map preview")
    canvas:release()
    app:keypressed("n", "n", false)
    assert(game.seed ~= level.seed, "Next seed must generate a new map while previewing")
    app:keypressed("t", "t", false)
    assertSelectedLevel(game.level, "standard")
    local nextTick = game.world.time
    app:update(1)
    assert(game.world.time == nextTick, "Generating a map must preserve the paused preview")
    app:keypressed("tab", "tab", false)
    app:update(1/30)
    assert(game.world.time > nextTick, "Closing the map must resume live gameplay")
    app:keypressed("f2", "f2", false)
end

function Test.run(app)
    assertMapPreview(app)
    local playtest = app.screens.full_level_playtest
    playtest:loadAssets()
    assertProgressionPair(playtest)
    playtest.subtypeIndex = 1
    playtest.levelNumber = 1
    playtest.run = nil
    playtest:generateLevel(8675309)
    for _, subtype in ipairs({ "standard", "idol", "altar", "snake_pit", "shop", "dark" }) do
        playtest:keypressed("t", "t", false)
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
