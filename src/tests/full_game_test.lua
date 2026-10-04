local Controls = require("src.input.classic_controls")
local Player = require("src.platform.player")
local RunState = require("src.game.run_state")
local Test = {}

local function terrain(level)
    local cells = {}
    for _, row in ipairs(level.tiles) do
        for _, tile in ipairs(row) do cells[#cells+1] = tile.kind end
    end
    return table.concat(cells, ":")
end

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

local function useExit(app, game, inspect)
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
    assert(game.transition and game.level == level and game.run == run,
        "The exit must open an intermission before generating the next level")
    assert(not game.music.source:isPlaying(), "Intermissions must remain silent")
    local time, worldTime, bombs, ropes = run.time, game.world.time, run.bombs, run.ropes
    app:keypressed("a", "a", false)
    app:keypressed("s", "s", false)
    app:keypressed("up", "up", false)
    game:simulationStepBody({ right = true, attack = true })
    assert(game.level == level and run.time == time and game.world.time == worldTime
        and run.bombs == bombs and run.ropes == ropes,
        "Intermissions must freeze gameplay and reject gameplay tools")
    app:keypressed("escape", "escape", false)
    assert(game.level == level and app.currentScreenName == "full_game",
        "ESC must act as the source START key and hurry an unfinished tally without leaving Full game")
    for _ = 1, 200 do
        game:simulationStepBody({})
        if game.transition:isReady() then break end
    end
    assert(game.transition:isReady(), "The completion tally must finish")
    if inspect then inspect(game.transition) end
    app:draw()
    app:keypressed("x", "x", true)
    assert(game.transition and game.level == level, "Key repeat cannot skip the intermission")
    app:keypressed("x", "x", false)
    assert(not game.transition, "A fresh ACTION must continue after the tally finishes")
end

function Test.run(app)
    local controls = app.controls
    local hardwareIsDown = love.keyboard.isDown
    local randomState = love.math.getRandomState()
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
        -- Full game's keyboard filter must still allow the shared jump callback
        -- path to deliver a tap completed before the next simulation tick.
        love.keyboard.isDown = function() return false end
        for _ = 1, 20 do
            app:update(1/30)
            if game.player:isGroundState() and game.player.vy == 0 then break end
        end
        assert(game.player:isGroundState() and game.player.vy == 0,
            "The generated entrance must settle before testing a ground jump")
        app:keypressed("z", "z", false)
        app:keyreleased("z", "z")
        app:update(1/30)
        -- Some entrance seeds have a low ceiling; the launch impulse proves
        -- delivery without assuming four pixels of unobstructed headroom.
        assert(game.player.vy == -4 and game.player.state == Player.STATES.falling,
            "Full game must receive a short jump tap through its shared input path")
        love.keyboard.isDown = hardwareIsDown

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
        love.keyboard.isDown = function() return false end
        for _ = 1, 20 do
            app:update(1/30)
            if game.player:isGroundState() then break end
        end
        local gold = game:spawnEntity("gold_chunk", game.player.x, game.player.y)
        local snake = game:spawnEntity("snake", game.player.x+64, game.player.y+8)
        snake:damage(1, game.player.x)
        app:update(1/30)
        assert(not gold.alive and snake.deathCounted,
            "The summary fixture must collect treasure and count a kill through gameplay")
        game.run:flushMoney()
        game.run.money = game.run.money-50
        local exit = game.level.exit
        game.player.x, game.player.y = exit.x*16+8, exit.y*16+8
        game.player.state, game.player.vx, game.player.vy = Player.STATES.standing, 0, 0
        game.player.health = 3
        local shotgun = game:spawnEntity("shotgun", game.player.x, game.player.y)
        assert(shotgun:pickup(game.player, game.run), "The carried gun must be picked up")
        game.heldItem = shotgun
        local damsel = game:spawnEntity("damsel", game.player.x, game.player.y+8)
        assert(damsel:pickup(game.player), "The damsel must be carried to the exit")
        game.heldNpc = damsel
        local oldRun = game.run
        useExit(app, game, function(summary)
            assert(summary.money == 100 and summary.moneyCount == 100 and summary.totalMoney == 50,
                "The tally must show gross level loot separately from money after spending")
            assert(#summary.loot == 2 and #summary.kills == 1 and summary.rescued,
                "Collected gold, the rescued damsel, and the slain snake must populate the summary")
            assert(game.player.health == 3, "Rescue healing must wait until the transition room ends")
            local time = game.run.time
            for _ = 1, 100 do game:simulationStepBody({}) end
            assert(summary.kissed and game.run.time == time,
                "The rescued damsel must kiss during the interlude without advancing the run clock")
        end)
        assert(game.run == oldRun and game.levelNumber == 2 and game.player.health == 4
            and game.run.money == 50 and game.run.damsels == 1
            and game.heldItem and game.heldItem.kind == "shotgun",
            "Continuing must preserve the run and held item and award the rescue heart once")
        assert(game.levelStats.money == 0 and next(game.levelStats.loot) == nil
            and next(game.levelStats.kills) == nil, "The next level must begin a fresh tally")
        app:showScreen("menu")
        love.keyboard.isDown = hardwareIsDown

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

        love.math.setRandomSeed(721466261)
        game = start(app)
        -- The reported run repeated its terrain on 1-2, 1-3 and 1-4.
        game:generateLevel(721466261)
        local layouts = {}
        for depth = 1, 4 do
            local layout = terrain(game.level)
            for previous, seen in ipairs(layouts) do
                assert(layout ~= seen, "Full game repeated terrain from 1-"..previous.." on 1-"..depth)
            end
            layouts[#layouts+1] = layout
            useExit(app, game)
        end
        assert(game.completed and game.levelNumber == 4 and app.currentScreenName == "menu",
            "The current playable Mines run returns to the menu after the fourth completion summary")
        assert(not game.music.source:isPlaying(), "Completion must stop level music")
    end)
    love.keyboard.isDown = hardwareIsDown
    love.math.setRandomState(randomState)
    if app.currentScreenName == "full_game" then app:showScreen("menu") end
    lab.levelNumber, lab.subtypeIndex, lab.run = labLevel, labSubtype, labRun
    app.controls = controls
    app.screens.menu.selectedIndex = menuSelection
    assert(ok, err)
    print("Full game lifecycle tests passed")
end

return Test
