local PlaytestLog = require("src.observability.playtest_log")

local Test = {}

function Test.run(app)
    local pointerPath = "playtest-logs/latest.txt"
    local previousPointer = love.filesystem.read(pointerPath)
    local log = assert(PlaytestLog.start(), "A playtest must open its persistent log")
    local ok, err = pcall(function()
        app.playtestLog = log
        app:showScreen("platforming_engine")
        app.screens.platforming_engine:resetCourse()
        app:update(1 / 30)
        app:showScreen("world_generation")
        app:update(1 / 60)
        app:showScreen("enemy_ai")
        app:update(1 / 30)
        app:showScreen("full_level_playtest")
        app:update(1 / 30)
        app:keypressed("f9", "f9", false)
        log:close()

        local pointer = assert(love.filesystem.read(pointerPath))
        local contents = assert(love.filesystem.read(log.path))
        assert(pointer == log.path .. "\n", "Last-playtest pointer must name the current session")
        assert(contents:find('"type":"level"', 1, true)
            and contents:find('"sourceFingerprint":"', 1, true)
            and contents:find('"type":"tick_start"', 1, true)
            and contents:find('"type":"tick"', 1, true)
            and contents:find('"type":"bookmark"', 1, true),
            "A real screen must persist its initial world, live ticks, and bug marker")
        for _, screen in ipairs({ "platforming_engine", "enemy_ai", "full_level_playtest" }) do
            local foundTick = false
            for line in contents:gmatch("[^\n]+") do
                if line:find('"type":"tick"', 1, true)
                    and line:find('"screen":"' .. screen .. '"', 1, true) then
                    foundTick = true
                    break
                end
            end
            assert(foundTick, "Every simulation screen must record an actual live tick")
        end
        assert(contents:find('"type":"generation"', 1, true),
            "World generation must record the level shown to the tester")
    end)
    log:close()
    app.playtestLog = nil
    for _, screen in ipairs({ "platforming_engine", "enemy_ai", "full_level_playtest" }) do
        local simulation = app.screens[screen]
        if simulation.world then simulation.world.playtestLog = nil end
        if simulation.player then simulation.player.playtestLog = nil end
    end
    love.filesystem.remove(log.path)
    if previousPointer then
        love.filesystem.write(pointerPath, previousPointer)
    else
        love.filesystem.remove(pointerPath)
    end
    assert(ok, err)
end

return Test
