local EntitySpriteData = require("src.world.original_entity_sprites")
local Depth = require("src.render.classic_depth")
local MeleeMask = require("src.platform.melee_mask")
local Tiles = require("src.platform.tiles.types")
local ItemDefinitions = require("src.platform.item_definitions")
local Objects = require("src.platform.objects")

local MinesRenderer = {}
MinesRenderer.__index = MinesRenderer

function MinesRenderer.new()
    return setmetatable({ images = {}, backdropImages = {}, entitySprites = {},
        caveTopQuads = {} }, MinesRenderer)
end

function MinesRenderer:loadAssets()
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
    self.itemAnimationSprites = {}
    local Assets = require("src.platform.object_assets")
    for kind, definition in pairs(ItemDefinitions) do
        if definition.sprite then
            local spec = definition.sprite
            self.entitySprites[kind] = { image = Assets.image(spec.group, spec.name),
                metadata = { originX = spec.originX or spec.size / 2, originY = spec.originY or spec.size / 2,
                    width = spec.size, height = spec.size } }
        end
        if definition.leftSprite then
            local spec = definition.leftSprite
            local metadata = self.entitySprites[kind].metadata
            self.entitySprites[kind .. "_left"] = { image = Assets.image(spec.group, spec.name),
                metadata = { originX = metadata.originX, originY = spec.originY or metadata.originY,
                    width = metadata.width, height = metadata.height } }
        end
    end
    for _, definition in pairs(ItemDefinitions) do
        if definition.loadRenderAssets then definition.loadRenderAssets(self) end
    end
    self.meleeSprites = {}
    for _, sprite in ipairs({ "sMachetePreL", "sMachetePreR", "sMattockPreL",
        "sMattockPreR", "sSlashLeft", "sSlashRight", "sMattockHitL", "sMattockHitR" }) do
        local frames = {}
        local count = sprite:find("Pre") and 1 or 3
        for frame = 0, count - 1 do
            local image = love.graphics.newImage("original-game-reference/source/extracted/spelunky/"
                .. "Sprites/Items/Weapons/" .. sprite .. ".images/image " .. frame .. ".png")
            image:setFilter("nearest", "nearest")
            frames[#frames + 1] = image
        end
        self.meleeSprites[sprite] = frames
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

function MinesRenderer:drawBackdrops(level)
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
function MinesRenderer:submitLevel(queue, level, options)
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

function MinesRenderer:drawTile(tile, x, y)
    local definition = assert(Tiles[tile.kind], "Unknown tile: " .. tostring(tile.kind))
    local image = definition.image
    if type(image) == "function" then image = image(tile) end
    if image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.images[image], x, y)
    end
end

function MinesRenderer:drawEntity(entity, tick)
    love.graphics.setColor(1, 1, 1, 1)
    local fallbackX = entity.x * 16
    local fallbackY = entity.y * 16
    local definition = Objects[entity.kind]
    local spriteKey = definition and definition.spriteKey and definition.spriteKey(entity) or entity.kind

    local sprite = self.entitySprites[spriteKey]
    if sprite then
        local metadata = sprite.metadata
        local x = entity.x * 16 - metadata.originX
        local y = entity.y * 16 - metadata.originY
        love.graphics.setColor(1, 1, 1,
            definition and definition.alpha and definition.alpha(entity) or 1)
        local image = definition and definition.entityImage and definition.entityImage(entity, tick) or sprite.image
        love.graphics.draw(image, math.floor(x), math.floor(y))
        love.graphics.setColor(1, 1, 1, 1)
    elseif definition and definition.draw then
        definition.draw(self, entity)
    elseif entity.kind ~= "hidden_sapphire"
        and entity.kind ~= "hidden_emerald"
        and entity.kind ~= "hidden_ruby"
        and entity.kind ~= "hidden_item" then
        love.graphics.setColor(0.92, 0.72, 0.18, 0.85)
        love.graphics.rectangle("fill", fallbackX + 5, fallbackY + 5, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function MinesRenderer:drawItem(item, facing)
    if item.visible == false then return end
    local kind = item.kind
    local definition = item.definition or ItemDefinitions[kind]
    if self.itemAnimationSprites and definition then
        if definition.drawItem then
            definition.drawItem(self, item, facing)
            return
        end
        local image = definition.itemImage and definition.itemImage(self, item, facing)
        if image then
            local metadata = self.entitySprites[kind].metadata
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, math.floor(item.x - metadata.originX),
                math.floor(item.y - metadata.originY))
            return
        end
    end
    if (facing or item.facing or 1) < 0 and self.entitySprites[kind .. "_left"] then
        kind = kind .. "_left"
    end
    self:drawEntity({ kind = kind, x = item.x / 16, y = item.y / 16,
        properties = item.properties })
end

function MinesRenderer:drawMeleeSwing(player, item)
    local phase = player:getMeleePhase()
    if not phase or not item then return end
    local name, frame, x, y = MeleeMask.pose(player, item.definition.melee,
        phase, player.meleeStrikeAge)
    if not name then return end
    local image = self.meleeSprites[name][frame + 1]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y)
end

return MinesRenderer
