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
        (assert(love.filesystem.read(active.settingsSource))))
    assert(active.keys.left == loaded.keys.left and active.keys.bomb == loaded.keys.bomb
        and active.keys.rope == loaded.keys.rope
        and active.settings.downToRun == loaded.settings.downToRun,
        "The app must use the actual files selected at startup")

    do
        local controls = ClassicControls.fromContents(nil, "0\n1\n1\n1", "-1\n1\n3\n5\n7\n8\n4\n6\n10")
        local axis, buttons = { 0, 0, 0 }, {}
        local pad = {
            getAxisCount = function() return 3 end,
            getAxis = function(_, index) return axis[index] end,
            getHatCount = function() return 1 end,
            getHat = function() return "lu" end,
            isDown = function(_, index) return not not buttons[index] end,
        }
        local hardware = love.joystick.getJoysticks
        local ok, err = pcall(function()
            love.joystick.getJoysticks = function() return { pad } end
            axis[3], buttons[7] = 0.2, true
            controls:pollGamepad()
            local input = controls:playerInput(true)
            assert(input.left and input.up and input.jump and input.jumpPressed
                and controls:takeGamepadPress("bomb"),
                "A configured Z-axis trigger, diagonal hat and bomb button reach Classic controls")
            controls:pollGamepad()
            assert(not controls:playerInput(true).jumpPressed and not controls:takeGamepadPress("bomb"),
                "Holding a gamepad button cannot repeat its pressed edge")
            axis[3], buttons[7] = 0, false
            controls:pollGamepad()
            assert(controls:playerInput(true).jumpReleased, "Releasing the trigger delivers jump release")
            controls.settings.gamepadOn = false
            controls:pollGamepad()
            assert(not controls.padHeld.left, "Disabling gamepad input clears its held directions")
        end)
        love.joystick.getJoysticks = hardware
        assert(ok, err)
    end

    local room = app.screens.full_level_playtest
    room:enter()
    local groundY
    local function resetRoom()
        room.levelNumber, room.subtypeIndex = 1, 1
        room:generateSelectedLevel(8675309, true)
        room.enemies, room.items, room.collectibles, room.fakeBones = {}, {}, {}, {}
        room.traps.traps = {}
        for y = 4, room.world.height-2 do
            for x = 2, room.world.width-3 do
                local px, py = x*16+8, y*16-8
                if room.world:solidAtPoint(px, py+8)
                    and not room.world:overlaps("solid", px-8, py-48, px+8, py+8) then
                    room.player.x, room.player.y = px, py
                    groundY = py
                    return
                end
            end
        end
        error("The generated level needs a clear grounded input fixture")
    end
    resetRoom()
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
    app:showScreen("full_level_playtest")
    local held = {}
    local function jumpTap(key)
        held[key] = true
        app:keypressed(key, key, false)
        held[key] = nil
        app:keyreleased(key, key)
    end
    local function resetJump()
        resetRoom()
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
        room.player.y, room.player.vy = groundY, 0
        room.player.state = "standing"
        app:update(1/30)
        assert(room.player.vy == 0, "An ineligible tap must not wait for a later landing")

        resetJump()
        jumpTap("z")
        app:showScreen("menu")
        app:showScreen("full_level_playtest")
        assert(not room:getInput(true).jumpPressed, "Menu navigation must discard pending gameplay jump events")
        app:update(1/30)

        resetJump()
        jumpTap("z")
        resetRoom()
        app:update(1/30)
        assert(room.player.vy == 0, "Resetting a level must discard pending jump events")

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

    resetRoom()
    app.controls = remapped
    resetRoom()
    assert(#room.level.decorations == 0, "Low graphics omits the source's cave fringe tiles")
    room.tools:explode(120, 120)
    for _, particle in ipairs(room.tools.effects.particles) do
        assert(particle.kind ~= "flame", "Low graphics suppresses bomb flames")
    end
    room.effects:blood(100, 60, 1)
    for _ = 1, 5 do room.effects:update(room.world) end
    assert(#room.effects.trails == 0, "Low graphics suppresses blood trails")
    local remaining = room.run.ropes
    room:keypressed("s")
    assert(room.run.ropes == remaining, "The original rope key must stop working after a remap")
    room:simulationStepBody({ attack = true })
    room:keypressed("t")
    assert(room.run.ropes == remaining and #room.tools.ropes == 0,
        "A rope press during the whip animation must not spend a rope")
    for _ = 1, 20 do room:simulationStepBody({}) end
    room:keypressed("t")
    assert(room.run.ropes == remaining - 1 and #room.tools.ropes == 1,
        "The configured rope key must reach the live gameplay screen")

    resetRoom()
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
