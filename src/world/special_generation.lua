local SpecialGeneration = {}

local function hash(seed, salt)
    local value = (math.floor(seed or 1) * 1103515245 + salt * 12345) % 2147483647
    return value / 2147483647
end

local function tile(level, x, y)
    return level.tiles[y + 1] and level.tiles[y + 1][x + 1]
end

local function isSolid(value)
    return value and (value.kind == "solid" or value.kind == "brick" or value.kind == "block"
        or value.kind == "smooth_brick" or value.kind == "push_block" or value.kind == "falling")
end

local function add(level, kind, x, y, properties)
    level.entities[#level.entities + 1] = { kind = kind, x = x, y = y, properties = properties or {} }
end

local function findFloor(level, fromBottom)
    local first, last, step = 2, level.height - 2, 1
    if fromBottom then first, last, step = level.height - 2, 2, -1 end
    for y = first, last, step do
        for x = 2, level.width - 3 do
            if isSolid(tile(level, x, y)) and not isSolid(tile(level, x, y - 1))
                and not isSolid(tile(level, x + 1, y - 1)) then
                return x, y - 1
            end
        end
    end
end

local function removeKind(level, kind)
    for index = #level.entities, 1, -1 do
        if level.entities[index].kind == kind then table.remove(level.entities, index) end
    end
end

function SpecialGeneration.apply(level, run)
    local absolute = level.absoluteLevel or level.levelNumber or 1
    level.specialEntrances = {}
    local darkEligible = absolute > 1 and absolute ~= 16 and level.area ~= "ice"
        and not run.hadDarkLevel and not level.blackMarket
    level.dark = darkEligible and hash(level.seed, absolute * 17) < (1 / 12)
    if level.dark then
        run.hadDarkLevel = true
        local x, y = findFloor(level, false)
        if x then
            add(level, "lamp", x, y)
            add(level, "scarab", math.min(level.width - 2, x + 5), y - 1)
        end
    end

    if (absolute == 4 and run.tunnel1 > 0) or (absolute == 8 and run.tunnel2 > 0) then
        local x, y = findFloor(level, true)
        if x then add(level, "tunnel_man", x, y, { tunnel = absolute == 4 and 1 or 2 }) end
    end

    if level.area == "jungle" and absolute == run.blackMarketLevel then
        level.blackMarket = true
        if run.equipment.udjat_eye and not run.visited.black_market then
            local x, y = findFloor(level, true)
            if x then
                add(level, "door", x, y, { special = "black_market", label = "BLACK MARKET" })
                level.specialEntrances[#level.specialEntrances + 1] = level.entities[#level.entities]
            end
        end
    elseif level.area == "ice" then
        if absolute == run.lakeLevel then
            level.lake = true
            for y = math.max(4, level.height - 8), level.height - 3 do
                for x = 3, level.width - 4 do
                    local value = tile(level, x, y)
                    if value and value.kind == "empty" then
                        value.kind, value.style = "liquid", "water"
                        value.properties = { liquid = "water" }
                    end
                end
            end
        end
        if absolute == run.alienLevel and not run.visited.alien_craft then
            level.alienCraft = true
            local x, y = findFloor(level, false)
            if x then
                add(level, "alien_structure", x, y)
                add(level, "door", x + 1, y, { special = "alien_craft", label = "MOTHERSHIP" })
                level.specialEntrances[#level.specialEntrances + 1] = level.entities[#level.entities]
            end
        end
        if absolute == run.yetiLevel and not run.visited.yeti_lair then
            level.yetiLair = true
            local x, y = findFloor(level, true)
            if x then
                add(level, "door", x, y, { special = "yeti_lair", label = "YETI LAIR" })
                level.specialEntrances[#level.specialEntrances + 1] = level.entities[#level.entities]
            end
        end
        if level.hasMoai and run.equipment.ankh and not run.visited.moai then
            local x, y = findFloor(level, true)
            if x then
                add(level, "moai_inside", x, y, { special = "moai", label = "MOAI" })
                level.specialEntrances[#level.specialEntrances + 1] = level.entities[#level.entities]
            end
        end
    elseif level.area == "temple" then
        if run.equipment.crown and absolute == 14 and not run.visited.city_of_gold then
            local x, y = findFloor(level, true)
            if x then
                removeKind(level, "gold_door")
                add(level, "gold_door", x, y, { special = "city_of_gold", label = "CITY OF GOLD" })
                level.specialEntrances[#level.specialEntrances + 1] = level.entities[#level.entities]
            end
        else
            removeKind(level, "gold_door")
        end
    end
    return level
end

local function emptyGrid(width, height)
    local rows = {}
    for y = 0, height - 1 do
        rows[y + 1] = {}
        for x = 0, width - 1 do
            local border = x == 0 or x == width - 1 or y == 0 or y == height - 1
            rows[y + 1][x + 1] = border and { kind = "solid", style = "block" }
                or { kind = "empty" }
        end
    end
    return rows
end

local function platform(level, x, y, width)
    for column = x, x + width - 1 do level.tiles[y + 1][column + 1] = { kind = "solid", style = "block" } end
end

function SpecialGeneration.interior(kind, seed)
    if kind == "black_market" or kind == "city_of_gold" or kind == "alien_craft"
        or kind == "yeti_lair" then
        local ClassicAreaGenerator = require("src.world.classic_area_generator")
        local area = kind == "black_market" and "jungle"
            or kind == "city_of_gold" and "temple" or "ice"
        local level = ClassicAreaGenerator.generate(area, seed, {
            levelNumber = 1,
            special = kind,
        })
        level.special = kind
        local x, y = findFloor(level, true)
        if kind == "black_market" then
            add(level, "shopkeeper", x, y, { shopType = "Ankh" })
            add(level, "ankh", x + 2, y, { forSale = true, shopType = "Ankh" })
        elseif kind == "city_of_gold" then
            for offset = 0, 8, 2 do add(level, "gold_bars", math.min(level.width - 2, x + offset), y) end
            add(level, "tomb_lord", x, y - 1)
            add(level, "ankh", x + 2, y)
        elseif kind == "alien_craft" then
            add(level, "alien_boss", x, y - 1)
            add(level, "jetpack", x + 2, y)
            add(level, "alien", x + 4, y)
        elseif kind == "yeti_lair" then
            add(level, "yeti_king", x, y - 1)
            for offset = 3, 15, 4 do add(level, "yeti", math.min(level.width - 2, x + offset), y) end
            add(level, "crown", x + 2, y)
        end
        return level
    end
    local level = {
        area = kind == "city_of_gold" and "temple" or kind == "black_market" and "jungle" or "ice",
        special = kind,
        seed = seed,
        levelNumber = 1,
        absoluteLevel = 0,
        width = 40,
        height = 24,
        tileSize = 16,
        tiles = emptyGrid(40, 24),
        entities = {},
        decorations = {},
        roomPath = { { 1 } },
    }
    platform(level, 1, 20, 38)
    platform(level, 4, 15, 12)
    platform(level, 22, 14, 13)
    platform(level, 12, 9, 16)
    level.entrance = { x = 2, y = 19 }
    level.exit = { x = 37, y = 19 }
    add(level, "entrance", 2, 19)
    add(level, "exit", 37, 19, { specialReturn = true })

    if kind == "black_market" then
        for shop = 0, 3 do
            local x = 7 + shop * 8
            add(level, "shopkeeper", x, 14, { shopType = "Rare" })
            add(level, ({ "jetpack", "shotgun", "ankh", "crown" })[shop + 1], x + 2, 14,
                { forSale = true, shopType = "Rare" })
        end
    elseif kind == "city_of_gold" then
        for x = 5, 34, 3 do add(level, "gold_bars", x, 19) end
        add(level, "tomb_lord", 20, 8)
        add(level, "ankh", 20, 13)
    elseif kind == "alien_craft" then
        add(level, "alien_boss", 20, 13)
        add(level, "jetpack", 20, 19)
        for x = 7, 33, 8 do
            add(level, "ufo", x, 13)
            add(level, "alien", x + 2, 19)
        end
    elseif kind == "yeti_lair" then
        add(level, "yeti_king", 20, 13)
        for x = 7, 33, 6 do add(level, "yeti", x, 19) end
        add(level, "crown", 20, 13)
    elseif kind == "moai" then
        add(level, "crown", 20, 19)
    end
    return level
end

return SpecialGeneration
