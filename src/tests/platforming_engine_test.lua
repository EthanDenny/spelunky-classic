local Test = {}

function Test.run(app)
    local savedControls = app.controls
    app.controls = require("src.input.classic_controls").fromContents(
        assert(love.filesystem.read("original-game-reference/keys.cfg")),
        assert(love.filesystem.read("original-game-reference/settings.cfg")))
    local screen = app.screens.platforming_engine
    screen:enter()
    screen:resetCourse()

    local world = screen.world
    for x = 0, world.width - 1 do
        assert(world:has("solid", x, 0) and world:has("solid", x, world.height - 1),
            "The platforming room must have an unbroken ceiling and floor")
    end
    for y = 0, world.height - 1 do
        assert(world:has("solid", 0, y) and world:has("solid", world.width - 1, y),
            "The platforming room must have unbroken side walls")
    end

    local rock = screen.items[1]
    assert(#screen.items == 1 and rock.kind == "rock" and not rock.held,
        "A loose rock must be available in the platforming room")
    screen.player.x, screen.player.y = rock.x, 18 * 16 - 8
    screen:simulationStep({ down = true, attack = true })
    assert(screen.heldItem == rock and rock.held,
        "Down plus attack must pick up the room's rock")
    screen:simulationStep({})
    screen:simulationStep({ attack = true })
    assert(screen.heldItem == nil and not rock.held and rock.vx > 0 and rock.vy < 0,
        "Attack while carrying must launch the rock into the shared item physics")
    for _ = 1, 100 do screen:simulationStep({}) end
    assert(rock.x >= 16 + rock:getCollisionHalfWidth()
        and rock.x <= (world.width - 1) * 16 - rock:getCollisionHalfWidth(),
        "A thrown rock must stay within the enclosed room")

    screen:resetCourse()
    assert(#screen.items == 1 and not screen.items[1].held,
        "Resetting the room must restore its loose rock")

    local ropeCount = screen.ropes
    screen:simulationStep({ attack = true })
    screen:keypressed("s")
    assert(screen.ropes == ropeCount and #screen.tools.ropes == 0,
        "A rope press during the whip animation must not spend a rope")
    for _ = 1, 20 do screen:simulationStep({}) end
    screen:keypressed("s")
    assert(screen.ropes == ropeCount - 1 and #screen.tools.ropes == 1,
        "The platforming room must deploy a rope with Classic's S binding")
    for _ = 1, 40 do screen:simulationStep({}) end
    assert(screen.tools.ropes[1].deployed and #screen.tools.ropes[1].segments > 0,
        "A thrown rope must become a climbable line in the platforming room")
    local bombCount = screen.bombs
    screen:keypressed("f")
    screen:keypressed("g")
    assert(screen.bombs == bombCount and screen.ropes == ropeCount - 1,
        "The previous F/G tool shortcuts must not spend Classic's bomb or rope inventory")
    screen:keypressed("a")
    assert(screen.bombs == bombCount - 1 and #screen.tools.bombs == 1,
        "Classic's A binding must throw a bomb in the platforming room")
    app.controls = savedControls
end

return Test
