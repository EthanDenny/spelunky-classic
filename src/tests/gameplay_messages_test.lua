local FullLevel = require("src.screens.full_level_playtest")
local RunState = require("src.game.run_state")
local Player = require("src.platform.player")
local Item = require("src.platform.item")
local World = require("src.platform.world")
local OriginalMessages = require("src.ui.original_messages")
local Test = {}

function Test.run(app)
    local run, player = RunState.new(17), Player.new(80, 104)
    Item.collect("bomb_bag", run, player)
    assert(run:currentMessage() and run:currentMessage().text == "YOU GOT 3 MORE BOMBS!"
        and run:currentMessage().timer == 120, "Supplies must use scrStealItem's text and duration")
    Item.collect("spectacles", run, player)
    assert(run:currentMessage().text == "YOU GOT SPECTACLES!\nYOUR EYESIGHT SEEMS IMPROVED...",
        "New messages must replace earlier messages with the source's two lines")
    Item.collect("gold_bar", run, player)
    assert(run:currentMessage().text == "YOU GOT SPECTACLES!\nYOUR EYESIGHT SEEMS IMPROVED...",
        "Treasure must collect silently without a prototype cash notice")
    for _ = 1, 120 do run:update() end
    assert(not run:currentMessage(), "Expired messages must not reveal a queued older message")

    local game = FullLevel.new(app)
    game:loadAssets()
    game.levelNumber = 2
    game:generateLevel(17)
    game.world = World.new(42, 34, 16)
    game.world:fill("solid", 0, 7, 42, 1)
    game.player = Player.new(80, 104)
    game.player.state = Player.STATES.standing
    game.enemies, game.items, game.collectibles, game.hiddenEntities = {}, {}, {}, {}
    game.level.hasSnakePit, game.level.hasAltar, game.level.dark = false, false, false
    game.run.messages = {}
    game.levelTime = 120
    game:simulationStepBody({})
    assert(game.run:currentMessage().text == "A CHILL RUNS UP YOUR SPINE...\nLET'S GET OUT OF HERE!"
        and game.run:currentMessage().timer == 200 and not game.ghostSpawned,
        "The warning precedes the ghost by thirty seconds")
    game.run.messages = {}
    game.levelTime = 150
    game:simulationStepBody({})
    assert(game.ghostSpawned and not game.run:currentMessage(), "Ghost arrival adds no second notice")
    game:openContainer(game:spawnEntity("locked_chest", 100, 100))
    assert(not game.run:currentMessage(), "A locked chest must not show the added locked prompt")
    game:openContainer(game:spawnEntity("jar", 100, 100))
    assert(not game.run:currentMessage(), "Smashing a pot must not announce its contents")
    game.enemies = {}
    game.levelTime, game.entryMessageTimer, game.darkEntryAnnounced = 0, 10, false
    game.level.dark, game.level.hasAltar = true, true
    for _ = 1, 9 do game:simulationStepBody({}) end
    assert(not game.run:currentMessage(), "Level feelings wait for the source ten-tick alarm")
    game:simulationStepBody({})
    assert(game.run:currentMessage().text == "I CAN'T SEE A THING!\nI'D BETTER USE THESE FLARES!")
    for _ = 1, 209 do game:simulationStepBody({}) end
    assert(not game.run:currentMessage(), "Darkness leaves a ten-tick gap before the second feeling")
    game:simulationStepBody({})
    assert(game.run:currentMessage().text == "I CAN HEAR PRAYERS TO KALI!"
        and game.run:currentMessage().timer == 200)

    -- Independent pixel fixture from oLevel.Draw's coordinates and sFontSmall;
    -- comparing the entire camera also detects added panels, shadows or wrapping.
    run:addMessage("AA\nA", 200)
    local actual, expected = love.graphics.newCanvas(320, 240), love.graphics.newCanvas(320, 240)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(actual)
    love.graphics.clear(0.2, 0.3, 0.4, 1)
    OriginalMessages.draw(run, { x = 0, y = 0, width = 320, height = 240,
        scale = 1, logicalWidth = 320, logicalHeight = 240 })
    love.graphics.setCanvas(expected)
    love.graphics.clear(0.2, 0.3, 0.4, 1)
    local glyph = love.graphics.newImage(
        "original-game-reference/source/extracted/config/Sprites/sFontSmall.images/image 33.png")
    glyph:setFilter("nearest", "nearest")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(glyph, 152, 216)
    love.graphics.draw(glyph, 160, 216)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.draw(glyph, 156, 224)
    love.graphics.pop()
    local a, b = actual:newImageData(), expected:newImageData()
    assert(a:getString() == b:getString(), "Messages must match Classic's font, position and colours pixel for pixel")
    actual:release()
    expected:release()
    print("Source gameplay message tests passed")
end
return Test
