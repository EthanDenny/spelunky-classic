local Test = {}

local function advance(viewer, scenario, tick)
    while scenario.tick < tick do viewer:stepScenario(scenario) end
end

function Test.run(app)
    local viewer = app.screens.enemy_ai
    viewer:enter()
    viewer:setPage(28)
    assert(viewer.scenarios[1] and viewer.scenarios[1].kaliGame,
        "The scenario viewer must expose a playable Kali Altar page after the item pages")
    viewer:draw()
    local selectedRow
    for _, row in ipairs(viewer.pageRows) do
        if row.index == 28 then selectedRow = row end
    end
    assert(selectedRow and selectedRow.y >= 78 and selectedRow.y+selectedRow.height <= love.graphics.getHeight()-90,
        "Kali's sidebar row must be visible and clickable at the default window size")

    local previous = viewer.scenarios
    viewer:mousepressed(selectedRow.x+8, selectedRow.y+8, 1)
    assert(viewer.pageIndex == 28 and viewer.scenarios ~= previous,
        "Clicking the visible Kali row must rebuild the selected page")
    local cases = {}
    for _, scenario in ipairs(viewer.scenarios) do
        cases[scenario.definition.kaliSetup.key] = scenario
    end
    assert(cases.ghost.player.ball and #cases.ghost.kaliGame.chains == 4,
        "The third-defilement replay must start with the previous ball punishment")
    local held = cases.held
    advance(viewer, held, 34)
    assert(held.kaliGame.heldNpc == held.body and held.kaliGame.run.favor == 0,
        "The held-body replay must wait for its scripted release before scoring favor")
    advance(viewer, held, 100)
    assert(not held.kaliGame.heldNpc and held.body.sacrificed and held.kaliGame.run.favor == 8,
        "The release replay must deliver ACTION to the real game and sacrifice after landing")

    local favor = { living_damsel = 8, dead_damsel = 8, living_caveman = 2,
        dead_caveman = 1, living_shopkeeper = 12, dead_shopkeeper = 6,
        equipment = 8, kapala = 16, bombs = 32, vitality = 48, devoured = -8, forgiven = 0 }
    for key, expected in pairs(favor) do
        local scenario = assert(cases[key], "Missing Kali replay: " .. key)
        advance(viewer, scenario, 60)
        assert(scenario.body.sacrificed and scenario.kaliGame.run.favor == expected,
            key .. " must show the source result through the scenario simulation")
    end
    assert(cases.equipment.kaliGame.items[1] and cases.equipment.kaliGame.run.kaliGift == 1,
        "The equipment replay must visibly spawn a gift")
    assert(cases.kapala.kaliGame.items[1].kind == "kapala"
        and not cases.kapala.kaliGame.items[1].properties.forSale,
        "The Kapala replay must display the free pickup")
    assert(cases.bombs.kaliGame.run.bombs == 99 and cases.vitality.player.health >= 8,
        "Bomb and vitality replays must change the displayed player resources")
    for _, key in ipairs({ "spiders", "chain", "ghost" }) do advance(viewer, cases[key], 60) end
    assert(cases.spiders.altar.destroyed and #cases.spiders.kaliGame.enemies == 6,
        "The blast replay must open the Kali head and release six real spiders")
    assert(cases.chain.altar.destroyed and cases.chain.player.ball
        and #cases.chain.kaliGame.chains == 4,
        "The support-collapse replay must attach and render the ball and chain")
    assert(cases.ghost.altar.destroyed and cases.ghost.kaliGame.level.dark
        and cases.ghost.kaliGame.enemies[1].kind == "ghost",
        "The third-defilement replay must darken its scene and summon a real Ghost")
    for _, scenario in ipairs(viewer.scenarios) do
        assert(scenario.event, scenario.definition.title .. " must expose its observed outcome")
    end
    viewer.scrollY = viewer.maxScroll
    viewer:draw()
    local tick = cases.kapala.tick
    viewer:keypressed("space", "space", false)
    viewer:update(1/30)
    assert(cases.kapala.tick == tick, "Pause must stop Kali replay ticks")
    viewer:keypressed("space", "space", false)
    advance(viewer, cases.kapala, 209)
    viewer:stepScenario(cases.kapala)
    assert(cases.kapala.runs == 2 and cases.kapala.tick == 0
        and cases.kapala.kaliGame.run.favor == 8 and #cases.kapala.kaliGame.items == 0,
        "Automatic replay must restore the initial favor and remove the prior gift")
    viewer:keypressed("r", "r", false)
    assert(viewer.scenarios[1].tick == 0 and viewer.scenarios[1].kaliGame.run.kaliPunish == 0,
        "Restart must rebuild fresh Kali scenes")
    viewer:setPage(1)
    print("Kali viewer scenarios passed")
end

return Test
