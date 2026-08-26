local App = require("src.app")

local app

local function runSmokeTest()
    require("src.tests.font_test").run(app)
    require("src.tests.animation_catalog_test").run()
    require("src.tests.platform_player_test").run()
    require("src.tests.platform_item_test").run()
    require("src.tests.enemy_ai_test").run()
    require("src.tests.mines_generator_test").run()
    require("src.tests.classic_area_generator_test").run()
    require("src.tests.entity_population_test").run()
    require("src.tests.generated_world_test").run()

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
    assert(fullLevel.level.entrance, "Full level playtest generated no entrance")
    do
        local Item = require("src.platform.item")
        local pickup = Item.new({
            kind = "rock",
            x = fullLevel.player.x / 16,
            y = (fullLevel.player.y + 4) / 16,
        }, { width = 8, height = 8 })
        fullLevel.items = { pickup }
        assert(fullLevel:pickupNearestItem() and fullLevel.heldItem == pickup and pickup.held,
            "Full level playtest must pick up the nearest carry object")
        fullLevel:buildSimulation()
    end
    assert(#app.screens.menu.items == 5
        and app.screens.menu.items[5].screen == "full_level_playtest",
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

    app = App.new()
    app:load()

    for _, argument in ipairs(args or {}) do
        if argument == "--smoke-test" then
            local ok, message = xpcall(runSmokeTest, debug.traceback)
            if not ok then
                io.stderr:write(message .. "\n")
            end
            love.event.quit(ok and 0 or 1)
        end
    end
end

function love.update(dt)
    if app then app:update(dt) end
end

function love.draw()
    if app then app:draw() end
end

function love.keypressed(key, scancode, isRepeat)
    if app then app:keypressed(key, scancode, isRepeat) end
end

function love.mousemoved(x, y, dx, dy)
    if app then app:mousemoved(x, y, dx, dy) end
end

function love.mousepressed(x, y, button)
    if app then app:mousepressed(x, y, button) end
end

function love.wheelmoved(x, y)
    if app then app:wheelmoved(x, y) end
end
