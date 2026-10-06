-- The live Mines simulation, with run and display rules for normal play.
local FullLevel = require("src.screens.full_level_playtest")
local Player = require("src.platform.player")
local MinesMusic = require("src.audio.mines_music")
local Transition = require("src.screens.level_transition")
local Exit = require("src.platform.structures.exit")
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
    self.mapPreview, self.showRoomPath = false, false
    self:generateLevel()
end

function FullGame:leave()
    if self.music then self.music:stop() end
    self.transition = nil
    local previous = self.previousWindow
    if not previous then return end
    self.previousWindow = nil
    assert(love.window.setMode(previous.width, previous.height, previous.flags),
        "Could not restore the menu window")
    if previous.maximized then love.window.maximize() end
    love.mouse.setVisible(previous.mouseVisible)
end

function FullGame:generateLevel(seed)
    seed = seed or love.math.random(1, 2147483646)
    self.transition = nil
    self.levelStats = { loot = {}, kills = {}, money = 0 }
    FullLevel.generateLevel(self, seed)
    self.music = self.music or MinesMusic.new()
    self.music:start(self.app.controls.settings.musicVol)
end

function FullGame:recordLoot(kind, money)
    local stats = self.levelStats
    stats.loot[kind] = (stats.loot[kind] or 0)+1
    stats.money = stats.money+money
end

function FullGame:recordKill(kind)
    local kills = self.levelStats.kills
    kills[kind] = (kills[kind] or 0)+1
end

function FullGame:advanceLevel()
    Exit.prepare(self)
    self.run:capturePlayer(self.player)
    self.run.messages = {}
    self.transition = Transition.new(self)
    self.exiting = nil
    self.music:stop()
    self.app.controls:clearEdges()
end

function FullGame:simulationStepBody(input)
    if self.transition then self.transition:step(self) return end
    if not self.player:isDead() then FullLevel.simulationStepBody(self, input) end
    if self.player:isDead() then
        self.app:showScreen("menu")
    elseif self.transition or self.exiting or self.completed then
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
    if self.transition then
        if (key == "escape" or self.app.controls:matches("attack", key))
            and self.transition:pressAction() then
            -- oDamselKiss.Room End awards one heart, including an early skip.
            self.rescues = self.transition.rescued and 1 or 0
            self.transition = nil
            FullLevel.advanceLevel(self)
        end
        return
    end
    if self.exiting then return end
    if key == "m" then self.music:toggle() end
    local controls = self.app.controls
    if controls:matches("pay", key) or controls:matches("item", key) or controls:matches("rope", key)
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
    if self.transition then self.transition:draw(self, view) return end
    self:drawWorld(view)
    self:drawPlayerHUD(view)
    self:drawGameplayMessages(view)
end

return FullGame
