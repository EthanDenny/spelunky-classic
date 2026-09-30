local EntityGenerator = {}

local function getTile(level, x, y)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then return nil end
    return level.tiles[y + 1][x + 1]
end

local function isSolid(level, x, y)
    local tile = getTile(level, x, y)
    if not tile then return false end
    return tile.kind == "solid" or tile.kind == "brick" or tile.kind == "block"
        or tile.kind == "smooth_brick" or tile.kind == "push_block"
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

local function itemExists(level, kind)
    for _, entity in ipairs(level.entities) do
        if entity.kind == kind then return true end
    end
    return false
end

local function chooseShopItem(level, rng, shopType, highEnd)
    if highEnd then
        local items = {
            "jetpack", "cape", "shotgun", "gloves", "teleporter", "mattock", "paste",
            "spring_shoes", "spike_shoes", "compass", "pistol", "machete", "bomb_box",
        }
        return items[rng:integer(1, #items)]
    end

    if shopType == "Bomb" then
        if rng:integer(1, 5) == 1 and not itemExists(level, "paste") then return "paste" end
        if rng:integer(1, 4) == 1 then return "bomb_box" end
        return "bomb_bag"
    elseif shopType == "Weapon" then
        local items = { "pistol", "machete", "bomb_bag", "bow", "web_cannon", "shotgun", "bomb_box" }
        for _ = 1, 20 do
            local item = items[rng:integer(1, #items)]
            if item == "bomb_bag" or item == "bomb_box" or not itemExists(level, item) then return item end
        end
        return "bomb_bag"
    elseif shopType == "Clothing" then
        local items = { "spring_shoes", "spectacles", "gloves", "mitt", "cape", "spike_shoes", "rope_pile" }
        for _ = 1, 20 do
            local item = items[rng:integer(1, #items)]
            if item == "rope_pile" or not itemExists(level, item) then return item end
        end
        return "rope_pile"
    elseif shopType == "Rare" then
        local items = {
            "spring_shoes", "compass", "mattock", "spectacles", "jetpack", "gloves",
            "mitt", "web_cannon", "cape", "teleporter", "spike_shoes", "bomb_box",
        }
        for _ = 1, 20 do
            local item = items[rng:integer(1, #items)]
            if item == "bomb_box" or not itemExists(level, item) then return item end
        end
        return "bomb_box"
    end

    if rng:integer(1, 20) == 1 and not itemExists(level, "mattock") then return "mattock" end
    if rng:integer(1, 10) == 1 and not itemExists(level, "gloves") then return "gloves" end
    if rng:integer(1, 10) == 1 and not itemExists(level, "compass") then return "compass" end
    return ({ "bomb_bag", "rope_pile", "parachute" })[rng:integer(1, 3)]
end

local function resolveEmbeddedEntities(level, rng)
    for _, entity in ipairs(level.entities) do
        if entity.kind == "shop_item" then
            entity.kind = chooseShopItem(level, rng, entity.properties.shopType,
                entity.properties.highEnd)
            entity.properties.forSale = true
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

local function canHangBelow(level, x, y)
    return y < level.height - 4 and not isSolid(level, x, y + 1)
        and not isSolid(level, x, y + 2)
end

local function canStandAbove(level, x, y)
    return y > 1 and not isSolid(level, x, y - 1)
        and not entityAt(level, x, y - 1)
end

local function populateMines(level, rng, x, y, state)
    if not inStartRoom(level, x, y) then
        if canHangBelow(level, x, y) then
            if state.generateGiantSpider and not state.giantSpider
                and not isSolid(level, x + 1, y + 1) and not isSolid(level, x + 1, y + 2)
                and rng:integer(1, 40) == 1 then
                addEntity(level, "giant_spider", x, y + 1)
                state.giantSpider = true
            elseif rng:integer(1, 60) == 1 then addEntity(level, "bat", x, y + 1)
            elseif rng:integer(1, 80) == 1 then addEntity(level, "spider", x, y + 1) end
        end
        if canStandAbove(level, x, y) then
            if rng:integer(1, 60) == 1 then addEntity(level, "snake", x, y - 1)
            elseif rng:integer(1, 800) == 1 then addEntity(level, "caveman", x, y - 1) end
        end
    end

    if getTile(level, x, y).kind == "block" and rng:integer(1, 4) == 1
        and not near(level, "entrance", x, y, 9) then
        if isSolid(level, x + 1, y) and not isSolid(level, x - 1, y) and not isSolid(level, x - 2, y) then
            addEntity(level, "arrow_trap_left", x, y)
            level.tiles[y + 1][x + 1] = { kind = "empty" }
        elseif isSolid(level, x - 1, y) and not isSolid(level, x + 1, y) and not isSolid(level, x + 2, y) then
            addEntity(level, "arrow_trap_right", x, y)
            level.tiles[y + 1][x + 1] = { kind = "empty" }
        end
    end
end

local function addProgressionItems(level, rng)
    local depth = level.levelNumber
    local generateChest = (depth == 2 and rng:integer(1, 3) == 1)
        or (depth == 3 and rng:integer(1, 2) == 1) or depth == 4
    if generateChest then
        local chestX, chestY
        for y = level.height - 2, 2, -1 do
            for x = 1, level.width - 2 do
                if canStandAbove(level, x, y) and not inShop(level, x, y)
                    and not near(level, "entrance", x, y, 3) then
                    chestX, chestY = x + 0.5, y - 0.5
                    break
                end
            end
            if chestX then break end
        end
        if chestX then
            addEntity(level, "locked_chest", chestX, chestY)
            level.hasLockedChest = true
            local replaced = false
            for _, entity in ipairs(level.entities) do
                if not replaced and (entity.kind == "gold_bar" or entity.kind == "gold_bars"
                    or entity.kind == "emerald_big" or entity.kind == "sapphire_big"
                    or entity.kind == "ruby_big") then
                    entity.kind = "key"
                    replaced = true
                end
            end
            if not replaced then addEntity(level, "key", chestX - 1, chestY) end
        end
    end
end

function EntityGenerator.populate(level, rng)
    resolveEmbeddedEntities(level, rng)
    -- Preserve the random draw made before Mines enemy placement by the
    -- original mixed-area generator, so existing seeds keep their layout.
    rng:integer(1, 4)
    local minesState = {
        generateGiantSpider = rng:integer(1, 6) == 1,
        giantSpider = false,
    }

    for y = 1, level.height - 1 do
        for x = 0, level.width - 1 do
            if isSolid(level, x, y) and not inShop(level, x, y) then
                local tile = getTile(level, x, y)
                if not (tile.properties and tile.properties.altar) then
                    treasureGen(level, rng, x, y, 0)
                end
                populateMines(level, rng, x, y, minesState)
            end
        end
    end
    addProgressionItems(level, rng)

    if level.entrance then
        addEntity(level, "player", level.entrance.x + 0.5, level.entrance.y + 0.5,
            { atEntrance = true })
    end
end

return EntityGenerator
