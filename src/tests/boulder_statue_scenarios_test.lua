local Test = {}

function Test.run(app)
    local viewer = app.screens.enemy_ai
    viewer:setPage(9)
    assert(#viewer.scenarios == 7,
        "One Boulder & Statue page must include boulder interactions and idol alarms")
    viewer:draw()
    local fall, wall, block, snake, ruby, armed, untouched = unpack(viewer.scenarios)
    assert(wall.world:has("solid", 5, 8) and block.block.alive
        and snake.enemy.alive and ruby.treasure.alive,
        "The rolling boulder must encounter intact brick, a block, an enemy, and treasure")
    local rolled, crushed, crushedBlock, crushedSnake, metRuby, passedRuby =
        false, false, false, false, false, false
    for _ = 1, 140 do
        for _, scenario in ipairs({ fall, wall, block, snake, ruby }) do
            viewer:stepScenario(scenario)
        end
        local rock = fall.traps.boulders[1]
        if rock and rock.vx < 0 then rolled = true end
        if not wall.world:has("solid", 5, 8) then crushed = true end
        if not block.block.alive then crushedBlock = true end
        if not snake.enemy.alive then crushedSnake = true end
        local rubyRock = ruby.traps.boulders[1]
        if rubyRock and math.abs(rubyRock.x - ruby.treasure.x) < 18
            and math.abs(rubyRock.y - ruby.treasure.y) < 20 then metRuby = true end
        if metRuby and rubyRock and rubyRock.x < ruby.treasure.x then passedRuby = true end
    end
    assert(rolled and crushed and crushedBlock and crushedSnake,
        "Rolling boulders must destroy ordinary brick, movable blocks, and enemies")
    assert(metRuby and passedRuby and ruby.treasure.alive,
        "The boulder must encounter loose treasure without destroying it, as in Classic")

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
