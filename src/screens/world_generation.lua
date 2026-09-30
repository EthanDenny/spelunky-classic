local MinesGenerator = require("src.world.mines_generator")
local EntitySpriteData = require("src.world.original_entity_sprites")
local SegmentedSelector = require("src.ui.segmented_selector")

local WorldGeneration = {}
WorldGeneration.__index = WorldGeneration

local LEVEL_TYPES = {
    { label = "Mines", key = "mines", depthCount = 4, implemented = true },
}

local TILE_IMAGES = {
    brick = "brick",
    brick_alt = "brick_alt",
    brick_gold = "brick_gold",
    brick_gold_big = "brick_gold_big",
    brick_down = "brick_down",
    cave_up = "cave_up",
    cave_up2 = "cave_up2",
}

function WorldGeneration.new(app)
    return setmetatable({
        app = app,
        selector = SegmentedSelector.new(LEVEL_TYPES),
        levelNumber = 1,
        seed = nil,
        level = nil,
        images = {},
        entitySprites = {},
        caveTopQuads = {},
        showRoomPath = false,
    }, WorldGeneration)
end

function WorldGeneration:loadAssets()
    if self.images.brick then
        return
    end

    local directory = "assets/original/mines/"
    local names = {
        "altar_left",
        "altar_right",
        "bg_cave",
        "bg_cave_top",
        "block",
        "brick",
        "brick_alt",
        "brick_down",
        "brick_gold",
        "brick_gold_big",
        "cave_smooth",
        "cave_up",
        "cave_up2",
        "entrance",
        "exit",
        "gold_idol",
        "ladder",
        "ladder_top",
        "ruby_big",
        "snake",
        "spikes",
    }

    for _, name in ipairs(names) do
        self.images[name] = love.graphics.newImage(directory .. name .. ".png")
        self.images[name]:setFilter("nearest", "nearest")
    end

    for key, metadata in pairs(EntitySpriteData) do
        local image = love.graphics.newImage("assets/original/entities/" .. metadata.image .. ".png")
        image:setFilter("nearest", "nearest")
        self.entitySprites[key] = { image = image, metadata = metadata }
    end

    self.images.bg_cave:setWrap("repeat", "repeat")
    self.caveTopQuads = {
        love.graphics.newQuad(0, 0, 16, 16, self.images.bg_cave_top:getDimensions()),
        love.graphics.newQuad(16, 0, 16, 16, self.images.bg_cave_top:getDimensions()),
    }
end

function WorldGeneration:enter()
    self:loadAssets()
    if not self.level then
        self.seed = os.time() % 2147483646 + 1
        self:generate(self.seed)
    end
end

function WorldGeneration:generate(seed)
    self.seed = seed
    self.level = MinesGenerator.generate(seed, { levelNumber = self.levelNumber })
    self.level.area = "mines"
    if self.app.playtestLog then
        self.app.playtestLog:generatedLevel("world_generation", self.level, self.levelNumber)
    end
end

function WorldGeneration:regenerate()
    local nextSeed = (self.seed % 2147483646) + 1
    self:generate(nextSeed)
end

function WorldGeneration:changeLevelNumber(direction)
    local depthCount = self.selector:getSelected().depthCount
    self.levelNumber = ((self.levelNumber - 1 + direction) % depthCount) + 1
    self:generate(self.seed)
end

function WorldGeneration:keypressed(key, _, isRepeat)
    if isRepeat then
        return
    end

    if key == "up" or key == "w" then
        if self.selector:getSelected().implemented then
            self:changeLevelNumber(1)
        end
    elseif key == "down" or key == "s" then
        if self.selector:getSelected().implemented then
            self:changeLevelNumber(-1)
        end
    elseif key == "r" or key == "return" or key == "kpenter" or key == "space" then
        if self.selector:getSelected().implemented then
            self:regenerate()
        end
    elseif key == "tab" then
        self.showRoomPath = not self.showRoomPath
    end
end

function WorldGeneration:getLayout()
    local width, height = love.graphics.getDimensions()
    local margin = 8
    local sidebarWidth = 300
    local gap = 16
    return {
        sidebar = { x = margin, y = margin, width = sidebarWidth, height = height - margin * 2 },
        selector = { x = 24, y = 62, width = sidebarWidth - 32, height = 220 },
        viewport = {
            x = margin + sidebarWidth + gap,
            y = margin,
            width = width - sidebarWidth - gap - margin * 2,
            height = height - margin * 2,
        },
        generate = { x = 24, y = 336, width = sidebarWidth - 32, height = 32 },
        depthDown = { x = 24, y = 294, width = 32, height = 30 },
        depthUp = { x = 136, y = 294, width = 32, height = 30 },
        info = { x = 24, y = 392, width = sidebarWidth - 32 },
    }
end

local function contains(bounds, x, y)
    return x >= bounds.x and x <= bounds.x + bounds.width
        and y >= bounds.y and y <= bounds.y + bounds.height
end

function WorldGeneration:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local layout = self:getLayout()
    if contains(layout.generate, x, y) then
        self:regenerate()
    elseif contains(layout.depthDown, x, y) then
        self:changeLevelNumber(-1)
    elseif contains(layout.depthUp, x, y) then
        self:changeLevelNumber(1)
    end
end

function WorldGeneration:drawButton(bounds, label, active)
    love.graphics.setColor(active and 0.50 or 0.12, active and 0.17 or 0.10, 0.08)
    love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height, 3, 3)
    love.graphics.setColor(active and 1 or 0.42, active and 0.91 or 0.38, active and 0.70 or 0.33)
    love.graphics.printf(label, bounds.x, bounds.y + 6, bounds.width, "center")
end

function WorldGeneration:drawTile(tile, x, y)
    if tile.kind == "brick" then
        local imageName = TILE_IMAGES[tile.style] or "brick"
        love.graphics.draw(self.images[imageName], x, y)
    elseif tile.kind == "solid" then
        local imageName = TILE_IMAGES[tile.style] or TILE_IMAGES[tile.baseStyle] or "block"
        love.graphics.draw(self.images[imageName], x, y)
    elseif tile.kind == "block" or tile.kind == "push_block" then
        love.graphics.draw(self.images.block, x, y)
    elseif tile.kind == "smooth_brick" then
        love.graphics.draw(self.images.cave_smooth, x, y)
    elseif tile.kind == "ladder" then
        love.graphics.draw(self.images.ladder, x, y)
    elseif tile.kind == "ladder_top" then
        love.graphics.draw(self.images.ladder_top, x, y)
    end
end

function WorldGeneration:drawEntity(entity)
    local fallbackX = entity.x * 16
    local fallbackY = entity.y * 16
    local spriteKey = entity.kind
    if entity.kind == "shop_sign" then
        spriteKey = "shop_sign_" .. string.lower(entity.properties.shopType or "general")
    end

    local sprite = self.entitySprites[spriteKey]
    if sprite then
        local metadata = sprite.metadata
        local x = entity.x * 16 - metadata.originX
        local y = entity.y * 16 - metadata.originY
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite.image, math.floor(x), math.floor(y))
    elseif entity.kind == "sacrifice_altar" then
        love.graphics.draw(self.entitySprites.sac_altar_left.image, entity.x * 16, entity.y * 16)
        love.graphics.draw(self.entitySprites.sac_altar_right.image, (entity.x + 1) * 16, entity.y * 16)
    elseif entity.kind ~= "hidden_sapphire"
        and entity.kind ~= "hidden_emerald"
        and entity.kind ~= "hidden_ruby"
        and entity.kind ~= "hidden_item" then
        love.graphics.setColor(0.92, 0.72, 0.18, 0.85)
        love.graphics.rectangle("fill", fallbackX + 5, fallbackY + 5, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function WorldGeneration:drawRoomPath()
    local pathColors = {
        [0] = { 0.15, 0.13, 0.11, 0.10 },
        [1] = { 0.20, 0.68, 0.34, 0.22 },
        [2] = { 0.20, 0.68, 0.34, 0.22 },
        [3] = { 0.20, 0.68, 0.34, 0.22 },
        [4] = { 0.82, 0.53, 0.16, 0.28 },
        [5] = { 0.82, 0.53, 0.16, 0.28 },
        [7] = { 0.55, 0.25, 0.62, 0.28 },
        [8] = { 0.55, 0.25, 0.62, 0.28 },
        [9] = { 0.55, 0.25, 0.62, 0.28 },
    }

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setLineWidth(1)
    for roomY = 0, 3 do
        for roomX = 0, 3 do
            local value = self.level.roomPath[roomY + 1][roomX + 1]
            local origin = self.level.roomOrigins and self.level.roomOrigins[roomY + 1][roomX + 1]
            local x = (origin and origin.x or (1 + roomX * 10)) * 16
            local y = (origin and origin.y or (1 + roomY * 8)) * 16
            love.graphics.setColor(pathColors[value] or pathColors[0])
            love.graphics.rectangle("fill", x, y, 160, 128)
            love.graphics.setColor(1, 0.94, 0.78, 0.42)
            love.graphics.rectangle("line", x, y, 160, 128)
            love.graphics.print(tostring(value), x + 5, y + 3)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldGeneration:drawLevel(viewport)
    local worldWidth = self.level.width * self.level.tileSize
    local worldHeight = self.level.height * self.level.tileSize
    local fitScale = math.min(viewport.width / worldWidth, viewport.height / worldHeight)
    local scale = fitScale >= 1 and math.floor(fitScale) or fitScale
    local drawWidth = worldWidth * scale
    local drawHeight = worldHeight * scale
    local drawX = math.floor(viewport.x + (viewport.width - drawWidth) / 2)
    local drawY = math.floor(viewport.y + (viewport.height - drawHeight) / 2)

    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(drawX, drawY)
    love.graphics.scale(scale, scale)

    love.graphics.setColor(1, 1, 1, 1)
    local background = self.images.bg_cave
    local backgroundQuad = love.graphics.newQuad(0, 0, worldWidth, worldHeight,
        background:getDimensions())
    love.graphics.draw(background, backgroundQuad, 0, 0)

    for y = 0, self.level.height - 1 do
        for x = 0, self.level.width - 1 do
            self:drawTile(self.level.tiles[y + 1][x + 1], x * 16, y * 16)
        end
    end

    for _, decoration in ipairs(self.level.decorations) do
        if decoration.y >= 0 then
            love.graphics.draw(self.images.bg_cave_top, self.caveTopQuads[decoration.variant],
                decoration.x * 16, decoration.y * 16)
        end
    end

    for _, entity in ipairs(self.level.entities) do
        self:drawEntity(entity)
    end

    if self.showRoomPath then
        self:drawRoomPath()
    end

    love.graphics.pop()
    love.graphics.setScissor()

    love.graphics.setColor(0.30, 0.22, 0.14)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", drawX, drawY, drawWidth, drawHeight)
end

function WorldGeneration:draw()
    local width, height = love.graphics.getDimensions()
    local layout = self:getLayout()
    love.graphics.clear(0.045, 0.04, 0.035)
    love.graphics.setColor(0.065, 0.057, 0.048)
    love.graphics.rectangle("fill", layout.sidebar.x, layout.sidebar.y,
        layout.sidebar.width, layout.sidebar.height, 5, 5)
    love.graphics.setFont(self.app.fonts.menu)
    love.graphics.setColor(0.92, 0.86, 0.72)
    love.graphics.printf("WORLD GENERATION", layout.sidebar.x + 8, 24,
        layout.sidebar.width - 16, "center")

    self.selector:draw(layout.selector.x, layout.selector.y, layout.selector.width,
        layout.selector.height, self.app.fonts.small, true)

    love.graphics.setFont(self.app.fonts.small)
    self:drawButton(layout.depthDown, "<", true)
    self:drawButton(layout.depthUp, ">", true)
    love.graphics.setColor(0.86, 0.80, 0.67)
    local depthLabel = "1-" .. self.levelNumber
    love.graphics.printf(depthLabel,
        58, layout.depthDown.y + 7, 76, "center")
    self:drawButton(layout.generate, "GENERATE", true)

    love.graphics.setColor(0.56, 0.50, 0.40)
    local features = {}
    if self.level.hasSnakePit then features[#features + 1] = "SNAKE PIT" end
    if self.level.hasShop then features[#features + 1] = "SHOP" end
    if self.level.hasIdol then features[#features + 1] = "IDOL" end
    local featureText = #features > 0 and table.concat(features, " · ") or "STANDARD"
    love.graphics.printf("SEED " .. self.seed, layout.info.x, layout.info.y,
        layout.info.width, "center")
    love.graphics.setColor(0.72, 0.64, 0.50)
    love.graphics.printf(featureText, layout.info.x, layout.info.y + 30,
        layout.info.width, "center")
    self:drawLevel(layout.viewport)

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(0.56, 0.50, 0.40)
    love.graphics.printf("UP/DOWN  DEPTH\nR  GENERATE\nTAB  ROOM PATH\nESC  BACK",
        layout.sidebar.x + 16, height - 126, layout.sidebar.width - 32, "left")
end

return WorldGeneration
