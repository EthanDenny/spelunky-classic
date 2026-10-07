local EntityGenerator = {}
local ShopStock = require("src.platform.shop_stock")

local Tiles = require("src.platform.tiles.types")
local Objects = require("src.platform.objects")
local ItemDefinitions = require("src.platform.item_definitions")
local SpriteCollision = require("src.platform.sprite_collision")
local SpriteData = require("src.world.original_entity_sprites")

local function getTile(level, x, y)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then return nil end
    return level.tiles[y + 1][x + 1]
end

local function isSolid(level, x, y)
    local tile = getTile(level, x, y)
    if not tile then return false end
    if Tiles[tile.kind] and Tiles[tile.kind].solid then return true end
    for _, entity in ipairs(level.entities) do
        local definition = Objects[entity.kind]
        if definition and definition.worldLayer == "solid" and entity.y == y
            and x >= entity.x and x < entity.x + (definition.cellsWide or 1) then
            return true
        end
    end
    return false
end

local function addEntity(level, kind, x, y, properties)
    level.entities[#level.entities + 1] = {
        kind = kind,
        x = x,
        y = y,
        properties = properties or {},
    }
end

local function addBones(level, rng, x, y)
    -- scrTreasureGen places inert bones plus a skull seven times out of eight;
    -- only oFakeBones can rise into a skeleton when the player approaches.
    if rng:integer(1, 8) == 1 then
        addEntity(level, "fake_bones", x, y - 1)
    else
        addEntity(level, "bones", x, y - 1)
        addEntity(level, "skull", x + 0.75, y - 0.25)
    end
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function near(level, kind, x, y, radius)
    for _, entity in ipairs(level.entities) do
        if entity.kind == kind and distance(x, y, entity.x, entity.y) < radius then return true end
    end
    return false
end

local function entityAt(level, x, y, kinds)
    for _, entity in ipairs(level.entities) do
        if math.abs(entity.x - x) < 0.75 and math.abs(entity.y - y) < 0.75
            and (not kinds or kinds[entity.kind]) then
            return true
        end
    end
    return false
end

local function roomCoordinates(x, y)
    return math.floor((x - 1) / 10), math.floor((y - 1) / 8)
end

local function inStartRoom(level, x, y)
    local roomX, roomY = roomCoordinates(x, y)
    return roomX == level.startRoomX and roomY == level.startRoomY
end

local function inShop(level, x, y)
    local roomX, roomY = roomCoordinates(x, y)
    if roomX < 0 or roomX > 3 or roomY < 0 or roomY > 3 then return false end
    local value = level.roomPath[roomY + 1][roomX + 1]
    return value == 4 or value == 5
end

-- scrShopItemsGen uses the center of each 'i' cell, with a vertical offset
-- chosen for the item's sprite. The 'q' marker uses scrGenerateItem(+8,+8).
local function resolveEmbeddedEntities(level, rng)
    for _, entity in ipairs(level.entities) do
        if entity.kind == "shop_item" then
            entity.kind = entity.properties.highEnd and ShopStock.prize(rng)
                or ShopStock.choose(level, rng, entity.properties.shopType)
            local yOffset = entity.properties.highEnd and 8
                or (entity.properties.shopType == "Weapon" and entity.kind == "bomb_box" and 10)
                or assert(ItemDefinitions[entity.kind].shopOffsetY, "Missing shop item placement")
            entity.x = entity.x + 0.5
            entity.y = entity.y + yOffset / 16
            entity.properties.forSale = true
            entity.properties.inDiceHouse = entity.properties.highEnd or false
        elseif entity.kind == "treasure" then
            if rng:integer(1, 120) == 1 then entity.kind = "ruby_big"
            elseif rng:integer(1, 80) == 1 then entity.kind = "sapphire_big"
            elseif rng:integer(1, 60) == 1 then entity.kind = "emerald_big"
            else entity.kind = "gold_bars" end
        end
    end
end

local function treasureGen(level, rng, x, y, bonesBonus)
    if near(level, "entrance", x, y, 2) or near(level, "exit", x, y, 2)
        or near(level, "gold_idol", x, y, 4) then return end

    local blockedKinds = {
        chest = true, crate = true, spikes = true, entrance = true, exit = true,
        gold_bar = true, gold_bars = true, emerald_big = true, sapphire_big = true,
        ruby_big = true, damsel = true,
    }
    local open = not isSolid(level, x, y - 1) and not entityAt(level, x, y - 1, blockedKinds)
    if not open then return end

    if rng:integer(1, 100) == 1 then addEntity(level, "rock", x + 0.5, y - 0.25) return end
    if rng:integer(1, 40) == 1 then addEntity(level, "jar", x + 0.5, y - 0.375) return end

    local alcove = isSolid(level, x, y - 2)
        and (isSolid(level, x - 1, y - 1) or isSolid(level, x + 1, y - 1))
    local tunnel = isSolid(level, x - 1, y - 1) and isSolid(level, x + 1, y - 1)
    local absoluteLevel = level.absoluteLevel or level.levelNumber
    bonesBonus = bonesBonus or 0

    if alcove then
        if rng:integer(1, 60) == 1 then addEntity(level, "web", x, y - 1)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "crate", x + 0.5, y - 0.5)
        elseif rng:integer(1, 15) == 1 then addEntity(level, "chest", x + 0.5, y - 0.5)
        elseif not level.hasDamsel and rng:integer(1, 8) == 1 then
            addEntity(level, "damsel", x + 0.5, y - 0.5)
            level.hasDamsel = true
        elseif rng:integer(1, math.max(1, 40 - 2 * absoluteLevel)) <= 1 + bonesBonus then
            addBones(level, rng, x, y)
        elseif rng:integer(1, 3) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 6) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, 6) == 1 then addEntity(level, "emerald_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "sapphire_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "ruby_big", x + 0.5, y - 0.25) end
    elseif tunnel then
        if rng:integer(1, 60) == 1 then addEntity(level, "web", x, y - 1)
        elseif rng:integer(1, 4) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, math.max(1, 80 - absoluteLevel)) <= 1 + bonesBonus then
            addBones(level, rng, x, y)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "emerald_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 9) == 1 then addEntity(level, "sapphire_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "ruby_big", x + 0.5, y - 0.25) end
    else
        if rng:integer(1, 40) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 50) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, math.max(1, 140 - 2 * absoluteLevel)) <= 1 + bonesBonus then
            addBones(level, rng, x, y) end
    end
end

local ceilingEnemies = { bat = true, spider = true, giant_spider = true,
    snake = true, caveman = true, shopkeeper = true, scarab = true }
local function enemyAt(level, x, y)
    for _, entity in ipairs(level.entities) do
        if ceilingEnemies[entity.kind] then
            local sprite = SpriteData[entity.kind].sourceSprite
            if SpriteCollision.overlaps(sprite, 0, entity.x*16, entity.y*16, false,
                x*16, y*16, x*16+1, y*16+1, true) then return true end
        end
    end
    return false
end

local function canHangBelow(level, x, y)
    return y < level.height - 4 and not isSolid(level, x, y + 1)
        and not isSolid(level, x, y + 2) and not enemyAt(level, x, y + 1)
end

local function canStandAbove(level, x, y)
    return y > 1 and not isSolid(level, x, y - 1)
        and not entityAt(level, x, y - 1)
end

local function populateMines(level, rng, x, y, state)
    if not inStartRoom(level, x, y - 1) then
        if canHangBelow(level, x, y) then
            if state.generateGiantSpider and not state.giantSpider
                and not isSolid(level, x + 1, y + 1) and not isSolid(level, x + 1, y + 2)
                and rng:integer(1, 40) == 1 then
                addEntity(level, "giant_spider", x, y + 1)
                addEntity(level, "web", x, y + 2)
                addEntity(level, "web", x + 1, y + 2)
                state.giantSpider = true
            elseif level.dark and rng:integer(1, 60) == 1 then
                local tile = getTile(level, x, y+1)
                if tile.kind ~= "ladder" and tile.kind ~= "ladder_top" then
                    addEntity(level, "lamp", x, y+1)
                end
            elseif level.dark and rng:integer(1, 40) == 1 then
                addEntity(level, "scarab", x, y + 1)
                level.entities[#level.entities].counter = rng:integer(10, 30)
            elseif rng:integer(1, 60) == 1 then addEntity(level, "bat", x, y + 1)
            elseif rng:integer(1, 80) == 1 then addEntity(level, "spider", x, y + 1) end
        end
        if canStandAbove(level, x, y) then
            if rng:integer(1, 60) == 1 then addEntity(level, "snake", x, y - 1)
            elseif rng:integer(1, 800) == 1 then addEntity(level, "caveman", x, y - 1) end
        end
    end
end

local function placeMinesTrap(level, rng, x, y)
    if getTile(level, x, y).kind ~= "block" or inShop(level, x, y) then return end
    local entrance = level.entrance
    local entranceDistance = entrance and distance(x, y, entrance.x, entrance.y) or math.huge
    if rng:integer(1, 4) ~= 1 or entranceDistance <= 3
        or (entrance and y == entrance.y and entranceDistance < 9) then return end

    if isSolid(level, x + 1, y) and not isSolid(level, x - 1, y)
        and not isSolid(level, x - 2, y) then
        addEntity(level, level.dark and "arrow_trap_left_lit" or "arrow_trap_left", x, y)
    elseif isSolid(level, x - 1, y) and not isSolid(level, x + 1, y)
        and not isSolid(level, x + 2, y) and not isSolid(level, x + 3, y) then
        addEntity(level, level.dark and "arrow_trap_right_lit" or "arrow_trap_right", x, y)
    else
        return
    end
    level.tiles[y + 1][x + 1] = { kind = "empty" }
end

local function addProgressionItems(level, rng, run)
    if run and run.madeUdjatEye then return end
    local depth = level.levelNumber
    local generateChest = (depth == 2 and rng:integer(1, 3) == 1)
        or (depth == 3 and rng:integer(1, 2) == 1) or depth == 4
    if generateChest then
        local chestX, chestY
        for y = level.height - 2, 2, -1 do
            for x = 1, level.width - 2 do
                if isSolid(level, x, y) and canStandAbove(level, x, y) and not inShop(level, x, y)
                    and not near(level, "entrance", x, y, 3) then
                    chestX, chestY = x + 0.5, y - 0.5
                    break
                end
            end
            if chestX then break end
        end
        -- Like Classic's forced placement, a crowded level still gets its chest
        -- at the exit rather than losing the run's Udjat pair.
        if not chestX and level.exit then
            chestX, chestY = level.exit.x + 0.5, level.exit.y + 0.5
        end
        if chestX then
            addEntity(level, "locked_chest", chestX, chestY)
            level.hasLockedChest = true
            local replaced = false
            for _, entity in ipairs(level.entities) do
                if not replaced and not isSolid(level, math.floor(entity.x), math.floor(entity.y))
                    and not inShop(level, entity.x, entity.y)
                    and (entity.kind == "gold_bar" or entity.kind == "gold_bars"
                    or entity.kind == "emerald_big" or entity.kind == "sapphire_big"
                    or entity.kind == "ruby_big") then
                    entity.kind = "key"
                    replaced = true
                end
            end
            -- Sharing the chest's clear cell avoids burying a fallback key in
            -- the adjacent wall when there is no exposed treasure to replace.
            if not replaced then addEntity(level, "key", chestX, chestY) end
            if run then run.madeUdjatEye = true end
        end
    end
end

EntityGenerator.resolveRooms = resolveEmbeddedEntities

function EntityGenerator.populate(level, rng, run)
    -- Preserve the random draw made before Mines enemy placement by the
    -- original mixed-area generator, so existing seeds keep their layout.
    rng:integer(1, 4)
    local minesState = {
        generateGiantSpider = rng:integer(1, 6) == 1,
        giantSpider = false,
    }

    for y = 1, level.height - 1 do
        for x = 0, level.width - 1 do
            if y > 1 and isSolid(level, x, y) and not inShop(level, x, y) then
                local tile = getTile(level, x, y)
                if not (tile.properties and tile.properties.altar) then
                    treasureGen(level, rng, x, y, 0)
                end
                populateMines(level, rng, x, y, minesState)
            end
        end
    end
    addProgressionItems(level, rng, run)

    -- Classic converts eligible oBlock instances only after treasure, enemies,
    -- the locked chest, and its key have all been generated.
    for y = 1, level.height - 1 do
        for x = 0, level.width - 1 do
            placeMinesTrap(level, rng, x, y)
        end
    end

    if level.entrance then
        if level.dark then
            local x, y = level.entrance.x, level.entrance.y
            local offset = not isSolid(level, x - 1, y) and -1
                or not isSolid(level, x + 1, y) and 1 or 0
            addEntity(level, "flare_crate", x + offset + 0.5, y + 0.5)
        end
        addEntity(level, "player", level.entrance.x + 0.5, level.entrance.y + 0.5,
            { atEntrance = true })
    end
end

return EntityGenerator
