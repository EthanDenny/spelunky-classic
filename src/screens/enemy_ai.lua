local Enemy = require("src.platform.enemy")
local Player = require("src.platform.player")
local World = require("src.platform.world")

local EnemyAI = {}
EnemyAI.__index = EnemyAI

local HEADER_HEIGHT = 96
local FOOTER_HEIGHT = 48
local STEP = 1 / Enemy.TICK_RATE

local COLORS = {
    background = { 0.035, 0.031, 0.027 },
    panel = { 0.075, 0.064, 0.052 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.55, 0.25, 0.62 },
    alert = { 0.95, 0.28, 0.16 },
    sense = { 0.85, 0.62, 0.20, 0.42 },
}

local STATE_COLORS = {
    IDLE = { 0.62, 0.56, 0.45 },
    WALK = { 0.40, 0.76, 0.42 },
    HANG = { 0.42, 0.62, 0.82 },
    ATTACK = { 0.95, 0.28, 0.16 },
    RECOVER = { 0.88, 0.65, 0.22 },
    BOUNCE = { 0.72, 0.34, 0.76 },
}

local function makeCourse()
    local world = World.new(40, 24, 16)
    world:fill("solid", 0, 22, 40, 2)
    world:fill("solid", 0, 0, 40, 1)
    world:fill("solid", 18, 15, 5, 1)
    world:fill("solid", 27, 15, 5, 1)
    world:fill("solid", 38, 18, 1, 4)
    world.labels = {
        { x = 12 * 16 + 8, y = 21 * 16, text = "PATROL" },
        { x = 20 * 16 + 8, y = 14 * 16, text = "PROXIMITY" },
        { x = 29 * 16 + 8, y = 14 * 16, text = "AMBUSH" },
    }
    return world
end

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function EnemyAI.new(app)
    return setmetatable({
        app = app,
        world = nil,
        player = nil,
        enemies = {},
        images = {},
        sounds = {},
        accumulator = 0,
        kills = 0,
        gameOverTimer = 0,
        effects = {},
        showSensors = true,
        debugCollision = false,
    }, EnemyAI)
end

function EnemyAI:loadAssets()
    if self.images.brick then return end
    self.images.brick = loadImage("assets/original/mines/brick.png")
    self.images.brickAlt = loadImage("assets/original/mines/brick_alt.png")
    self.images.brickDown = loadImage("assets/original/mines/brick_down.png")
    self.images.background = loadImage("assets/original/mines/bg_cave.png")
    self.images.background:setWrap("repeat", "repeat")
    Enemy.loadAssets()
    self.sounds.bat = love.audio.newSource("original-game-reference/sound/bat.wav", "static")
    self.sounds.hit = love.audio.newSource("original-game-reference/sound/hit.wav", "static")
    self.sounds.hurt = love.audio.newSource("original-game-reference/sound/hurt.wav", "static")
end

function EnemyAI:playSound(name)
    local source = self.sounds[name]
    if source then source:clone():play() end
end

function EnemyAI:resetArena()
    self.world = makeCourse()
    self.player = Player.new(5 * 16 + 8, 22 * 16 - 8)
    self.player.state = Player.STATES.standing
    self.player.spriteName = "sStandLeft"
    self.player.playtestLog = self.app.playtestLog
    self.player:loadAssets()
    self.enemies = {
        Enemy.new("snake", 12 * 16 + 8, 22 * 16, { facing = -1, seed = 11 }),
        Enemy.new("bat", 20 * 16 + 8, 16 * 16 + 16, { seed = 22 }),
        Enemy.new("spider", 29 * 16 + 8, 16 * 16 + 16, { seed = 33 }),
        Enemy.new("snake", 35 * 16 + 8, 22 * 16, { facing = 1, seed = 44 }),
    }
    self.accumulator = 0
    self.kills = 0
    self.gameOverTimer = 0
    self.effects = {}
    if self.app.playtestLog then self.app.playtestLog:level("enemy_ai", self) end
end

function EnemyAI:enter()
    self:loadAssets()
    self:resetArena()
end

function EnemyAI:getInput()
    return {
        left = love.keyboard.isDown("left", "a"),
        right = love.keyboard.isDown("right", "d"),
        up = love.keyboard.isDown("up", "w"),
        down = love.keyboard.isDown("down", "s"),
        jump = love.keyboard.isDown("space", "z"),
        sprint = love.keyboard.isDown("lshift", "rshift"),
        attack = love.keyboard.isDown("x", "c", "k", "lctrl", "rctrl"),
    }
end

function EnemyAI:getAttackHitbox()
    return self.player:getWhipHitbox()
end

function EnemyAI:addEffect(x, y, color)
    self.effects[#self.effects + 1] = { x = x, y = y, timer = 10, color = color }
end

function EnemyAI:updateEffects()
    for index = #self.effects, 1, -1 do
        local effect = self.effects[index]
        effect.timer = effect.timer - 1
        if effect.timer <= 0 then table.remove(self.effects, index) end
    end
end

function EnemyAI:updateAttack(input)
    local left, top, right, bottom = self:getAttackHitbox()
    if left then
        for _, enemy in ipairs(self.enemies) do
            if enemy.alive and self.player:whipCanHit(enemy)
                and enemy:overlapsRectangle(left, top, right, bottom) then
                self.player:markWhipHit(enemy)
                enemy:damage(1)
                self.kills = self.kills + 1
                self:addEffect(enemy.x, enemy.y - 8, COLORS.alert)
                self:playSound("hit")
            end
        end
    end
end

function EnemyAI:updateEnemies(previousPlayerY)
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            enemy:step(self.world, self.player)
            if enemy.justAlerted and enemy.kind == "bat" then self:playSound("bat") end
            local result = enemy:resolvePlayerContact(self.player, previousPlayerY)
            if result == "stomp" then
                self.kills = self.kills + 1
                self:addEffect(enemy.x, enemy.y - 8, COLORS.alert)
                self:playSound("hit")
            elseif result == "hurt" then
                self:addEffect(self.player.x, self.player.y - 4, COLORS.text)
                self:playSound("hurt")
            end
        end
    end
end

function EnemyAI:simulationStepBody(input)
    if self.player:isDead() then
        self.gameOverTimer = self.gameOverTimer - 1
        if self.gameOverTimer <= 0 then self:resetArena() end
        return
    end

    local previousPlayerY = self.player.y
    self.player:step(self.world, input)
    self:updateAttack(input)
    self:updateEnemies(previousPlayerY)
    self:updateEffects()
    if self.player:isDead() then self.gameOverTimer = 75 end
    if self.player.y > self.world.height * self.world.tileSize + 32 then self:resetArena() end
end

function EnemyAI:simulationStep()
    local input = self:getInput()
    local log = self.app.playtestLog
    local before = log and log.capture(self)
    if log then log:tickStart("enemy_ai", input, before) end
    self:simulationStepBody(input)
    if log then log:tick("enemy_ai", input, before, self) end
end

function EnemyAI:update(dt)
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        self:simulationStep()
        self.accumulator = self.accumulator - STEP
    end
end

function EnemyAI:keypressed(key, _, isRepeat)
    if isRepeat then return end
    if key == "r" then
        self:resetArena()
    elseif key == "v" then
        self.showSensors = not self.showSensors
    elseif key == "b" then
        self.debugCollision = not self.debugCollision
    end
end

function EnemyAI:getViewport()
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

function EnemyAI:drawSensors(enemy)
    if not self.showSensors or not enemy.alive then return end
    love.graphics.setLineWidth(0.75)
    love.graphics.setColor(COLORS.sense)
    if enemy.kind == "bat" then
        love.graphics.circle("line", enemy.x, enemy.y - 8, 90)
        love.graphics.line(enemy.x, enemy.y - 8, self.player.x, self.player.y)
    elseif enemy.kind == "spider" and enemy.state == Enemy.STATES.hang then
        love.graphics.rectangle("fill", enemy.x - 7, enemy.y, 14, 90)
    elseif enemy.kind == "snake" then
        local direction = enemy.facing
        love.graphics.line(enemy.x + direction * 7, enemy.y - 6,
            enemy.x + direction * 10, enemy.y - 6)
        love.graphics.line(enemy.x + direction * 8, enemy.y,
            enemy.x + direction * 8, enemy.y + 3)
    end
end

function EnemyAI:drawEnemyState(enemy)
    if not enemy.alive then return end
    local label = enemy.state
    local font = self.app.fonts.small
    love.graphics.setFont(font)
    local width = font:getWidth(label) * 0.5 + 6
    local x = math.floor(enemy.x - width / 2)
    local y = math.floor(enemy.y - 29)
    love.graphics.setColor(0.03, 0.025, 0.02, 0.84)
    love.graphics.rectangle("fill", x, y, width, 10, 2, 2)
    love.graphics.setColor(STATE_COLORS[label] or COLORS.text)
    love.graphics.print(label, x + 3, y - 2, 0, 0.5, 0.5)
end

function EnemyAI:drawPlayer()
    if self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0 then
        return
    end
    self.player:draw()
end

function EnemyAI:drawDebugBounds(entity, color)
    local left, top, right, bottom
    if entity == self.player then
        local halfWidth = entity:getCollisionHalfWidth()
        local topOffset, bottomOffset = entity:getVerticalBounds()
        left, top, right, bottom = entity.x - halfWidth, entity.y + topOffset,
            entity.x + halfWidth, entity.y + bottomOffset
    else
        left, top, right, bottom = entity:getBounds()
    end
    love.graphics.setColor(color)
    love.graphics.setLineWidth(0.75)
    love.graphics.rectangle("line", left, top, right - left, bottom - top)
end

function EnemyAI:drawWorld(viewport)
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
    self.world:each("solid", function(x, y)
        local image = (x * 17 + y * 31) % 7 == 0 and self.images.brickAlt or self.images.brick
        love.graphics.draw(image, x * 16, y * 16)
    end)
    self.world:each("platform", function(x, y)
        love.graphics.draw(self.images.brickDown, x * 16, y * 16)
    end)

    love.graphics.setFont(self.app.fonts.small)
    for _, label in ipairs(self.world.labels) do
        love.graphics.setColor(COLORS.muted)
        love.graphics.printf(label.text, label.x - 40, label.y, 80, "center", 0, 0.5, 0.5)
    end

    for _, enemy in ipairs(self.enemies) do self:drawSensors(enemy) end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            enemy:draw()
            self:drawEnemyState(enemy)
        end
    end
    self:drawPlayer()

    local attackLeft, attackTop, attackRight, attackBottom = self:getAttackHitbox()
    if attackLeft and self.debugCollision then
        love.graphics.setColor(0.95, 0.75, 0.18, 0.8)
        love.graphics.rectangle("line", attackLeft, attackTop,
            attackRight - attackLeft, attackBottom - attackTop)
    end
    if self.debugCollision then
        self:drawDebugBounds(self.player, { 0.2, 1, 0.35, 0.9 })
        for _, enemy in ipairs(self.enemies) do
            if enemy.alive then self:drawDebugBounds(enemy, { 1, 0.25, 0.2, 0.9 }) end
        end
    end

    for _, effect in ipairs(self.effects) do
        local radius = 2 + (10 - effect.timer) * 0.55
        love.graphics.setColor(effect.color)
        love.graphics.circle("line", effect.x, effect.y, radius)
        love.graphics.line(effect.x - radius, effect.y, effect.x + radius, effect.y)
        love.graphics.line(effect.x, effect.y - radius, effect.x, effect.y + radius)
    end
    love.graphics.pop()
    love.graphics.setScissor()
end

function EnemyAI:drawHeader(width)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, width, HEADER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, HEADER_HEIGHT - 1, width, 1)
    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("ENEMY AI", 20, 10)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print("ORIGINAL 30 Hz SENSING, STATES & CONTACT RULES", 22, 61)
    local hearts = string.rep("♥ ", self.player.health)
    love.graphics.setColor(COLORS.alert)
    love.graphics.printf("LIFE  " .. hearts, width - 350, 23, 330, "right")
    love.graphics.setColor(COLORS.accent)
    love.graphics.printf(string.format("KILLS  %d / %d", self.kills, #self.enemies),
        width - 350, 59, 330, "right")
end

function EnemyAI:drawFooter(width, height)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, 1)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(
        "A/D MOVE   SHIFT SPRINT   Z/SPACE JUMP   X WHIP   V SENSORS   B COLLIDERS   R RESET   ESC MENU",
        12, height - 30, width - 24, "center")
end

function EnemyAI:drawOverlay(width, height)
    if not self.player:isDead() and self.kills < #self.enemies then return end
    love.graphics.setColor(0.02, 0.015, 0.01, 0.76)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(self.player:isDead() and COLORS.alert or COLORS.text)
    local message = self.player:isDead() and "YOU DIED" or "ARENA CLEAR"
    love.graphics.printf(message, 0, height / 2 - 38, width, "center")
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    local detail = self.player:isDead() and "RESETTING...  •  R TO RETRY NOW" or "R TO RUN THE SIMULATION AGAIN"
    love.graphics.printf(detail, 0, height / 2 + 18, width, "center")
end

function EnemyAI:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(COLORS.background)
    self:drawHeader(width)
    self:drawWorld(self:getViewport())
    self:drawFooter(width, height)
    self:drawOverlay(width, height)
end

return EnemyAI
