local Test = {}

function Test.run(app)
    local viewer = app.screens.enemy_ai
    viewer:setPage(9)
    assert(#viewer.scenarios == 2, "Boulder scenarios must be available in Scenario Tests")
    viewer:draw()
    local fall, wall = unpack(viewer.scenarios)
    assert(wall.world:has("solid", 5, 8), "The wall replay must begin intact")
    local rolled, crushed = false, false
    for _ = 1, 140 do
        viewer:stepScenario(fall)
        viewer:stepScenario(wall)
        local rock = fall.traps.boulders[1]
        if rock and rock.vx < 0 then rolled = true end
        if not wall.world:has("solid", 5, 8) then crushed = true end
    end
    assert(rolled and crushed,
        "The boulder replays must show a grounded roll and destroyed ordinary brick")

    viewer:setPage(10)
    assert(#viewer.scenarios == 2, "Statue scenarios must be available in Scenario Tests")
    viewer:draw()
    local armed, untouched = unpack(viewer.scenarios)
    for _ = 1, 103 do
        viewer:stepScenario(armed)
        viewer:stepScenario(untouched)
    end
    assert(armed.idol.held and armed.traps.traps[1].state == "armed"
        and #armed.traps.boulders == 0,
        "The idol must arm the head without releasing a boulder before its 100-step alarm")
    assert(not untouched.idol.held and untouched.traps.traps[1].state == "idle"
        and #untouched.traps.boulders == 0,
        "An untouched idol must leave the statue closed")
    viewer:stepScenario(armed)
    viewer:stepScenario(untouched)
    assert(armed.traps.traps[1].state == "fired" and #armed.traps.boulders == 1,
        "The head must open and release a boulder when its alarm expires")
    viewer:draw()
    for _ = 105, 190 do
        viewer:stepScenario(armed)
        viewer:stepScenario(untouched)
    end
    assert(armed.runs == 2 and untouched.runs == 2,
        ("Both statue replays must reset automatically (%d, %d; ticks %d, %d)")
            :format(armed.runs, untouched.runs, armed.tick, untouched.tick))
    viewer:setPage(1)
end

return Test
