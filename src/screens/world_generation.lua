local MinesLevelSelection = require("src.world.mines_level_selection")
local EntitySpriteData = require("src.world.original_entity_sprites")
local SegmentedSelector = require("src.ui.segmented_selector")
local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")

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
        subtypeSelector = SegmentedSelector.new(MinesLevelSelection.choices),
        levelNumber = 1,
        seed = nil,
        level = nil,
        images = {},
        backdropImages = {},
        entitySprites = {},
        caveTopQuads = {},
        showRoomPath = false,
        selectionError = nil,
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
    for key, sprite in pairs({ arrow = "sArrowRight", arrow_left = "sArrowLeft" }) do
        local image = love.graphics.newImage(
            "original-game-reference/source/extracted/spelunky/Sprites/Items/Weapons/"
                .. sprite .. ".images/image 0.png")
        image:setFilter("nearest", "nearest")
        self.entitySprites[key] = { image = image,
            metadata = { originX = 4, originY = 4, width = 8, height = 8 } }
    end

    local backgroundDirectory = "original-game-reference/source/extracted/spelunky/Backgrounds/"
    for kind, filename in pairs({
        kali_body = "bgKaliBody.png",
        tiki_body = "bgTiki.png",
        tiki_arms = "bgTikiArms.png",
    }) do
        local image = love.graphics.newImage(backgroundDirectory .. filename)
        image:setFilter("nearest", "nearest")
        self.backdropImages[kind] = image
    end
    self.backdropImages.kali_heads = {}
    for variant = 1, 3 do
        local path = ("original-game-reference/source/extracted/spelunky/"
            .. "Sprites/Traps/sKaliHead%d.images/image 0.png"):format(variant)
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        self.backdropImages.kali_heads[variant] = image
    end
    self.tikiArmQuads = { right = {}, left = {} }
    for variant = 0, 2 do
        self.tikiArmQuads.right[variant] = love.graphics.newQuad(
            variant * 16, 0, 16, 16, self.backdropImages.tiki_arms:getDimensions())
        self.tikiArmQuads.left[variant] = love.graphics.newQuad(
            variant * 16, 16, 16, 16, self.backdropImages.tiki_arms:getDimensions())
    end

    self.images.bg_cave:setWrap("repeat", "repeat")
    self.caveTopQuads = {
        love.graphics.newQuad(0, 0, 16, 16, self.images.bg_cave_top:getDimensions()),
        love.graphics.newQuad(16, 0, 16, 16, self.images.bg_cave_top:getDimensions()),
    }
end

function WorldGeneration:drawBackdrops(level)
    love.graphics.setColor(1, 1, 1, 1)
    for _, backdrop in ipairs(level.backdrops or {}) do
        local x, y = backdrop.x * 16, backdrop.y * 16
        if backdrop.kind == "kali_body" or backdrop.kind == "tiki_body" then
            love.graphics.draw(self.backdropImages[backdrop.kind], x, y)
        elseif backdrop.kind == "tiki_arm_right" then
            love.graphics.draw(self.backdropImages.tiki_arms,
                self.tikiArmQuads.right[backdrop.variant], x, y)
        elseif backdrop.kind == "tiki_arm_left" then
            love.graphics.draw(self.backdropImages.tiki_arms,
                self.tikiArmQuads.left[backdrop.variant], x, y)
        end
    end
end

-- Shared static Mines submission used by the generator preview and live play.
-- Dynamic objects are submitted by their owning systems to the same queue.
function WorldGeneration:submitLevel(queue, level, options)
    options = options or {}
    queue:add(Depth.BACKDROP, function() self:drawBackdrops(level) end)
    for _, entity in ipairs(level.entities) do
        if not entity.destroyed and not entity.kind:match("^hidden_")
            and (not options.includeEntity or options.includeEntity(entity)) then
            local current = entity
            queue:add(Depth.entity(current.kind), function()
                if options.drawEntity then options.drawEntity(current)
                else self:drawEntity(current) end
            end)
        end
    end
    -- Group terrain by source depth; this avoids allocating a closure and a
    -- sort entry for each cell every frame while preserving stable cell order.
    for _, depth in ipairs({ 1000, 110, 100 }) do
        local targetDepth = depth
        queue:add(targetDepth, function()
            for y = 0, level.height - 1 do
                for x = 0, level.width - 1 do
                    local tile = level.tiles[y + 1][x + 1]
                    if Depth.tile(tile.kind) == targetDepth then
                        self:drawTile(tile, x * 16, y * 16)
                    end
                end
            end
        end)
    end
    queue:add(Depth.CAVE_LIP, function()
        love.graphics.setColor(1, 1, 1, 1)
        for _, decoration in ipairs(level.decorations or {}) do
            if decoration.y >= 0 then
                love.graphics.draw(self.images.bg_cave_top, self.caveTopQuads[decoration.variant],
                    decoration.x * 16, decoration.y * 16)
            end
        end
    end)
end

function WorldGeneration:enter()
    self:loadAssets()
    if not self.level then
        self.seed = os.time() % 2147483646 + 1
        self:generate(self.seed)
    end
end

function WorldGeneration:generate(seed)
    local subtype = self.subtypeSelector:getSelected().key
    local matchedSeed, level, err = MinesLevelSelection.find(seed, self.levelNumber, subtype)
    if not level then self.selectionError = err return false end
    self.seed = matchedSeed
    self.level = level
    self.level.area = "mines"
    self.level.selectedSubtype = subtype
    self.selectionError = nil
    if self.app.playtestLog then
        self.app.playtestLog:generatedLevel("world_generation", self.level, self.levelNumber)
    end
    return true
end

function WorldGeneration:regenerate()
    self:generate(MinesLevelSelection.nextSeed(self.seed))
end

function WorldGeneration:changeLevelNumber(direction)
    local depthCount = self.selector:getSelected().depthCount
    self.levelNumber = ((self.levelNumber - 1 + direction) % depthCount) + 1
    if self.levelNumber < MinesLevelSelection.requiredDepth(self.subtypeSelector:getSelected().key) then
        self.subtypeSelector:select(1)
    end
    self:generate(self.seed)
end

function WorldGeneration:changeSubtype(direction)
    local subtype = self.subtypeSelector:move(direction)
    self.levelNumber = math.max(self.levelNumber, MinesLevelSelection.requiredDepth(subtype.key))
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
    elseif key == "left" or key == "a" then
        self:changeSubtype(-1)
    elseif key == "right" or key == "d" then
        self:changeSubtype(1)
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
        selector = { x = 24, y = 62, width = sidebarWidth - 32, height = 36 },
        subtype = { x = 24, y = 124, width = sidebarWidth - 32, height = 168 },
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
    local subtypeIndex = self.subtypeSelector:indexAt(x, y)
    if subtypeIndex then
        self.subtypeSelector:select(subtypeIndex)
        self.levelNumber = math.max(self.levelNumber,
            MinesLevelSelection.requiredDepth(self.subtypeSelector:getSelected().key))
        self:generate(self.seed)
    elseif contains(layout.generate, x, y) then
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
    love.graphics.setColor(1, 1, 1, 1)
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
    love.graphics.setColor(1, 1, 1, 1)
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
    elseif entity.kind == "kali_head" then
        love.graphics.draw(self.backdropImages.kali_heads[entity.properties.variant],
            entity.x * 16 - 16, entity.y * 16 - 16)
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

    local queue = DepthQueue.new()
    self:submitLevel(queue, self.level)
    queue:draw()

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
    love.graphics.setColor(0.56, 0.50, 0.40)
    love.graphics.print("LEVEL TYPE", layout.subtype.x, layout.subtype.y - 18)
    self.subtypeSelector:draw(layout.subtype.x, layout.subtype.y, layout.subtype.width,
        layout.subtype.height, self.app.fonts.small, true)

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
    if self.level.hasAltar then features[#features + 1] = "ALTAR" end
    if self.level.dark then features[#features + 1] = "DARK" end
    local featureText = #features > 0 and table.concat(features, " · ") or "STANDARD"
    love.graphics.printf("SEED " .. self.seed, layout.info.x, layout.info.y,
        layout.info.width, "center")
    love.graphics.setColor(0.72, 0.64, 0.50)
    love.graphics.printf(featureText, layout.info.x, layout.info.y + 30,
        layout.info.width, "center")
    self:drawLevel(layout.viewport)

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(0.56, 0.50, 0.40)
    love.graphics.printf(self.selectionError or
        "UP/DOWN  DEPTH\nLEFT/RIGHT  TYPE\nR  GENERATE\nTAB  ROOM PATH\nESC  BACK",
        layout.sidebar.x + 16, height - 126, layout.sidebar.width - 32, "left")
end

return WorldGeneration
