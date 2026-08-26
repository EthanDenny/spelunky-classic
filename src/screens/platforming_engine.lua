local Player = require("src.platform.player")
local World = require("src.platform.world")

local PlatformingEngine = {}
PlatformingEngine.__index = PlatformingEngine

local HEADER_HEIGHT = 88
local FOOTER_HEIGHT = 42
local STEP = 1 / Player.TICK_RATE

local COLORS = {
    background = { 0.035, 0.031, 0.027 },
    panel = { 0.075, 0.064, 0.052 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.72, 0.18, 0.10 },
}

function PlatformingEngine.new(app)
    return setmetatable({
        app = app,
        world = nil,
        player = nil,
        accumulator = 0,
        images = {},
        debugCollision = false,
    }, PlatformingEngine)
end

function PlatformingEngine:loadAssets()
    if self.images.brick then
        return
    end
    local function load(path)
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        return image
    end
    self.images.brick = load("assets/original/mines/brick.png")
    self.images.brickAlt = load("assets/original/mines/brick_alt.png")
    self.images.brickDown = load("assets/original/mines/brick_down.png")
    self.images.ladder = load("assets/original/mines/ladder.png")
    self.images.ladderTop = load("assets/original/mines/ladder_top.png")
    self.images.background = load("assets/original/mines/bg_cave.png")
    self.images.rope = load("assets/original/platform/rope/sRope.png")
    self.images.ropeTop = load("assets/original/platform/rope/sRopeTop.png")
    self.images.background:setWrap("repeat", "repeat")
end

function PlatformingEngine:resetCourse()
    self.world = World.makeTestCourse()
    self.player = Player.new(5 * 16 + 8, 18 * 16 - 8)
    self.player.state = Player.STATES.standing
    self.player.spriteName = "sStandLeft"
    self.player:loadAssets()
    self.accumulator = 0
end

function PlatformingEngine:enter()
    self:loadAssets()
    if not self.world then
        self:resetCourse()
    end
end

function PlatformingEngine:getInput()
    return {
        left = love.keyboard.isDown("left", "a"),
        right = love.keyboard.isDown("right", "d"),
        up = love.keyboard.isDown("up", "w"),
        down = love.keyboard.isDown("down", "s"),
        jump = love.keyboard.isDown("z", "space"),
        sprint = love.keyboard.isDown("lshift", "rshift"),
        attack = love.keyboard.isDown("x", "c", "k", "lctrl", "rctrl"),
        downToRun = true,
    }
end

function PlatformingEngine:update(dt)
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        self.player:step(self.world, self:getInput())
        self.accumulator = self.accumulator - STEP
        if self.player.y > self.world.height * self.world.tileSize + 32 then
            self:resetCourse()
        end
    end
end

function PlatformingEngine:keypressed(key, _, isRepeat)
    if isRepeat then
        return
    end
    if key == "r" then
        self:resetCourse()
    elseif key == "b" then
        self.debugCollision = not self.debugCollision
    end
end

function PlatformingEngine:getViewport()
    local width, height = love.graphics.getDimensions()
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local availableHeight = height - HEADER_HEIGHT - FOOTER_HEIGHT
    local scale = math.max(1, math.floor(math.min(width / worldWidth, availableHeight / worldHeight)))
    return {
        x = math.floor((width - worldWidth * scale) / 2),
        y = HEADER_HEIGHT + math.floor((availableHeight - worldHeight * scale) / 2),
        width = worldWidth * scale,
        height = worldHeight * scale,
        scale = scale,
    }
end

function PlatformingEngine:drawRope(tileX, tileY)
    local above = self.world:has("rope", tileX, tileY - 1)
    local centerX = tileX * 16 + 8
    local top = tileY * 16

    if not above then
        -- oRopeTop is 8x8 with origin (4,4). The first oRope body is
        -- created eight pixels below it at x-8 and uses origin (4,4).
        love.graphics.draw(self.images.ropeTop, centerX - 4, top)
        love.graphics.draw(self.images.rope, centerX - 12, top + 8)
    else
        love.graphics.draw(self.images.rope, centerX - 12, top)
        love.graphics.draw(self.images.rope, centerX - 12, top + 8)
    end
end

function PlatformingEngine:drawWorld(viewport)
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local backgroundQuad = love.graphics.newQuad(0, 0, worldWidth, worldHeight,
        self.images.background:getDimensions())

    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.images.background, backgroundQuad, 0, 0)
    self.world:each("platform", function(x, y)
        love.graphics.draw(self.images.brickDown, x * 16, y * 16)
    end)
    self.world:each("solid", function(x, y)
        local image = (x * 17 + y * 31) % 7 == 0 and self.images.brickAlt or self.images.brick
        love.graphics.draw(image, x * 16, y * 16)
    end)
    self.world:each("ladder", function(x, y)
        love.graphics.draw(self.images.ladder, x * 16, y * 16)
    end)
    self.world:each("ladderTop", function(x, y)
        love.graphics.draw(self.images.ladderTop, x * 16, y * 16)
    end)
    self.world:each("rope", function(x, y)
        self:drawRope(x, y)
    end)

    self.player:draw()

    if self.debugCollision then
        local halfWidth = self.player:getCollisionHalfWidth()
        local topOffset, bottomOffset = self.player:getVerticalBounds()
        love.graphics.setColor(0.2, 1, 0.35, 0.85)
        love.graphics.rectangle("line", math.floor(self.player.x - halfWidth) + 0.5,
            math.floor(self.player.y + topOffset) + 0.5,
            halfWidth * 2 - 1, bottomOffset - topOffset - 1)
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function PlatformingEngine:drawHeader(width)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, width, HEADER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, HEADER_HEIGHT - 1, width, 1)

    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("PLATFORMING ENGINE", 20, 10)

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print("ORIGINAL 30 Hz MOVEMENT MODEL", 22, 60)

    local mode = self.player.runHeld >= 10 and "SPRINT" or "WALK"
    local status = string.format("%-12s  %s  VX %5.2f  VY %5.2f",
        string.upper(self.player.state:gsub("_", " ")), mode, self.player.vx, self.player.vy)
    love.graphics.setColor(COLORS.accent)
    love.graphics.printf(status, width - 540, 33, 520, "right")
end

function PlatformingEngine:drawFooter(width, height)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, 1)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf("A/D MOVE   SHIFT SPRINT   Z/SPACE JUMP   X WHIP   W/S CLIMB & LOOK/CROUCH   B COLLIDER   R RESET   ESC MENU",
        12, height - 28, width - 24, "center")
end

function PlatformingEngine:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(COLORS.background)
    self:drawHeader(width)
    self:drawWorld(self:getViewport())
    self:drawFooter(width, height)
end

return PlatformingEngine
