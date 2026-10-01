local App = {}
App.__index = App
local ClassicControls = require("src.input.classic_controls")

local UI_FONT = "assets/fonts/NotoSans-Regular.ttf"
local SYMBOL_FONT = "assets/fonts/NotoSansMono-Regular.ttf"

local function newUIFont(size)
    local font = love.graphics.newFont(UI_FONT, size)
    local symbols = love.graphics.newFont(SYMBOL_FONT, size)
    font:setFallbacks(symbols)
    return font, symbols
end

function App.new(playtestLog)
    return setmetatable({
        playtestLog = playtestLog,
        controls = nil,
        currentScreen = nil,
        currentScreenName = nil,
        screens = {},
        fonts = {},
    }, App)
end

function App:load()
    self.controls = ClassicControls.load()
    if self.playtestLog then self.playtestLog:record("controls_loaded", {
        keySource = self.controls.keySource, settingsSource = self.controls.settingsSource,
        keys = self.controls.keys, settings = self.controls.settings,
    }) end
    love.graphics.setDefaultFilter("nearest", "nearest")

    self.fontFallbacks = {}
    self.fonts.small, self.fontFallbacks.small = newUIFont(14)
    self.fonts.body, self.fontFallbacks.body = newUIFont(18)
    self.fonts.menu, self.fontFallbacks.menu = newUIFont(25)
    self.fonts.title, self.fontFallbacks.title = newUIFont(40)

    self.screens = {
        menu = require("src.screens.menu").new(self),
        animation_viewer = require("src.screens.animation_viewer").new(self),
        world_generation = require("src.screens.world_generation").new(self),
        platforming_engine = require("src.screens.platforming_engine").new(self),
        enemy_ai = require("src.screens.enemy_ai").new(self),
        full_level_playtest = require("src.screens.full_level_playtest").new(self),
    }

    self:showScreen("menu")
end

function App:preload()
    -- GameMaker displays its splash while resources are loaded. Keep the
    -- frameless splash alive while the prototype's shared assets are warmed.
    self.screens.animation_viewer:loadPage(1)
    self.screens.world_generation:loadAssets()
    self.screens.platforming_engine:loadAssets()
    self.screens.enemy_ai:loadAssets()
    self.screens.full_level_playtest:loadAssets()
end

function App:showScreen(name)
    local nextScreen = assert(self.screens[name], "Unknown screen: " .. tostring(name))
    local previousName = self.currentScreenName

    if self.currentScreen and self.currentScreen.leave then
        self.currentScreen:leave(name)
    end

    self.currentScreen = nextScreen
    self.currentScreenName = name

    if self.currentScreen.enter then
        self.currentScreen:enter(previousName)
    end
    if self.playtestLog then
        self.playtestLog:record("screen", { from = previousName, to = name })
    end
end

function App:update(dt)
    if self.currentScreen and self.currentScreen.update then
        self.currentScreen:update(dt)
    end
    if self.playtestLog then
        self.playtestLog:record("frame", { screen = self.currentScreenName, dt = dt,
            state = self.currentScreen and not self.currentScreen.world
                and self.playtestLog.capture(self.currentScreen) or nil })
    end
end

function App:draw()
    if self.currentScreen and self.currentScreen.draw then
        self.currentScreen:draw()
    end
end

function App:keypressed(key, scancode, isRepeat)
    if self.playtestLog then
        self.playtestLog:record("key", { screen = self.currentScreenName,
            key = key, scancode = scancode, repeated = isRepeat })
        if key == "f9" and not isRepeat then
            self.playtestLog:mark(self.currentScreenName, self.currentScreen)
            return
        end
    end
    if key == "escape" then
        if self.currentScreenName == "menu" then
            love.event.quit()
        else
            self:showScreen("menu")
        end
        return
    end

    if self.currentScreen and self.currentScreen.keypressed then
        self.currentScreen:keypressed(key, scancode, isRepeat)
    end
end

function App:mousemoved(x, y, dx, dy)
    if self.playtestLog then
        self.playtestLog:record("mouse_move", { screen = self.currentScreenName,
            x = x, y = y, dx = dx, dy = dy })
    end
    if self.currentScreen and self.currentScreen.mousemoved then
        self.currentScreen:mousemoved(x, y, dx, dy)
    end
end

function App:keyreleased(key, scancode)
    if self.playtestLog then
        self.playtestLog:record("key_release", { screen = self.currentScreenName,
            key = key, scancode = scancode })
    end
end

function App:mousepressed(x, y, button)
    if self.playtestLog then
        self.playtestLog:record("mouse_press", { screen = self.currentScreenName,
            x = x, y = y, button = button })
    end
    if self.currentScreen and self.currentScreen.mousepressed then
        self.currentScreen:mousepressed(x, y, button)
    end
end

function App:mousereleased(x, y, button)
    if self.playtestLog then
        self.playtestLog:record("mouse_release", { screen = self.currentScreenName,
            x = x, y = y, button = button })
    end
end

function App:wheelmoved(x, y)
    if self.playtestLog then
        self.playtestLog:record("wheel", { screen = self.currentScreenName, x = x, y = y })
    end
    if self.currentScreen and self.currentScreen.wheelmoved then
        self.currentScreen:wheelmoved(x, y)
    end
end

return App
