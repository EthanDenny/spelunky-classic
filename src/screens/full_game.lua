-- The live Mines simulation, with run and display rules for normal play.
local FullLevel = require("src.screens.full_level_playtest")
local Player = require("src.platform.player")
local MinesMusic = require("src.audio.mines_music")
local FullGame = setmetatable({}, { __index = FullLevel })
FullGame.__index = FullGame
local STEP = 1/Player.TICK_RATE

function FullGame.new(app)
    local game = setmetatable(FullLevel.new(app), FullGame)
    game.screenName = "full_game"
    return game
end

function FullGame:enter()
    local width, height, flags = love.window.getMode()
    local x, y, display = love.window.getPosition()
    flags.x, flags.y, flags.display, flags.centered = x, y, display, false
    self.previousWindow = { width = width, height = height, flags = flags,
        maximized = love.window.isMaximized(), mouseVisible = love.mouse.isVisible() }
    local fullscreenFlags = {}
    for key, value in pairs(flags) do fullscreenFlags[key] = value end
    fullscreenFlags.fullscreen, fullscreenFlags.fullscreentype = true, "exclusive"
    fullscreenFlags.resizable, fullscreenFlags.minwidth, fullscreenFlags.minheight = false, 320, 240
    -- Use the display resolution rather than the lab window's requested size.
    assert(love.window.setMode(0, 0, fullscreenFlags), "Could not enter fullscreen")
    love.mouse.setVisible(false)
    self:loadAssets()
    self.levelNumber, self.subtypeIndex = 1, 1
    self.run, self.heldItem, self.heldNpc, self.selectionError = nil, nil, nil, nil
    self.debugCollision = false
    self:generateLevel(love.math.random(1, 2147483646))
end

function FullGame:leave()
    if self.music then self.music:stop() end
    local previous = self.previousWindow
    if not previous then return end
    self.previousWindow = nil
    assert(love.window.setMode(previous.width, previous.height, previous.flags),
        "Could not restore the menu window")
    if previous.maximized then love.window.maximize() end
    love.mouse.setVisible(previous.mouseVisible)
end

function FullGame:generateLevel(seed)
    FullLevel.generateLevel(self, seed)
    self.music = self.music or MinesMusic.new()
    self.music:start(self.app.controls.settings.musicVol)
end

function FullGame:simulationStepBody(input)
    if not self.player:isDead() then FullLevel.simulationStepBody(self, input) end
    if self.player:isDead() then
        self.app:showScreen("menu")
    elseif self.exiting or self.completed then
        self.music:stop()
    elseif self.levelNumber > 1 and self.levelTime > 120 then
        self.music:fade()
    end
end

function FullGame:update(dt)
    self.accumulator = math.min(self.accumulator+dt, STEP*5)
    while self.accumulator >= STEP and self.app.currentScreen == self do
        self:simulationStep()
        self.accumulator = self.accumulator-STEP
    end
end

function FullGame:fallOutOfLevel()
    self.player:kill("fall")
    self.run:capturePlayer(self.player)
end

function FullGame:finishMines()
    self.completed = true
    self.app:showScreen("menu")
end

function FullGame:keypressed(key, scancode, isRepeat)
    if isRepeat or self.player:isDead() then return end
    if self.exiting then return end
    if key == "m" then self.music:toggle() end
    local controls = self.app.controls
    if controls:matches("pay", key) or controls:matches("rope", key)
        or controls:matches("bomb", key) or controls:matches("up", key) then
        FullLevel.keypressed(self, key, scancode, false)
        if self.exiting then self.music:stop() end
    end
end

function FullGame:getViewport()
    local width, height = love.graphics.getDimensions()
    local scale = math.max(1, math.floor(math.min(width/320, height/240)))
    local drawWidth, drawHeight = 320*scale, 240*scale
    return { x = math.floor((width-drawWidth)/2), y = math.floor((height-drawHeight)/2),
        width = drawWidth, height = drawHeight, scale = scale,
        logicalWidth = 320, logicalHeight = 240 }
end

function FullGame:draw()
    local view = self:getViewport()
    love.graphics.clear(0, 0, 0, 1)
    self:drawWorld(view)
    self:drawPlayerHUD(view)
    self:drawGameplayMessages(view)
end

return FullGame
