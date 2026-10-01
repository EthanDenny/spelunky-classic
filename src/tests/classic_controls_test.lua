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
