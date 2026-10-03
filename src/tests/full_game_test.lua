local Controls = require("src.input.classic_controls")
local Player = require("src.platform.player")
local RunState = require("src.game.run_state")
local Test = {}

local function start(app)
    app:showScreen("menu")
    app:keypressed("6", "6", false)
    assert(app.currentScreenName == "full_game", "Menu option 6 must launch Full game")
    local game = app.currentScreen
    assert(game.music and game.music.source:isPlaying() and game.music.source:isLooping(),
        "Full game must play looping Mines music on entry")
    assert(game.music.source:getType() == "stream" and game.music.source:getPitch() == 1
        and math.abs(game.music.source:getVolume()-0.01) < 0.000001,
        "Mines music must stream at normal pitch with the configured Classic volume")
    assert(love.audio.getVolume() == 0, "Music must preserve the smoke suite's global mute")
    local fullscreen, mode = love.window.getFullscreen()
    assert(fullscreen and mode == "exclusive", "Full game must enter real exclusive fullscreen")
    assert(game.levelNumber == 1 and game.level.absoluteLevel == 1 and game.subtypeIndex == 1
        and game.player.health == 4 and game.run.money == 0 and game.run.bombs == 4
        and game.run.ropes == 4 and not game.heldItem and not game.heldNpc,
        "Every Full game entry must begin a fresh unrestricted 1-1 with starting resources")
    return game
end

local function useExit(app, game)
    local exit = game.level.exit
    game.player.x, game.player.y = exit.x*16+8, exit.y*16+8
    game.player.vx, game.player.vy, game.player.stunTimer = 0, 0, 0
    game.player.state, game.player.whipping = Player.STATES.standing, false
    app:keypressed("up", "up", false)
    assert(game.exiting == 0, "UP at the real door must begin the exit animation")
    assert(not game.music.source:isPlaying(), "Entering an exit must stop the level music")
    local level, run = game.level, game.run
    app:keypressed("r", "r", false)
    app:keypressed("n", "n", false)
    assert(game.exiting == 0 and game.level == level and game.run == run,
        "Restart and reroll keys must stay disabled during the exit animation")
    for _ = 1, 32 do game:simulationStepBody({}) end
end

function Test.run(app)
    local controls = app.controls
    local menuSelection = app.screens.menu.selectedIndex
    local width, height, flags = love.window.getMode()
    local mouseVisible = love.mouse.isVisible()
    local lab = app.screens.full_level_playtest
    local labLevel, labSubtype, labRun = lab.levelNumber, lab.subtypeIndex, lab.run
    local ok, err = pcall(function()
        local normalControls = Controls.fromContents(nil, "0\n1\n1\n0\n3\n9\n15")
        app.controls = normalControls
        lab.levelNumber, lab.subtypeIndex, lab.run = 4, 3, RunState.new(17)
        lab.run.money, lab.run.bombs = 9999, 99
        local game = start(app)
        local run, level, seed = game.run, game.level, game.seed
        local view = game:getViewport()
        assert(view.logicalWidth == 320 and view.logicalHeight == 240 and view.scale % 1 == 0,
            "Fullscreen must preserve Classic's 320x240 camera on an integer pixel grid")
        assert(view.x >= 0 and view.y >= 0 and view.x+view.width <= love.graphics.getWidth()
            and view.y+view.height <= love.graphics.getHeight(), "The game viewport must fit the display")
        for _, key in ipairs({ "r", "n", "-", "=", "[", "]", "b" }) do
            app:keypressed(key, key, false)
        end
        assert(game.run == run and game.level == level and game.seed == seed
            and game.levelNumber == 1 and not game.debugCollision,
            "Testing keys must not reroll, reset, skip a level, select a type or show colliders")
        assert(lab.levelNumber == 4 and lab.subtypeIndex == 3 and lab.run.money == 9999,
            "Starting a Full game must preserve the separate lab session")
        -- A configured gameplay binding still works when it uses a lab shortcut key.
        app.controls = Controls.fromContents("38\n40\n37\n39\n90\n88\n67\n16\n78\n83\n70\n80", nil)
        app:keypressed("n", "n", false)
        assert(game.run == run and game.level == level and game.run.bombs == 3
            and #game.tools.bombs == 1, "A remapped bomb key must throw a bomb without rerolling")
        app.controls = normalControls
        game.run.money = 333
        useExit(app, game)
        assert(app.currentScreenName == "full_game" and game.levelNumber == 2
            and game.run == run and game.run.money == 333 and game.run.bombs == 3,
            "The door must advance to 1-2 while preserving the live run")
        local music = game.music.source
        assert(music:isPlaying() and music:getPitch() == 1,
            "The next Mines level must restart its music at normal pitch")
        game.levelTime = 119
        game:simulationStepBody({})
        assert(music:getPitch() == 1, "Music must retain normal pitch before the ghost warning")
        game.levelTime, game.player.invincibleTimer = 120, 999
        for _ = 1, 110 do game:simulationStepBody({}) end
        assert(music:isPlaying() and math.abs(music:getPitch()-34100/44100) < 0.000001,
            "After two minutes, the music must slow by 100 Hz per tick for at most 100 ticks")
        app:keypressed("m", "m", false)
        assert(not music:isPlaying(), "M must disable music")
        app:keypressed("m", "m", true)
        assert(not music:isPlaying(), "Key repeat must not re-enable music")
        useExit(app, game)
        assert(not music:isPlaying() and music:getPitch() == 1,
            "A new level must reset pitch while preserving the music toggle")
        app:keypressed("m", "m", false)
        assert(music:isPlaying(), "M must re-enable music in the current level")
        app:draw()
        app:keypressed("escape", "escape", false)
        local restoredWidth, restoredHeight, restoredFlags = love.window.getMode()
        assert(app.currentScreenName == "menu" and restoredWidth == width and restoredHeight == height
            and restoredFlags.fullscreen == flags.fullscreen and love.mouse.isVisible() == mouseVisible,
            "Leaving Full game must restore the menu's window and cursor")
        assert(not music:isPlaying(), "Returning to the menu must stop Full game music")

        game = start(app)
        run, level = game.run, game.level
        game.tools:explode(game.player.x, game.player.y)
        app:update(1/30)
        assert(game.player:isDead() and app.currentScreenName == "menu"
            and game.run == run and game.level == level,
            "A lethal explosion must end the run at the menu without regenerating the level")
        assert(not game.music.source:isPlaying(), "Death must stop Full game music")

        game = start(app)
        level = game.level
        game.player.y = game.world.height*16+48
        app:update(1/30)
        assert(game.player:isDead() and app.currentScreenName == "menu" and game.level == level,
            "Falling out of the level must kill the player rather than reroll the map")

        game = start(app)
        for _ = 1, 4 do useExit(app, game) end
        assert(game.completed and game.levelNumber == 4 and app.currentScreenName == "menu",
            "The current playable Mines run returns to the menu after the fourth exit")
        assert(not game.music.source:isPlaying(), "Completion must stop level music")
    end)
    if app.currentScreenName == "full_game" then app:showScreen("menu") end
    lab.levelNumber, lab.subtypeIndex, lab.run = labLevel, labSubtype, labRun
    app.controls = controls
    app.screens.menu.selectedIndex = menuSelection
    assert(ok, err)
    print("Full game lifecycle tests passed")
end

return Test
