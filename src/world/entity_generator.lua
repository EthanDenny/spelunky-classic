local EntityGenerator = {}

local function getTile(level, x, y)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then return nil end
    return level.tiles[y + 1][x + 1]
end

local function isSolid(level, x, y)
    local tile = getTile(level, x, y)
    if not tile then return false end
    return tile.kind == "solid" or tile.kind == "brick" or tile.kind == "block"
        or tile.kind == "smooth_brick" or tile.kind == "push_block" or tile.kind == "falling"
end

local function isLiquid(level, x, y)
    local tile = getTile(level, x, y)
    return tile and (tile.kind == "liquid" or (tile.properties and tile.properties.liquid))
end

local function addEntity(level, kind, x, y, properties)
    level.entities[#level.entities + 1] = {
        kind = kind,
        x = x,
        y = y,
        properties = properties or {},
    }
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

local HIDDEN_CHANCES = {
    jungle = { 80, 100, 120 },
    dark = { 40, 60, 80 },
    temple = { 60, 80, 100 },
}

local function populateSolidContents(level, rng)
    if level.area == "mines" then return end
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = getTile(level, x, y)
            local base = tile and (tile.baseStyle or tile.style)
            local chances = HIDDEN_CHANCES[base]
            if tile and tile.kind == "solid" and chances then
                local contentsRoll = rng:integer(1, 100)
                if contentsRoll < 20 then
                    tile.style = base .. "_gold"
                elseif contentsRoll < 30 then
                    tile.style = base .. "_gold_big"
                elseif x > 0 and x < level.width - 1 and y > 0 and y < level.height - 1 then
                    if rng:integer(1, chances[1]) == 1 then addEntity(level, "hidden_sapphire", x + 0.5, y + 0.5)
                    elseif rng:integer(1, chances[2]) == 1 then addEntity(level, "hidden_emerald", x + 0.5, y + 0.5)
                    elseif rng:integer(1, chances[3]) == 1 then addEntity(level, "hidden_ruby", x + 0.5, y + 0.5)
                    elseif rng:integer(1, 1200) == 1 then addEntity(level, "hidden_item", x + 0.5, y + 0.5) end
                end
            end
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
        if level.area ~= "ice" and rng:integer(1, 60) == 1 then addEntity(level, "web", x, y - 1)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "crate", x + 0.5, y - 0.5)
        elseif rng:integer(1, 15) == 1 then addEntity(level, "chest", x + 0.5, y - 0.5)
        elseif not level.hasDamsel and rng:integer(1, 8) == 1 and not isLiquid(level, x, y - 1) then
            addEntity(level, "damsel", x + 0.5, y - 0.5)
            level.hasDamsel = true
        elseif rng:integer(1, math.max(1, 40 - 2 * absoluteLevel)) <= 1 + bonesBonus then
            addEntity(level, rng:integer(1, 8) == 1 and "bones" or "skeleton", x, y - 1)
        elseif rng:integer(1, 3) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 6) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, 6) == 1 then addEntity(level, "emerald_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "sapphire_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "ruby_big", x + 0.5, y - 0.25) end
    elseif tunnel then
        if level.area ~= "ice" and rng:integer(1, 60) == 1 then addEntity(level, "web", x, y - 1)
        elseif rng:integer(1, 4) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, math.max(1, 80 - absoluteLevel)) <= 1 + bonesBonus then
            addEntity(level, rng:integer(1, 8) == 1 and "bones" or "skeleton", x, y - 1)
        elseif rng:integer(1, 8) == 1 then addEntity(level, "emerald_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 9) == 1 then addEntity(level, "sapphire_big", x + 0.5, y - 0.25)
        elseif rng:integer(1, 10) == 1 then addEntity(level, "ruby_big", x + 0.5, y - 0.25) end
    else
        if rng:integer(1, 40) == 1 then addEntity(level, "gold_bar", x + 0.5, y - 0.25)
        elseif rng:integer(1, 50) == 1 then addEntity(level, "gold_bars", x + 0.5, y - 0.5)
        elseif rng:integer(1, math.max(1, 140 - 2 * absoluteLevel)) <= 1 + bonesBonus then
            addEntity(level, rng:integer(1, 8) == 1 and "bones" or "skeleton", x, y - 1) end
    end
end

local function canHangBelow(level, x, y)
    return y < level.height - 4 and not isSolid(level, x, y + 1)
        and not isSolid(level, x, y + 2) and not isLiquid(level, x, y + 1)
        and not isLiquid(level, x, y + 2)
end

local function canStandAbove(level, x, y)
    return y > 1 and not isSolid(level, x, y - 1) and not isLiquid(level, x, y - 1)
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

local function populateJungle(level, rng, x, y)
    if not inStartRoom(level, x, y) then
        if canHangBelow(level, x, y) and rng:integer(1, level.hasCemetery and 60 or 80) == 1 then
            addEntity(level, "bat", x, y + 1)
        end
        if canStandAbove(level, x, y) and not entityAt(level, x, y - 1, { spikes = true }) then
            if level.hasCemetery then
                if rng:integer(1, 25) == 1 then addEntity(level, "zombie", x, y - 1)
                elseif rng:integer(1, 160) == 1 then addEntity(level, "vampire", x, y - 1) end
            elseif rng:integer(1, 60) == 1 then addEntity(level, "mantrap", x, y - 1)
            elseif rng:integer(1, 60) == 1 then addEntity(level, "caveman", x, y - 1)
            elseif rng:integer(1, 120) == 1 then addEntity(level, "fire_frog", x, y - 1)
            elseif rng:integer(1, 30) == 1 then addEntity(level, "frog", x, y - 1) end
        end
    end
    if level.hasCemetery and canStandAbove(level, x, y) and rng:integer(1, 20) == 1 then
        addEntity(level, "grave", x, y - 1)
    end
    if y > 2 and canStandAbove(level, x, y) and isSolid(level, x, y + 1)
        and not isSolid(level, x, y - 2) and not near(level, "entrance", x, y, 4)
        and rng:integer(1, 12) == 1 then
        addEntity(level, "spear_trap_bottom", x, y)
        addEntity(level, "spear_trap_top", x, y - 1)
        level.tiles[y + 1][x + 1] = { kind = "empty" }
    end
end

local function populateIce(level, rng, x, y)
    if inStartRoom(level, x, y) or not canStandAbove(level, x, y) or y >= 37 then return end
    if rng:integer(1, 30) == 1 then addEntity(level, "ufo", x, y - 1) end
    if not near(level, "entrance", x, y, 4) then
        if rng:integer(1, 10) == 1 and (getTile(level, x, y).baseStyle or "") == "dark"
            and not isSolid(level, x, y - 2) and not isSolid(level, x, y - 3) then
            addEntity(level, "spring_trap", x, y - 1)
        elseif rng:integer(1, 20) == 1 then addEntity(level, "yeti", x, y - 1) end
    end
end

local function populateTemple(level, rng, x, y, state)
    if canStandAbove(level, x, y) and not inStartRoom(level, x, y) then
        if state.generateTombLord and not state.tombLord and not isSolid(level, x + 1, y - 1)
            and rng:integer(1, 40) == 1 then
            addEntity(level, "tomb_lord", x, y - 2)
            state.tombLord = true
        elseif rng:integer(1, 40) == 1 then addEntity(level, "caveman", x, y - 1)
        elseif rng:integer(1, 40) == 1 then addEntity(level, "hawkman", x, y - 1)
        elseif rng:integer(1, 60) == 1 then addEntity(level, "smash_trap", x, y - 1) end
    end
    local tile = getTile(level, x, y)
    if tile and (tile.kind == "block" or tile.baseStyle == "block") and rng:integer(1, 3) == 1
        and not near(level, "entrance", x, y, 4) then
        if isSolid(level, x + 1, y) and not isSolid(level, x - 1, y) and not isSolid(level, x - 2, y) then
            addEntity(level, "arrow_trap_left", x, y)
            level.tiles[y + 1][x + 1] = { kind = "empty" }
        elseif isSolid(level, x - 1, y) and not isSolid(level, x + 1, y) and not isSolid(level, x + 2, y) then
            addEntity(level, "arrow_trap_right", x, y)
            level.tiles[y + 1][x + 1] = { kind = "empty" }
        end
    elseif y > 2 and canStandAbove(level, x, y) and isSolid(level, x, y + 1)
        and not isSolid(level, x, y - 2) and not near(level, "entrance", x, y, 4)
        and rng:integer(1, 12) == 1 then
        addEntity(level, "spear_trap_bottom", x, y)
        addEntity(level, "spear_trap_top", x, y - 1)
        level.tiles[y + 1][x + 1] = { kind = "empty" }
    end
end

local function addProgressionItems(level, rng)
    if level.area == "mines" then
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
    elseif level.area == "temple" and level.absoluteLevel == 14 then
        for y = 3, level.height - 2 do
            for x = 1, level.width - 2 do
                if canStandAbove(level, x, y) and not inShop(level, x, y) then
                    addEntity(level, "gold_door", x, y - 1)
                    level.hasGoldDoor = true
                    return
                end
            end
        end
    end
end

local function populateVinesAndWater(level, rng)
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = getTile(level, x, y)
            if tile and (tile.kind == "ladder" or tile.kind == "ladder_top") and tile.style == "vine"
                and rng:integer(1, 15) == 1 then
                addEntity(level, "monkey", x, y)
            elseif isLiquid(level, x, y) and not isSolid(level, x, y)
                and rng:integer(1, 30) == 1 then
                addEntity(level, level.hasCemetery and "dead_fish" or "piranha", x + 0.25, y + 0.25)
            end
        end
    end
end

function EntityGenerator.populate(level, rng)
    populateSolidContents(level, rng)
    resolveEmbeddedEntities(level, rng)

    local templeState = {
        generateTombLord = level.absoluteLevel == 13 or rng:integer(1, 4) == 1,
        tombLord = false,
    }
    local minesState = {
        generateGiantSpider = level.area == "mines" and rng:integer(1, 6) == 1,
        giantSpider = false,
    }

    if level.area ~= "olmec" then
        for y = 1, level.height - 1 do
            for x = 0, level.width - 1 do
                if isSolid(level, x, y) and not inShop(level, x, y) then
                    local tile = getTile(level, x, y)
                    if not (tile.properties and tile.properties.altar) then
                        treasureGen(level, rng, x, y, level.hasCemetery and 10 or 0)
                    end
                    if level.area == "mines" then populateMines(level, rng, x, y, minesState)
                    elseif level.area == "jungle" then populateJungle(level, rng, x, y)
                    elseif level.area == "ice" then populateIce(level, rng, x, y)
                    elseif level.area == "temple" then populateTemple(level, rng, x, y, templeState) end
                end
            end
        end
    end

    if level.area == "jungle" then populateVinesAndWater(level, rng) end
    addProgressionItems(level, rng)

    if level.entrance then
        addEntity(level, "player", level.entrance.x + 0.5, level.entrance.y + 0.5,
            { atEntrance = true })
    end
end

return EntityGenerator
