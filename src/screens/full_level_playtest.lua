local MinesGenerator = require("src.world.mines_generator")
local ClassicAreaGenerator = require("src.world.classic_area_generator")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Enemy = require("src.platform.enemy")
local Item = require("src.platform.item")

local FullLevelPlaytest = {}
FullLevelPlaytest.__index = FullLevelPlaytest

local STEP = 1 / Player.TICK_RATE
local HEADER_HEIGHT = 64
local FOOTER_HEIGHT = 40

local LEVEL_TYPES = {
    { label = "MINES", key = "mines", depths = 4, offset = 0 },
    { label = "JUNGLE", key = "jungle", depths = 4, offset = 4 },
    { label = "ICE CAVES", key = "ice", depths = 4, offset = 8 },
    { label = "TEMPLE", key = "temple", depths = 3, offset = 12 },
    { label = "OLMEC", key = "olmec", depths = 1, offset = 15 },
}

local DYNAMIC_ENEMIES = {
    snake = true,
    bat = true,
    spider = true,
}

local COLORS = {
    background = { 0.035, 0.031, 0.027 },
    panel = { 0.075, 0.064, 0.052 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.72, 0.18, 0.10 },
    danger = { 0.95, 0.28, 0.16 },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function FullLevelPlaytest.new(app)
    return setmetatable({
        app = app,
        renderer = nil,
        areaIndex = 1,
        levelNumber = 1,
        seed = nil,
        level = nil,
        world = nil,
        player = nil,
        enemies = {},
        items = {},
        heldItem = nil,
        dynamicEntities = {},
        spikeEntities = {},
        accumulator = 0,
        cameraX = 0,
        cameraY = 0,
        debugCollision = false,
        deathTimer = 0,
        exitReady = false,
        hitSound = nil,
        throwSound = nil,
        actionHeld = false,
    }, FullLevelPlaytest)
end

function FullLevelPlaytest:loadAssets()
    self.renderer = self.renderer or self.app.screens.world_generation
    self.renderer:loadAssets()
    Enemy.loadAssets()
    self.hitSound = self.hitSound
        or love.audio.newSource("original-game-reference/sound/hit.wav", "static")
    self.throwSound = self.throwSound
        or love.audio.newSource("original-game-reference/sound/throw.wav", "static")
end

function FullLevelPlaytest:selectedArea()
    return LEVEL_TYPES[self.areaIndex]
end

function FullLevelPlaytest:generateLevel(seed)
    self.seed = seed
    local area = self:selectedArea()
    if area.key == "mines" then
        self.level = MinesGenerator.generate(seed, { levelNumber = self.levelNumber })
    else
        self.level = ClassicAreaGenerator.generate(area.key, seed, { levelNumber = self.levelNumber })
    end
    self:buildSimulation()
end

function FullLevelPlaytest:buildSimulation()
    self.world = GeneratedWorld.fromLevel(self.level)
    local spawnX, spawnY = GeneratedWorld.spawnPoint(self.level)
    self.player = Player.new(spawnX, spawnY)
    self.player.state = Player.STATES.standing
    self.player.spriteName = "sStandLeft"
    self.player:loadAssets()

    self.enemies = {}
    self.items = {}
    self.heldItem = nil
    self.dynamicEntities = {}
    self.spikeEntities = {}
    for index, entity in ipairs(self.level.entities) do
        if DYNAMIC_ENEMIES[entity.kind] then
            local enemy = Enemy.new(entity.kind, entity.x * 16 + 8, entity.y * 16 + 16, {
                seed = self.seed + index * 97,
                hanging = entity.kind ~= "snake",
            })
            self.enemies[#self.enemies + 1] = enemy
            self.dynamicEntities[entity] = true
        elseif Item.isCarryable(entity.kind) then
            local sprite = self.renderer.entitySprites[entity.kind]
            local item = Item.new(entity, sprite and sprite.metadata)
            self.items[#self.items + 1] = item
            self.dynamicEntities[entity] = true
        elseif entity.kind == "spikes" then
            self.spikeEntities[#self.spikeEntities + 1] = entity
        end
    end

    self.accumulator = 0
    self.cameraX = clamp(spawnX - 160, 0, self.world.width * 16)
    self.cameraY = clamp(spawnY - 120, 0, self.world.height * 16)
    self.deathTimer = 0
    self.exitReady = false
    self.actionHeld = false
end

function FullLevelPlaytest:enter()
    self:loadAssets()
    if not self.level then
        self.seed = os.time() % 2147483646 + 1
        self:generateLevel(self.seed)
    else
        self:buildSimulation()
    end
end

function FullLevelPlaytest:getInput()
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

function FullLevelPlaytest:isNearExit()
    if not self.level.exit or not self.player then return false end
    local exitX = self.level.exit.x * 16 + 8
    local exitY = self.level.exit.y * 16 + 8
    return math.abs(self.player.x - exitX) <= 11 and math.abs(self.player.y - exitY) <= 15
end

function FullLevelPlaytest:advanceLevel()
    local area = self:selectedArea()
    if self.levelNumber < area.depths then
        self.levelNumber = self.levelNumber + 1
    elseif self.areaIndex < #LEVEL_TYPES then
        self.areaIndex = self.areaIndex + 1
        self.levelNumber = 1
    else
        self.areaIndex = 1
        self.levelNumber = 1
        self.seed = (self.seed % 2147483646) + 1
    end
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:checkSpikes(previousY)
    if self.player.invincibleTimer > 0 then return end
    local halfWidth = self.player:getCollisionHalfWidth()
    local _, bottomOffset = self.player:getVerticalBounds()
    local bottom = self.player.y + bottomOffset
    local previousBottom = previousY + bottomOffset
    for _, spike in ipairs(self.spikeEntities) do
        local left = spike.x * 16
        local top = spike.y * 16 + 4
        if self.player.x + halfWidth > left and self.player.x - halfWidth < left + 16
            and bottom >= top and previousBottom <= top + 5 and self.player.vy >= 0 then
            self.player:hurt(left + 8)
            return
        end
    end
end

function FullLevelPlaytest:checkWhip()
    local left, top, right, bottom = self.player:getWhipHitbox()
    if not left then return end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and self.player:whipCanHit(enemy)
            and enemy:overlapsRectangle(left, top, right, bottom) then
            self.player:markWhipHit(enemy)
            enemy:damage(1)
            if self.hitSound then self.hitSound:clone():play() end
        end
    end
end

function FullLevelPlaytest:pickupNearestItem()
    local left, top = self.player.x - 8, self.player.y
    local right, bottom = self.player.x + 8, self.player.y + 8
    local nearest, nearestDistance
    for _, item in ipairs(self.items) do
        if not item.held and item:overlapsRectangle(left, top, right, bottom)
            and not self.world:solidAtPoint(item.x, item.y) then
            local dx, dy = item.x - self.player.x, item.y - self.player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = item, distance
            end
        end
    end
    if nearest and nearest:pickup(self.player) then
        self.heldItem = nearest
        return true
    end
    return false
end

function FullLevelPlaytest:useHeldItem(input)
    local item = self.heldItem
    if not item then return false end
    if item.weapon and not input.down then
        -- Weapon-specific fire and swing behavior is separate from throwing.
        return false
    end
    if item.weapon then item:dropWeapon(self.player)
    else item:throw(self.player, input) end
    self.heldItem = nil
    if self.throwSound then self.throwSound:clone():play() end
    return true
end

function FullLevelPlaytest:dropHeldItemFromHurt()
    if not self.heldItem then return end
    self.heldItem:dropFromHurt(self.player)
    self.heldItem = nil
end

function FullLevelPlaytest:simulationStep()
    if self.player:isDead() then
        self.deathTimer = self.deathTimer - 1
        if self.deathTimer <= 0 then self:buildSimulation() end
        return
    end

    local input = self:getInput()
    local actionPressed = input.attack and not self.actionHeld
    self.actionHeld = input.attack
    if self.heldItem then input.suppressWhip = true end
    local previousY = self.player.y
    local previousHealth = self.player.health
    self.player:step(self.world, input)
    if actionPressed then
        if self.heldItem then
            self:useHeldItem(input)
        elseif input.down and self.player.state == Player.STATES.ducking then
            self:pickupNearestItem()
        end
    end
    self:checkWhip()
    self:checkSpikes(previousY)

    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            enemy:step(self.world, self.player)
            enemy:resolvePlayerContact(self.player, previousY)
        end
    end

    if self.player.health < previousHealth then self:dropHeldItemFromHurt() end
    for _, item in ipairs(self.items) do item:update(self.world, self.player) end

    if self.player:isDead() then self.deathTimer = 75 end
    if self.player.y > self.world.height * self.world.tileSize + 32 then
        self:buildSimulation()
        return
    end
    self.exitReady = self:isNearExit()
end

function FullLevelPlaytest:update(dt)
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        self:simulationStep()
        self.accumulator = self.accumulator - STEP
    end
end

function FullLevelPlaytest:changeArea(direction)
    self.areaIndex = ((self.areaIndex - 1 + direction) % #LEVEL_TYPES) + 1
    self.levelNumber = 1
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:changeDepth(direction)
    local depths = self:selectedArea().depths
    self.levelNumber = ((self.levelNumber - 1 + direction) % depths) + 1
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:keypressed(key, _, isRepeat)
    if isRepeat then return end
    if (key == "up" or key == "w") and self:isNearExit() then
        self:advanceLevel()
    elseif key == "r" then
        self:generateLevel(self.seed)
    elseif key == "n" then
        self:generateLevel((self.seed % 2147483646) + 1)
    elseif key == "[" or key == "q" then
        self:changeArea(-1)
    elseif key == "]" or key == "e" then
        self:changeArea(1)
    elseif key == "-" then
        self:changeDepth(-1)
    elseif key == "=" then
        self:changeDepth(1)
    elseif key == "b" then
        self.debugCollision = not self.debugCollision
    end
end

function FullLevelPlaytest:getViewport()
    local width, height = love.graphics.getDimensions()
    local availableHeight = height - HEADER_HEIGHT - FOOTER_HEIGHT
    -- Keep the generated art on an integer pixel grid while presenting a
    -- camera-sized slice of the level instead of shrinking the whole map.
    local scale = math.max(1, math.floor(math.min(width / 480, availableHeight / 320)))
    return {
        x = 0,
        y = HEADER_HEIGHT,
        width = width,
        height = availableHeight,
        scale = scale,
        logicalWidth = math.floor(width / scale),
        logicalHeight = math.floor(availableHeight / scale),
    }
end

function FullLevelPlaytest:updateCamera(viewport)
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local targetX = self.player.x - viewport.logicalWidth / 2
    local targetY = self.player.y - viewport.logicalHeight / 2
    self.cameraX = math.floor(clamp(targetX, 0, math.max(0, worldWidth - viewport.logicalWidth)))
    self.cameraY = math.floor(clamp(targetY, 0, math.max(0, worldHeight - viewport.logicalHeight)))
end

function FullLevelPlaytest:drawBackground()
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local background = (self.level.area == "temple" or self.level.area == "olmec")
        and self.renderer.images.bg_temple or self.renderer.images.bg_cave
    local quad = love.graphics.newQuad(0, 0, worldWidth, worldHeight, background:getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(background, quad, 0, 0)
end

function FullLevelPlaytest:drawDebugBounds(entity, color)
    local halfWidth = entity:getCollisionHalfWidth()
    local topOffset, bottomOffset = entity:getVerticalBounds()
    love.graphics.setColor(color)
    love.graphics.setLineWidth(0.5)
    love.graphics.rectangle("line", entity.x - halfWidth, entity.y + topOffset,
        halfWidth * 2, bottomOffset - topOffset)
end

function FullLevelPlaytest:drawWorld(viewport)
    self:updateCamera(viewport)
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)
    love.graphics.translate(-self.cameraX, -self.cameraY)

    self:drawBackground()
    -- GameMaker draws loose oItem instances (depth 101) before oSolid
    -- terrain (depth 100), so tile foreground pixels naturally cover them.
    for _, entity in ipairs(self.level.entities) do
        if entity.kind ~= "player" and not self.dynamicEntities[entity]
            and Item.rendersBehindTerrain(entity.kind) then
            self.renderer:drawEntity(entity)
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held then
            self.renderer:drawEntity({
                kind = item.kind,
                x = item.x / 16,
                y = item.y / 16,
                properties = item.properties,
            })
        end
    end
    for y = 0, self.level.height - 1 do
        for x = 0, self.level.width - 1 do
            self.renderer:drawTile(self.level.tiles[y + 1][x + 1], x * 16, y * 16)
        end
    end
    for _, decoration in ipairs(self.level.decorations or {}) do
        if decoration.y >= 0 then
            love.graphics.draw(self.renderer.images.bg_cave_top,
                self.renderer.caveTopQuads[decoration.variant], decoration.x * 16, decoration.y * 16)
        end
    end
    for _, entity in ipairs(self.level.entities) do
        if entity.kind ~= "player" and not self.dynamicEntities[entity]
            and not Item.rendersBehindTerrain(entity.kind) then
            self.renderer:drawEntity(entity)
        end
    end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then enemy:draw() end
    end

    if not (self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0) then
        self.player:draw()
    end
    if self.heldItem then
        self.renderer:drawEntity({
            kind = self.heldItem.kind,
            x = self.heldItem.x / 16,
            y = self.heldItem.y / 16,
            properties = self.heldItem.properties,
        })
    end
    if self.debugCollision then
        self:drawDebugBounds(self.player, { 0.2, 1, 0.35, 0.9 })
        for _, enemy in ipairs(self.enemies) do
            if enemy.alive then self:drawDebugBounds(enemy, { 1, 0.25, 0.2, 0.9 }) end
        end
        for _, item in ipairs(self.items) do
            self:drawDebugBounds(item, { 0.25, 0.65, 1, 0.9 })
        end
        local left, top, right, bottom = self.player:getWhipHitbox()
        if left then
            love.graphics.setColor(0.95, 0.75, 0.18, 0.9)
            love.graphics.rectangle("line", left, top, right - left, bottom - top)
        end
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function FullLevelPlaytest:levelLabel()
    local area = self:selectedArea()
    local absolute = area.offset + self.levelNumber
    if area.key == "olmec" then return "4-4" end
    return (math.floor((absolute - 1) / 4) + 1) .. "-" .. (((absolute - 1) % 4) + 1)
end

function FullLevelPlaytest:draw()
    local width, height = love.graphics.getDimensions()
    local viewport = self:getViewport()
    love.graphics.clear(COLORS.background)
    self:drawWorld(viewport)

    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, width, HEADER_HEIGHT)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.line(0, HEADER_HEIGHT - 1, width, HEADER_HEIGHT - 1)
    love.graphics.line(0, height - FOOTER_HEIGHT, width, height - FOOTER_HEIGHT)

    love.graphics.setFont(self.app.fonts.menu)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("FULL LEVEL PLAYTEST", 18, 10)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print(self:selectedArea().label .. "  " .. self:levelLabel()
        .. "    SEED " .. self.seed, 20, 42)

    love.graphics.setColor(self.player.health > 0 and COLORS.danger or COLORS.muted)
    love.graphics.printf("LIFE " .. math.max(0, self.player.health), 0, 20, width - 20, "right")
    if self.heldItem then
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("HOLD " .. self.heldItem.kind:gsub("_", " "):upper(),
            0, 42, width - 20, "right")
    end

    if self.exitReady then
        love.graphics.setColor(0.04, 0.03, 0.02, 0.88)
        love.graphics.rectangle("fill", width / 2 - 155, HEADER_HEIGHT + 18, 310, 34, 4, 4)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("PRESS UP TO ENTER THE EXIT", width / 2 - 150,
            HEADER_HEIGHT + 26, 300, "center")
    elseif self.player:isDead() then
        love.graphics.setColor(COLORS.danger)
        love.graphics.printf("YOU DIED", 0, HEADER_HEIGHT + 24, width, "center")
    end

    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(
        "A/D MOVE   SHIFT SPRINT   Z/SPACE JUMP   X WHIP/THROW   DOWN+X PICK UP/DROP   W/S CLIMB   R RESET   N SEED   [ ] AREA   B COLLIDERS   ESC BACK",
        12, height - 27, width - 24, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return FullLevelPlaytest
