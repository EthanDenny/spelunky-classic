local App = require("src.app")
local Startup = require("src.startup")
local PlaytestLog = require("src.observability.playtest_log")

local app
local playtestLog
local startup = {
    phase = "splash",
    elapsed = 0,
    minimumTime = tonumber(os.getenv("SPELUNKY_SPLASH_TIME")) or Startup.MINIMUM_SPLASH_TIME,
    drawn = false,
    ready = false,
    image = nil,
}

local function hasArgument(args, expected)
    for _, argument in ipairs(args or {}) do
        if argument == expected then return true end
    end
    return false
end

local function observed(callback, ...)
    local arguments = { ... }
    local count = select("#", ...)
    local ok, result = xpcall(function() return callback(unpack(arguments, 1, count)) end, debug.traceback)
    if not ok then
        if playtestLog then playtestLog:record("error", { traceback = result,
            screen = app and app.currentScreenName }) end
        error(result, 0)
    end
    return result
end

local function runSmokeTest()
    assert(love.audio.getVolume() == 0,
        "The smoke suite must mute application audio before loading any screens")
    require("src.tests.startup_test").run()
    require("src.tests.font_test").run(app)
    require("src.tests.animation_catalog_test").run()
    require("src.tests.shop_item_physics_test").run(app)
    require("src.tests.gameplay_messages_test").run(app)
    require("src.tests.shop_behaviour_test").run()
    require("src.tests.kali_altar_test").run(app)
    require("src.tests.mines_completion_test").run()
    require("src.tests.platform_player_test").run()
    require("src.tests.platform_item_test").run()
    require("src.tests.platforming_engine_test").run(app)
    require("src.tests.enemy_ai_test").run(app)
    require("src.tests.mine_item_scenarios_test").run(app)
    require("src.tests.bomb_scenarios_test").run(app)
    require("src.tests.boulder_statue_scenarios_test").run(app)
    require("src.tests.kali_scenarios_test").run(app)
    require("src.tests.mines_generator_test").run()
    require("src.tests.mines_level_selection_test").run(app)
    require("src.tests.entity_population_test").run()
    require("src.tests.generated_world_test").run()
    require("src.tests.dynamic_world_test").run()
    require("src.tests.gameplay_systems_test").run(app)
    require("src.tests.playtest_log_test").run(app)
    require("src.tests.full_game_test").run(app)

    local screenNames = {
        "menu",
        "animation_viewer",
        "world_generation",
        "platforming_engine",
        "enemy_ai",
        "full_level_playtest",
    }

    for _, screenName in ipairs(screenNames) do
        app:showScreen(screenName)
        app:update(1 / 60)
        app:draw()
    end

    local animationViewer = app.screens.animation_viewer
    assert(animationViewer.pageIndex == 1, "Animation viewer must default to the Player page")
    assert(animationViewer.facing == "left", "Animation viewer must default to facing left")
    animationViewer:setPage(#require("src.animation.original_catalog").pages)
    animationViewer:draw()
    animationViewer:keypressed("right", "right", false)
    assert(animationViewer.pageIndex == 1, "Animation page navigation must wrap")
    animationViewer:keypressed("f", "f", false)
    assert(animationViewer.facing == "right", "Animation facing toggle failed")
    animationViewer:keypressed("f", "f", false)

    local worldGeneration = app.screens.world_generation
    for levelType = 1, #worldGeneration.selector.items do
        worldGeneration.selector:select(levelType)
        local depths = worldGeneration.selector:getSelected().depthCount
        for depth = 1, depths do
            worldGeneration.levelNumber = depth
            worldGeneration:generate(8675309 + depth)
            worldGeneration:draw()
        end
    end
    worldGeneration.selector:select(1)
    worldGeneration.levelNumber = 4
    worldGeneration:generate(8675309)
    worldGeneration.showRoomPath = true
    worldGeneration:draw()
    worldGeneration.showRoomPath = false

    local fullLevel = app.screens.full_level_playtest
    assert(fullLevel.world and fullLevel.player, "Full level playtest did not build its simulation")
    require("src.tests.classic_controls_test").run(app)
    require("src.tests.original_hud_item_test").run(app)
    require("src.tests.crate_action_regression_test").run(app)
    require("src.tests.render_depth_test").run(app)
    require("src.tests.playtest_feedback_test").run(app)
    require("src.tests.mines_report_regression_test").run(app)
    require("src.tests.mines_followup_regression_test").run(app)
    require("src.tests.boulder_source_regression_test").run(app)
    fullLevel:buildSimulation()
    assert(fullLevel.level.entrance, "Full level playtest generated no entrance")
    assert(fullLevel.hud and fullLevel.hud.images
        and fullLevel.hud.glyphs[0] and fullLevel.hud.glyphs[58],
        "Full level playtest must load the original sprite HUD and font")
    do
        local Item = require("src.platform.item")
        local pickup = Item.new({
            kind = "rock",
            x = fullLevel.player.x / 16,
            y = (fullLevel.player.y + 4) / 16,
        }, { width = 8, height = 8 })
        fullLevel.items = { pickup }
        fullLevel.collectibles = {}
        fullLevel.tools.bombs = {}
        assert(fullLevel:pickupNearestItem() and fullLevel.heldItem == pickup and pickup.held,
            "Full level playtest must pick up the nearest carry object")
        fullLevel:buildSimulation()
    end
    do
        local tileX, tileY
        fullLevel.world:each("solid", function(x, y)
            if not tileX then tileX, tileY = x, y end
        end)
        assert(tileX, "Generated level needs a solid cell for the crush regression")
        fullLevel.player.x, fullLevel.player.y = tileX * 16 + 8, tileY * 16 + 8
        fullLevel.player.invincibleTimer = 60
        fullLevel:simulationStep()
        assert(fullLevel.player.health == 0 and fullLevel.player.state == "dead",
            "Solid overlap must crush even an invincible player")
        fullLevel.run.health = 4
        fullLevel:buildSimulation()

    end
    do
        for depth = 1, 4 do
            fullLevel.levelNumber = depth
            fullLevel:generateLevel(44000 + depth)
            fullLevel:simulationStep()
            fullLevel:draw()
        end
        fullLevel.levelNumber = 1
        fullLevel:generateLevel(8675309)
        fullLevel.levelNumber = 4
        fullLevel:generateLevel(8675309)
        local finalMinesLevel = fullLevel.level
        fullLevel:advanceLevel()
        assert(fullLevel.levelNumber == 4 and fullLevel.level == finalMinesLevel,
            "The Mines exit must not advance into an unimplemented area")
        fullLevel.run = require("src.game.run_state").new(2)
        fullLevel.levelNumber = 2
        fullLevel:generateLevel(2)
        assert(fullLevel.level.dark, "The dark Mines sample must still generate")
        fullLevel:draw()
        fullLevel.levelNumber = 1
        fullLevel:generateLevel(8675309)
    end
    assert(app.screens.menu.items[5].screen == "full_level_playtest",
        "Full level playtest must be the fifth menu section")

    app:showScreen("menu")
    app:keypressed("down", "down", false)
    app:keypressed("return", "return", false)
    assert(app.currentScreenName == "world_generation", "Menu activation failed")

    app:keypressed("escape", "escape", false)
    assert(app.currentScreenName == "menu", "Back navigation failed")
end

function love.load(args)
    for index, argument in ipairs(args or {}) do
        if argument == "--analyze-oracle" then
            local ok, message = xpcall(function()
                require("src.tests.original_oracle_analyzer").run(args[index + 1])
            end, debug.traceback)
            if not ok then
                io.stderr:write(message .. "\n")
            end
            love.event.quit(ok and 0 or 1)
            return
        end
    end

    if hasArgument(args, "--smoke-test") then
        love.audio.setVolume(0)
        Startup.openMainWindow(false)
        startup.phase = "running"
        app = App.new()
        app:load()
        local ok, message = xpcall(runSmokeTest, debug.traceback)
        if not ok then
            io.stderr:write(message .. "\n")
        end
        love.event.quit(ok and 0 or 1)
        return
    end

    playtestLog = PlaytestLog.start()
    startup.image = observed(Startup.loadSplashImage)
end

function love.update(dt)
    if startup.phase == "splash" then
        startup.elapsed = startup.elapsed + dt
        if startup.drawn and not startup.ready then
            app = App.new(playtestLog)
            observed(app.load, app)
            observed(app.preload, app)
            startup.ready = true
        end
        if startup.ready and startup.elapsed >= startup.minimumTime then
            observed(Startup.openMainWindow, true)
            startup.image = nil
            startup.phase = "running"
        end
        return
    end
    if app then observed(app.update, app, dt) end
end

function love.draw()
    if startup.phase == "splash" then
        observed(Startup.drawSplash, startup.image)
        startup.drawn = true
        return
    end
    if app then observed(app.draw, app) end
end

function love.keypressed(key, scancode, isRepeat)
    if startup.phase == "running" and app then observed(app.keypressed, app, key, scancode, isRepeat) end
end

function love.keyreleased(key, scancode)
    if startup.phase == "running" and app then observed(app.keyreleased, app, key, scancode) end
end

function love.mousemoved(x, y, dx, dy)
    if startup.phase == "running" and app then observed(app.mousemoved, app, x, y, dx, dy) end
end

function love.mousepressed(x, y, button)
    if startup.phase == "running" and app then observed(app.mousepressed, app, x, y, button) end
end

function love.mousereleased(x, y, button)
    if startup.phase == "running" and app then observed(app.mousereleased, app, x, y, button) end
end

function love.wheelmoved(x, y)
    if startup.phase == "running" and app then observed(app.wheelmoved, app, x, y) end
end

function love.quit()
    if playtestLog then playtestLog:close() end
end

function love.focus(focused)
    if app then app:focus(focused) end
    if playtestLog then playtestLog:record("focus", { focused = focused }) end
end

function love.resize(width, height)
    if playtestLog then playtestLog:record("resize", { width = width, height = height }) end
end
