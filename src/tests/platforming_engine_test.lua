local Test = {}

function Test.run(app)
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
end

return Test
