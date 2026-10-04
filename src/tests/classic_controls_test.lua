local ClassicControls = require("src.input.classic_controls")

local Test = {}

function Test.run(app)
    local sourceDefaults = ClassicControls.fromContents(nil, nil)
    assert(sourceDefaults:matches("bomb", "a") and sourceDefaults:matches("rope", "s")
        and sourceDefaults.settings.downToRun and not sourceDefaults.settings.gamepadOn,
        "Missing config files must fall back to scrInit's original control defaults")
    local archivedKeys = assert(love.filesystem.read("original-game-reference/keys.cfg"))
    local archivedSettings = assert(love.filesystem.read("original-game-reference/settings.cfg"))
    local original = ClassicControls.fromContents(archivedKeys, archivedSettings)
    assert(original:matches("left", "left") and original:matches("up", "up")
        and not original:matches("left", "a") and not original:matches("up", "w")
        and not original:matches("down", "s"),
        "Classic's keys.cfg must use arrow movement, never WASD movement")
    assert(original:matches("jump", "z") and original:matches("attack", "x")
        and original:matches("item", "c") and original:matches("run", "lshift")
        and original:matches("bomb", "a") and original:matches("rope", "s")
        and original:matches("flare", "f") and original:matches("pay", "p"),
        "Classic's shipped keys.cfg must bind the twelve actions in source order")
    assert(not original.settings.fullscreen and original.settings.graphicsHigh
        and not original.settings.downToRun and original.settings.gamepadOn
        and original.settings.screenScale == 3,
        "The archived settings.cfg must override scrInit's defaults in its original line order")

    local remapped = ClassicControls.fromContents(
        "73\n75\n74\n76\n90\n88\n67\n16\n81\n84\n70\n80",
        "1\n0\n0\n0\n3\n20\n-4")
    assert(remapped:matches("left", "j") and not remapped:matches("left", "left")
        and remapped:matches("bomb", "q") and remapped:matches("rope", "t")
        and not remapped.settings.downToRun and not remapped.settings.graphicsHigh
        and remapped.settings.musicVol == 17 and remapped.settings.soundVol == 0,
        "The original line-based files must support configured keys and clamped settings")

    local active = app.controls
    local loaded = ClassicControls.fromContents(
        assert(love.filesystem.read(active.keySource)),
        assert(love.filesystem.read(active.settingsSource)))
    assert(active.keys.left == loaded.keys.left and active.keys.bomb == loaded.keys.bomb
        and active.keys.rope == loaded.keys.rope
        and active.settings.downToRun == loaded.settings.downToRun,
        "The app must use the actual files selected at startup")

    local room = app.screens.platforming_engine
    room:enter()
    room:resetCourse()
    app.controls = original
    local hardwareIsDown = love.keyboard.isDown
    local ok, err = pcall(function()
        love.keyboard.isDown = function(key)
            return key == "w" or key == "a" or key == "s" or key == "d"
        end
        local wasd = room:getInput()
        assert(not wasd.left and not wasd.right and not wasd.up and not wasd.down,
            "WASD must not move the player with Classic's default file")
        love.keyboard.isDown = function(key) return key == "left" or key == "up" end
        local arrows = room:getInput()
        assert(arrows.left and arrows.up and not arrows.right and not arrows.down,
            "The arrow keys must drive movement from keys.cfg")
    end)
    love.keyboard.isDown = hardwareIsDown
    assert(ok, err)

    -- Real App callbacks must deliver taps that end before the next 30 Hz step.
    local previousScreen = app.currentScreenName
    app.controls = original
    app:showScreen("platforming_engine")
    local held = {}
    local function jumpTap(key)
        held[key] = true
        app:keypressed(key, key, false)
        held[key] = nil
        app:keyreleased(key, key)
    end
    local function resetJump()
        room:resetCourse()
        held = {}
    end
    ok, err = pcall(function()
        love.keyboard.isDown = function(...)
            for index = 1, select("#", ...) do
                if held[select(index, ...)] then return true end
            end
            return false
        end
        resetJump()
        app:update(1/60)
        local y = room.player.y
        jumpTap("z")
        app:update(1/60)
        assert(room.player.y == y-4 and room.player.vy == -4,
            "A press/release between fixed ticks must still launch a short jump")
        app:update(1/30)
        assert(math.abs(room.player.vy+3) < 0.000001,
            "The released tap must use full gravity on the next tick")

        resetJump()
        jumpTap("z")
        app:keypressed("a", "a", false)
        app:update(2/30)
        assert(room.player.vy == -3,
            "A bomb's held-input read must not consume jump edges; catch-up ticks consume them only once")

        resetJump()
        held.z = true
        app:keypressed("z", "z", false)
        app:update(1/30)
        held.z = nil
        app:keyreleased("z", "z")
        held.z = true
        app:keypressed("z", "z", false)
        room.player.equipment.cape = true
        app:update(1/30)
        assert(room.player.capeOpen,
            "Release and repress between ticks must reach airborne cape controls even if the key remains held")
        room.player.capeOpen = false
        app:keypressed("z", "z", true)
        app:update(1/30)
        assert(not room.player.capeOpen, "OS key repeat must not create another jump press")

        resetJump()
        room.player.y = room.player.y-32
        room.player.state = "falling"
        jumpTap("z")
        app:update(1/30)
        assert(room.player.vy > 0, "A queued input event does not permit a midair ground jump")
        room.player.y, room.player.vy = 18*16-8, 0
        room.player.state = "standing"
        app:update(1/30)
        assert(room.player.vy == 0, "An ineligible tap must not wait for a later landing")

        resetJump()
        jumpTap("z")
        app:showScreen("menu")
        app:showScreen("platforming_engine")
        app:update(1/30)
        assert(room.player.vy == 0, "Menu navigation must discard pending gameplay jump events")

        resetJump()
        jumpTap("z")
        room:resetCourse()
        app:update(1/30)
        assert(room.player.vy == 0, "Resetting a course must discard pending jump events")

        resetJump()
        jumpTap("z")
        love.focus(false)
        app:update(1/30)
        assert(room.player.vy == 0, "Losing focus must discard pending jump events")
        love.focus(true)

        app.controls = ClassicControls.fromContents("38\n40\n37\n39\n32", nil)
        resetJump()
        jumpTap("z")
        app:update(1/30)
        assert(room.player.vy == 0, "The old jump binding must stop delivering events after a remap")
        jumpTap("space")
        app:update(1/30)
        assert(room.player.vy == -4, "The remapped jump key must preserve short taps")
    end)
    love.keyboard.isDown = hardwareIsDown
    app.controls = active
    app:showScreen(previousScreen)
    assert(ok, err)

    room:resetCourse()
    app.controls = remapped
    local remaining = room.ropes
    room:keypressed("s")
    assert(room.ropes == remaining, "The original rope key must stop working after a remap")
    room:keypressed("t")
    assert(room.ropes == remaining - 1 and #room.tools.ropes == 1,
        "The configured rope key must reach the live gameplay screen")

    app.controls = original
    local fullLevel = app.screens.full_level_playtest
    local bombs, ropes = fullLevel.run.bombs, fullLevel.run.ropes
    fullLevel:keypressed("f")
    fullLevel:keypressed("g")
    assert(fullLevel.run.bombs == bombs and fullLevel.run.ropes == ropes,
        "The Mines playtest must no longer spend tools with F/G")
    fullLevel:keypressed("a")
    assert(fullLevel.run.bombs == bombs - 1 and #fullLevel.tools.bombs == 1,
        "Classic's A bomb binding must work in the Mines playtest")
    local foundSpace = false
    for y = 2, fullLevel.world.height - 3 do
        for x = 2, fullLevel.world.width - 3 do
            local px, py = x * 16 + 8, y * 16 + 8
            if not fullLevel.world:collidesSolid(fullLevel.player, px, py)
                and not fullLevel.world:collidesSolid(fullLevel.player, px, py - 1) then
                fullLevel.player.x, fullLevel.player.y = px, py
                foundSpace = true
                break
            end
        end
        if foundSpace then break end
    end
    assert(foundSpace, "The generated Mines level needs clear space to test an upward rope")
    fullLevel:keypressed("s")
    assert(fullLevel.run.ropes == ropes - 1 and #fullLevel.tools.ropes == 1,
        "Classic's S rope binding must work in the Mines playtest")
    fullLevel.run.bombs, fullLevel.run.ropes = bombs, ropes
    fullLevel:buildSimulation()
    app.controls = active
end

return Test
