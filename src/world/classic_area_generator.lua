local Data = require("src.world.original_area_data")
local EntityGenerator = require("src.world.entity_generator")

local ClassicAreaGenerator = {}

local WIDTH = 42
local ROOM_WIDTH = 10
local ROOM_HEIGHT = 8

local AREA_CONFIG = {
    jungle = { height = 34, levelOffset = 4, depthCount = 4, solid = "jungle" },
    ice = { height = 38, levelOffset = 8, depthCount = 4, solid = "dark" },
    temple = { height = 34, levelOffset = 12, depthCount = 3, solid = "temple" },
    olmec = { height = 55, levelOffset = 15, depthCount = 1, solid = "temple" },
}

local function newRandom(seed)
    local source = love.math.newRandomGenerator(seed)
    return {
        integer = function(_, minimum, maximum)
            return source:random(minimum, maximum)
        end,
    }
end

local function makeGrid(width, height, valueFactory)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = valueFactory and valueFactory() or 0
        end
    end
    return grid
end

local function newRoomPath()
    return { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
end

local function getRoom(level, x, y)
    if x < 0 or x > 3 or y < 0 or y > 3 then
        return 0
    end
    return level.roomPath[y + 1][x + 1]
end

local function setRoom(level, x, y, value)
    if x >= 0 and x <= 3 and y >= 0 and y <= 3 then
        level.roomPath[y + 1][x + 1] = value
    end
end

local function getTile(level, x, y)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then
        return nil
    end
    return level.tiles[y + 1][x + 1]
end

local function setTile(level, x, y, kind, style, properties)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then
        return
    end
    level.tiles[y + 1][x + 1] = {
        kind = kind,
        style = style,
        baseStyle = style,
        properties = properties or {},
    }
end

local function isSolid(tile)
    return tile and (tile.kind == "solid" or tile.kind == "push_block" or tile.kind == "falling")
end

local function addEntity(level, kind, x, y, properties)
    level.entities[#level.entities + 1] = {
        kind = kind,
        x = x,
        y = y,
        properties = properties or {},
    }
end

local function buildBorder(level)
    local style = AREA_CONFIG[level.area].solid
    local bottom = level.area ~= "ice"

    for x = 0, level.width - 1 do
        setTile(level, x, 0, "solid", style, { invincible = true })
        if bottom then
            setTile(level, x, level.height - 1, "solid", style, { invincible = true })
        end
    end
    for y = 0, level.height - 1 do
        setTile(level, 0, y, "solid", style, { invincible = true })
        setTile(level, level.width - 1, y, "solid", style, { invincible = true })
    end
end

local function generatePath(level, rng)
    local roomX = rng:integer(0, 3)
    local roomY = 0
    local previousX = roomX
    local previousY = 0
    local specialColumn = rng:integer(0, 3)

    level.startRoomX = roomX
    level.startRoomY = 0
    setRoom(level, roomX, roomY, 1)

    if level.area == "temple" and rng:integer(1, 8) == 1 then
        while specialColumn == roomX do
            specialColumn = rng:integer(0, 3)
        end
        setRoom(level, specialColumn, 0, 7)
        setRoom(level, specialColumn, 1, 8)
        setRoom(level, specialColumn, 2, 8)
        setRoom(level, specialColumn, 3, 9)
        level.hasSacrificePit = true
        level.hasIdol = true
        level.hasDamsel = true
    end

    while roomY < 4 do
        local movedDown = false
        local direction
        if roomX == 0 then
            direction = rng:integer(3, 5)
        elseif roomX == 3 then
            direction = rng:integer(5, 7)
        else
            direction = rng:integer(1, 5)
        end

        if direction < 3 or direction > 5 then
            if roomX > 0 then
                if getRoom(level, roomX - 1, roomY) == 0 then roomX = roomX - 1 end
            elseif roomX < 3 then
                if getRoom(level, roomX + 1, roomY) == 0 then roomX = roomX + 1 end
            else
                direction = 5
            end
        elseif direction == 3 or direction == 4 then
            if roomX < 3 then
                if getRoom(level, roomX + 1, roomY) == 0 then roomX = roomX + 1 end
            elseif roomX > 0 then
                if getRoom(level, roomX - 1, roomY) == 0 then roomX = roomX - 1 end
            else
                direction = 5
            end
        end

        if direction == 5 then
            roomY = roomY + 1
            movedDown = true
            if roomY < 4 then
                setRoom(level, previousX, previousY, 2)
                setRoom(level, roomX, roomY, 3)
            else
                level.endRoomX = roomX
                level.endRoomY = roomY - 1
            end
        end

        if not movedDown then setRoom(level, roomX, roomY, 1) end
        previousX = roomX
        previousY = roomY
    end

    if level.area == "ice" then
        local absoluteLevel = level.absoluteLevel
        local makeMoai = (absoluteLevel == 9 and rng:integer(1, 4) == 1)
            or (absoluteLevel == 10 and rng:integer(1, 3) == 1)
            or (absoluteLevel == 11 and rng:integer(1, 2) == 1)
            or absoluteLevel == 12
        if makeMoai then
            setRoom(level, rng:integer(0, 3), rng:integer(1, 2), 6)
            level.hasMoai = true
        end
    end
end

local function addShop(level, rng)
    if rng:integer(1, level.absoluteLevel) > 2 then
        return
    end

    local possibilities = {}
    for y = 0, 3 do
        for x = 0, 3 do
            if getRoom(level, x, y) == 0 then
                if x < 3 then
                    local right = getRoom(level, x + 1, y)
                    if right == 1 or right == 2 then
                        possibilities[#possibilities + 1] = { x = x, y = y, value = 4 }
                    end
                elseif x > 0 then
                    local left = getRoom(level, x - 1, y)
                    if left == 1 or left == 2 then
                        possibilities[#possibilities + 1] = { x = x, y = y, value = 5 }
                    end
                end
            end
        end
    end

    if #possibilities > 0 then
        local choice = possibilities[rng:integer(1, #possibilities)]
        setRoom(level, choice.x, choice.y, choice.value)
        level.hasShop = true
    end
end

local function resolve(template, rng)
    if type(template) == "table" then
        return template[rng:integer(1, #template)]
    end
    return template
end

local SHOP_TYPES = { "General", "Bomb", "Weapon", "Rare", "Clothing", "Craps", "Kissing" }

local function chooseShop(level, rng, leftTemplate, leftCraps, leftKissing,
        rightTemplate, rightCraps, rightKissing, roomPath, restrictDamsel)
    local maximum = restrictDamsel and level.hasDamsel and 6 or 7
    local index = rng:integer(1, maximum)
    local shopType = SHOP_TYPES[index]
    if roomPath == 4 then
        if index == 6 then return leftCraps, shopType end
        if index == 7 then level.hasDamsel = true return leftKissing, shopType end
        return leftTemplate, shopType
    end
    if index == 6 then return rightCraps, shopType end
    if index == 7 then level.hasDamsel = true return rightKissing, shopType end
    return rightTemplate, shopType
end

local function chooseJungle(level, rng, x, y)
    local t = Data.jungle.templates
    local path = getRoom(level, x, y)
    local above = y == 0 and -1 or getRoom(level, x, y - 1)
    if x == level.startRoomX and y == level.startRoomY then
        return t[path == 2 and rng:integer(4, 5) or rng:integer(2, 3)]
    elseif x == level.endRoomX and y == level.endRoomY then
        return t[above == 2 and rng:integer(6, 7) or rng:integer(8, 9)]
    elseif path == 0 and rng:integer(1, 3) <= 2 then
        local index
        if not level.hasAltar and rng:integer(1, 12) == 1 then
            index = 10
            level.hasAltar = true
        elseif level.hasIdol then
            index = rng:integer(1, 8)
        else
            index = rng:integer(1, 9)
            if index == 9 then level.hasIdol = true end
        end
        if index <= 8 then return t[10 + index] end
        if index == 9 then return level.hasCemetery and t[19] or t[20] end
        return t[21]
    elseif path == 0 or path == 1 then
        local index = rng:integer(1, 10)
        if index <= 5 then return t[21 + index] end
        if index == 6 then return resolve({ t[27], t[28] }, rng) end
        return t[22 + index]
    elseif path == 3 then
        return t[32 + rng:integer(1, 7)]
    elseif path == 4 or path == 5 then
        return chooseShop(level, rng, t[40], t[41], t[42], t[43], t[44], t[45], path)
    end
    local maximum = above ~= 2 and 6 or 5
    return t[62 + rng:integer(1, maximum)]
end

local function chooseIce(level, rng, x, y)
    local t = Data.ice.templates
    local path = getRoom(level, x, y)
    if x == level.startRoomX and y == level.startRoomY then
        return t[path == 2 and 3 or 2]
    elseif x == level.endRoomX and y == level.endRoomY then
        return t[4]
    elseif path == 0 and rng:integer(1, 2) == 1 then
        local index
        if not level.hasAltar and rng:integer(1, 12) == 1 then
            index = 10
            level.hasAltar = true
        elseif level.hasIdol then
            index = rng:integer(1, 8)
        else
            index = rng:integer(1, 9)
            if index == 9 then level.hasIdol = true end
        end
        return t[4 + index]
    elseif (path == 0 or path == 1 or path == 2) and rng:integer(1, 10) < 10 then
        return t[14 + rng:integer(1, 9)]
    elseif path == 4 or path == 5 then
        return chooseShop(level, rng, t[24], t[25], t[26], t[27], t[28], t[29], path)
    elseif path == 6 then
        return t[29 + rng:integer(1, 2)]
    elseif path == 7 then
        return t[32]
    elseif path == 8 then
        return t[33]
    elseif path == 9 then
        return t[34]
    end
    return t[35]
end

local function chooseTemple(level, rng, x, y)
    local t = Data.temple.templates
    local path = getRoom(level, x, y)
    if x == level.startRoomX and y == level.startRoomY then
        return t[path == 2 and 3 or 2]
    elseif x == level.endRoomX and y == level.endRoomY then
        return t[4]
    elseif path == 0 and rng:integer(1, 4) > 1 then
        local index
        if not level.hasAltar and rng:integer(1, 12) == 1 then
            index = 16
            level.hasAltar = true
        elseif level.hasIdol then
            index = rng:integer(1, 11)
        else
            index = rng:integer(1, 12)
            if index == 12 then level.hasIdol = true end
        end
        if index <= 9 then return t[4 + index] end
        if index == 10 then return resolve({ t[14], t[15] }, rng) end
        return t[5 + index]
    elseif path == 0 or path == 1 then
        return t[21 + rng:integer(1, 10)]
    elseif path == 3 then
        return t[33 + rng:integer(1, 4)]
    elseif path == 4 or path == 5 then
        return chooseShop(level, rng, t[38], t[39], t[40], t[41], t[42], t[43], path, true)
    elseif path >= 6 and path <= 9 then
        return t[38 + path]
    end
    return t[47 + rng:integer(1, 8)]
end

local function selectObstacle(area, marker, rng)
    local choices = Data[area].obstacles[marker]
    if not choices then return nil end

    if area == "jungle" and marker == "5" then
        if rng:integer(1, 8) == 1 then
            return choices[rng:integer(3, 5)]
        end
        return choices[rng:integer(1, 2)]
    elseif area == "olmec" and marker == "6" then
        local index = rng:integer(1, 8)
        if index > #choices then
            return { "00000", "00000", "00000" }
        end
        return choices[index]
    end
    return choices[rng:integer(1, #choices)]
end

local function expandObstacles(area, template, rng)
    assert(#template == 80, "Original area template is not 10 x 8")
    local characters = {}
    for index = 1, 80 do characters[index] = template:sub(index, index) end

    for index = 1, 80 do
        local obstacle = selectObstacle(area, characters[index], rng)
        if obstacle then
            local width = #obstacle[1]
            for row = 0, #obstacle - 1 do
                for column = 0, width - 1 do
                    characters[index + row * ROOM_WIDTH + column] = obstacle[row + 1]:sub(column + 1, column + 1)
                end
            end
        end
    end
    return table.concat(characters)
end

local function placeDoor(level, x, y, roomX, roomY, solidStyle)
    setTile(level, x, y + 1, "solid", solidStyle, { invincible = true })
    if roomX == level.startRoomX and roomY == level.startRoomY then
        addEntity(level, "entrance", x, y)
        level.entrance = { x = x, y = y }
    else
        addEntity(level, "exit", x, y)
        level.exit = { x = x, y = y }
    end
end

local function placeShared(level, rng, symbol, x, y, roomX, roomY, shopType,
        solidStyle, ladderStyle, options)
    options = options or {}
    if symbol == "9" then
        placeDoor(level, x, y, roomX, roomY, solidStyle)
    elseif symbol == "L" then
        setTile(level, x, y, "ladder", ladderStyle)
    elseif symbol == "P" then
        setTile(level, x, y, options.plainLadderTop and "ladder" or "ladder_top", ladderStyle)
    elseif symbol == "7" and (options.spikesAlways or rng:integer(1, 3) == 1) then
        addEntity(level, "spikes", x, y)
    elseif symbol == "4" and (options.pushBlockAlways or rng:integer(1, 4) == 1) then
        setTile(level, x, y, "push_block", "block")
    elseif symbol == "I" then
        addEntity(level, "gold_idol", x + 1, y)
    elseif symbol == "x" then
        addEntity(level, "sacrifice_altar", x, y)
    elseif symbol == "K" then
        addEntity(level, "shopkeeper", x, y, { shopType = shopType })
    elseif symbol == "k" then
        addEntity(level, "shop_sign", x, y, { shopType = shopType })
    elseif symbol == "q" or symbol == "i" or symbol == "$" then
        addEntity(level, "shop_item", x, y,
            { shopType = shopType, highEnd = symbol == "q" })
    elseif symbol == "u" then
        addEntity(level, "die", x, y)
    elseif symbol == "l" then
        addEntity(level, "lamp", x, y)
    elseif symbol == "+" then
        setTile(level, x, y, "solid", "ice")
    end
end

local function placeJungle(level, rng, symbol, x, y, roomX, roomY, shopType)
    if symbol == "1" and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "jungle")
    elseif symbol == "2" and rng:integer(1, 2) == 1 and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "jungle")
    elseif symbol == "t" and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "temple")
    elseif symbol == "r" and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", rng:integer(1, 2) == 1 and "temple" or "jungle")
    elseif symbol == "3" and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 2) == 1 then setTile(level, x, y, "liquid", "water")
        else setTile(level, x, y, "solid", "jungle") end
    elseif symbol == "s" then
        addEntity(level, "spikes", x, y)
    elseif symbol == "w" then
        setTile(level, x, y, "liquid", "water")
    elseif symbol == "v" then
        setTile(level, x, y, "solid", "jungle", { liquid = "water" })
    elseif symbol == "," then
        if rng:integer(1, 2) == 1 then setTile(level, x, y, "solid", "jungle", { liquid = "water" })
        else setTile(level, x, y, "liquid", "water") end
    elseif symbol == "." and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "jungle", { shopWall = true })
    elseif symbol == "b" then
        setTile(level, x, y, "solid", "jungle_smooth", { shopWall = true })
    elseif symbol == "B" then
        addEntity(level, "trap_block", x, y)
    elseif symbol == "C" then
        addEntity(level, "crystal_skull", x, y)
    elseif symbol == "c" then
        addEntity(level, "chest", x, y)
    elseif symbol == "d" then
        setTile(level, x, y, "liquid", "water")
        addEntity(level, "chest", x, y)
    elseif symbol == "J" then
        setTile(level, x, y, "liquid", "water")
        addEntity(level, "jaws", x, y)
    elseif symbol == "D" then
        addEntity(level, "damsel", x, y)
    elseif symbol == "T" then
        addEntity(level, "tree", x, y)
    elseif symbol == "p" then
        addEntity(level, rng:integer(1, 2) == 1 and "fake_bones" or "jar", x, y)
    end
    placeShared(level, rng, symbol, x, y, roomX, roomY, shopType, "jungle", "vine",
        { pushBlockAlways = true })
end

local function placeIce(level, rng, symbol, x, y, roomX, roomY, shopType)
    if symbol == "1" and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "ice" or "dark")
    elseif symbol == "2" and rng:integer(1, 2) == 1 and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "ice" or "dark")
    elseif symbol == "i" then
        setTile(level, x, y, "solid", "ice")
    elseif symbol == "j" and rng:integer(1, 2) == 1 then
        setTile(level, x, y, "solid", "ice")
    elseif symbol == "f" then
        setTile(level, x, y, "falling", "dark_fall")
    elseif symbol == "c" then
        setTile(level, x, y, "falling", "thin_ice")
    elseif symbol == "w" then
        setTile(level, x, y, "liquid", "water")
    elseif symbol == "." and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "dark", { shopWall = true })
    elseif symbol == ":" then
        setTile(level, x, y, "solid", "dark_smooth", { shopWall = true })
    elseif symbol == "a" then
        addEntity(level, "chest", x, y)
    elseif symbol == "Y" then
        addEntity(level, "yeti", x, y)
    elseif symbol == "M" then
        addEntity(level, "moai", x, y)
        addEntity(level, "moai2", x + 1, y)
        addEntity(level, "moai3", x + 2, y)
        addEntity(level, "moai_inside", x + 1, y + 1)
        setTile(level, x + 1, y + 2, "falling", "thin_ice")
        addEntity(level, "exit", x + 1, y + 3, { type = "Moai Exit" })
        addEntity(level, "crown", x + 1.5, y + 3.5)
    elseif symbol == "b" then
        if rng:integer(1, 2) == 1 then
            setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "ice" or "dark")
        else
            addEntity(level, "alien_structure", x, y, { symbol = symbol })
        end
    elseif symbol == "A" or symbol == "B" or symbol == "C" or symbol == "D" then
        addEntity(level, "alien_structure", x, y, { symbol = symbol })
    elseif symbol == "E" or symbol == "G" then
        addEntity(level, "alien_structure", x, y, { symbol = symbol })
    elseif symbol == "X" then
        addEntity(level, "alien_boss", x, y)
    elseif symbol == "!" then
        addEntity(level, "damsel", x, y)
    elseif symbol == "m" and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", "dark", { invincible = true })
    elseif symbol == "T" then
        setTile(level, x, y, "solid", "dark")
        addEntity(level, "jetpack", x, y)
    elseif symbol == "t" then
        addEntity(level, "barrier_emitter", x, y)
    end
    placeShared(level, rng, symbol, x, y, roomX, roomY, shopType, "dark", "vine",
        { spikesAlways = true, plainLadderTop = true })
end

local function placeTemple(level, rng, symbol, x, y, roomX, roomY, shopType)
    if symbol == "1" and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 100) == 1 then setTile(level, x, y, "solid", "jungle")
        elseif rng:integer(1, 10) == 1 then setTile(level, x, y, "solid", "block")
        else setTile(level, x, y, "solid", "temple") end
    elseif symbol == "2" and rng:integer(1, 2) == 1 and not isSolid(getTile(level, x, y)) then
        setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "block" or "temple")
    elseif symbol == "3" and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 2) == 1 then setTile(level, x, y, "liquid", "lava")
        else setTile(level, x, y, "solid", "temple") end
    elseif symbol == "R" then
        setTile(level, x, y, "solid", "temple")
        addEntity(level, "hidden_ruby", x, y)
    elseif symbol == "w" then
        setTile(level, x, y, "liquid", "lava")
    elseif symbol == "a" then
        addEntity(level, "chest", x, y)
    elseif symbol == "c" then
        addEntity(level, rng:integer(1, 2) == 1 and "chest" or "crate", x, y)
    elseif symbol == "." or symbol == "b" then
        setTile(level, x, y, "solid", "temple", { shopWall = true })
    elseif symbol == "d" then
        setTile(level, x, y, "solid", "jungle")
    elseif symbol == "e" and rng:integer(1, 2) == 1 then
        setTile(level, x, y, "solid", "jungle")
    elseif symbol == "C" then
        addEntity(level, "ceiling_trap", x, y)
    elseif symbol == "B" then
        addEntity(level, "trap_block", x, y)
    elseif symbol == "D" then
        addEntity(level, "door", x, y)
    elseif symbol == "A" then
        addEntity(level, "damsel", x, y)
    elseif symbol == ";" then
        addEntity(level, "damsel", x, y)
        addEntity(level, "gold_idol", x + 1, y)
    elseif symbol == "?" then
        addEntity(level, "tomb_lord", x, y)
    elseif symbol == "X" then
        addEntity(level, "lady_xoc", x, y)
    elseif symbol == "T" then
        addEntity(level, "tree", x, y)
    elseif symbol == "t" then
        addEntity(level, "treasure", x, y)
    elseif symbol == "p" then
        addEntity(level, "lamp_red", x, y)
    end
    placeShared(level, rng, symbol, x, y, roomX, roomY, shopType, "temple", "ladder")
end

local function generateRooms(level, rng, chooseTemplate, placeSymbol)
    for roomY = 0, 3 do
        for roomX = 0, 3 do
            local template, shopType = chooseTemplate(level, rng, roomX, roomY)
            local expanded = expandObstacles(level.area, template, rng)
            local origin = level.roomOrigins[roomY + 1][roomX + 1]
            level.roomTemplates[roomY + 1][roomX + 1] = expanded
            for localY = 0, 7 do
                for localX = 0, 9 do
                    local index = localY * 10 + localX + 1
                    placeSymbol(level, rng, expanded:sub(index, index), origin.x + localX,
                        origin.y + localY, roomX, roomY, shopType)
                end
            end
        end
    end
end

local function sameStyle(level, x, y, style)
    local tile = getTile(level, x, y)
    return tile and tile.kind == "solid" and (tile.baseStyle or tile.style) == style
end

local function applySurfaces(level, rng)
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = getTile(level, x, y)
            if tile and tile.kind == "solid" then
                local base = tile.baseStyle or tile.style
                if base == "ice" then
                    local up = sameStyle(level, x, y - 1, base)
                    local down = sameStyle(level, x, y + 1, base)
                    local left = sameStyle(level, x - 1, y, base)
                    local right = sameStyle(level, x + 1, y, base)
                    if not up then tile.style = "ice_up" end
                    if not down then tile.style = not up and "ice_up2" or "ice_down" end
                    if not left then
                        if not up and not down then tile.style = "ice_udl"
                        elseif not up then tile.style = "ice_ul"
                        elseif not down then tile.style = "ice_dl"
                        else tile.style = "ice_left" end
                    end
                    if not right then
                        if not up and not down then tile.style = "ice_udr"
                        elseif not up then tile.style = "ice_ur"
                        elseif not down then tile.style = "ice_dr"
                        else tile.style = "ice_right" end
                    end
                    if not up and not left and not right and down then tile.style = "ice_ulr" end
                    if not down and not left and not right and up then tile.style = "ice_dlr" end
                    if up and down and not left and not right then tile.style = "ice_lr" end
                    if not up and not down and not left and not right then tile.style = "ice_block" end
                elseif base == "temple" then
                    local up = sameStyle(level, x, y - 1, base)
                    local down = sameStyle(level, x, y + 1, base)
                    local left = sameStyle(level, x - 1, y, base)
                    local right = sameStyle(level, x + 1, y, base)
                    if not up then
                        tile.style = "temple_up"
                        if not left and not right then tile.style = not down and "temple_up6" or "temple_up5"
                        elseif not left then tile.style = not down and "temple_up7" or "temple_up3"
                        elseif not right then tile.style = not down and "temple_up8" or "temple_up4"
                        elseif not down then tile.style = "temple_up2" end
                    elseif not down then tile.style = "temple_down" end
                elseif base == "jungle" or base == "dark" then
                    local up = sameStyle(level, x, y - 1, base)
                    local down = sameStyle(level, x, y + 1, base)
                    if not up and not down then tile.style = base .. "_up2"
                    elseif not up then tile.style = base .. "_up"
                    elseif not down then tile.style = base .. "_down" end
                end
            elseif tile and tile.kind == "liquid" then
                local above = getTile(level, x, y - 1)
                local base = tile.baseStyle or tile.style
                if not above or above.kind ~= "liquid" or (above.baseStyle or above.style) ~= base then
                    tile.style = base .. "_top"
                elseif base == "water" then
                    local below = getTile(level, x, y + 1)
                    if below and isSolid(below) then
                        local twoAbove = getTile(level, x, y - 2)
                        if twoAbove and twoAbove.kind == "liquid" and rng:integer(1, 4) == 1 then
                            above.style = "water_bottom_tall1"
                            tile.style = "water_bottom_tall2"
                        else
                            local variant = rng:integer(1, 4)
                            tile.style = "water_bottom" .. (variant == 1 and "" or tostring(variant))
                        end
                    end
                end
            end
        end
    end
end

local function makeRoomOrigins(olmec)
    local origins = { {}, {}, {}, {} }
    for y = 0, 3 do
        for x = 0, 3 do
            origins[y + 1][x + 1] = {
                x = 1 + x * 10,
                y = olmec and (y == 3 and 37 or 1 + y * 8) or 1 + y * 8,
            }
        end
    end
    return origins
end

local function generateOlmec(level, rng)
    local templates = Data.olmec.templates
    for roomY = 0, 3 do
        for roomX = 0, 3 do
            local sourceIndex = roomY == 3 and rng:integer(8, 13) or rng:integer(2, 7)
            local expanded = expandObstacles("olmec", templates[sourceIndex], rng)
            local origin = level.roomOrigins[roomY + 1][roomX + 1]
            level.roomTemplates[roomY + 1][roomX + 1] = expanded
            for localY = 0, 7 do
                for localX = 0, 9 do
                    local symbol = expanded:sub(localY * 10 + localX + 1, localY * 10 + localX + 1)
                    local x = origin.x + localX
                    local y = origin.y + localY
                    if symbol == "1" and not isSolid(getTile(level, x, y)) then
                        setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "block" or "temple")
                    elseif symbol == "2" and rng:integer(1, 2) == 1 and not isSolid(getTile(level, x, y)) then
                        setTile(level, x, y, "solid", rng:integer(1, 10) == 1 and "block" or "temple")
                    elseif symbol == "L" then
                        setTile(level, x, y, "ladder", "vine")
                    elseif symbol == "P" then
                        setTile(level, x, y, "ladder_top", "vine")
                    elseif symbol == "7" and rng:integer(1, 3) == 1 then
                        addEntity(level, "spikes", x, y)
                    elseif symbol == "4" and rng:integer(1, 4) == 1 then
                        setTile(level, x, y, "push_block", "block")
                    elseif symbol == "a" then
                        addEntity(level, "chest", x, y)
                    elseif symbol == "T" then
                        if rng:integer(1, 15) == 1 then addEntity(level, "chest", x, y)
                        elseif rng:integer(1, 6) == 1 then addEntity(level, "gold_bars", x, y)
                        elseif rng:integer(1, 6) == 1 then addEntity(level, "emerald_big", x, y)
                        elseif rng:integer(1, 8) == 1 then addEntity(level, "sapphire_big", x, y)
                        elseif rng:integer(1, 10) == 1 then addEntity(level, "ruby_big", x, y)
                        elseif rng:integer(1, 10) == 1 then addEntity(level, "crate", x, y)
                        elseif rng:integer(1, 10) == 1 then setTile(level, x, y, "solid", "block")
                        else setTile(level, x, y, "solid", "temple") end
                    elseif symbol == "t" then
                        addEntity(level, "thwomp_trap", x, y)
                    elseif symbol == "I" then
                        addEntity(level, "gold_idol", x + 1, y)
                    elseif symbol == "C" then
                        addEntity(level, "ceiling_trap", x, y)
                    elseif symbol == "D" then
                        addEntity(level, "door", x, y)
                    elseif symbol == "w" then
                        setTile(level, x, y, "liquid", "water")
                    end
                end
            end
        end
    end

    for _, instance in ipairs(Data.olmecFixedInstances) do
        local x = math.floor(instance.x / 16)
        local y = math.floor(instance.y / 16)
        if instance.object == "oTemple" then
            setTile(level, x, y, "solid", "temple", { fixed = true })
        elseif instance.object == "oLava" then
            setTile(level, x, y, "liquid", "lava", { fixed = true })
        elseif instance.object == "oLavaSolid" then
            local tile = getTile(level, x, y)
            if tile then tile.properties.lavaSolid = true end
        elseif instance.object == "oEntrance" then
            addEntity(level, "entrance", x, y)
            if not level.entrance then level.entrance = { x = x, y = y } end
        elseif instance.object == "oOlmec" then
            addEntity(level, "olmec", x, y)
        elseif instance.object == "oCavemanWorship" or instance.object == "oHawkmanWorship" then
            addEntity(level, "worshipper", x, y,
                { role = instance.object == "oHawkmanWorship" and "hawkman" or "caveman" })
        end
    end
end

function ClassicAreaGenerator.generate(area, seed, options)
    options = options or {}
    local config = assert(AREA_CONFIG[area], "Unknown classic area: " .. tostring(area))
    local depth = math.max(1, math.min(config.depthCount, options.levelNumber or 1))
    local rng = newRandom(seed)
    local level = {
        area = area,
        seed = seed,
        levelNumber = depth,
        absoluteLevel = config.levelOffset + depth,
        width = WIDTH,
        height = config.height,
        tileSize = 16,
        tiles = makeGrid(WIDTH, config.height, function() return { kind = "empty" } end),
        entities = {},
        decorations = {},
        roomPath = newRoomPath(),
        roomTemplates = { {}, {}, {}, {} },
        roomOrigins = makeRoomOrigins(area == "olmec"),
        hasAltar = false,
        hasIdol = false,
        hasDamsel = false,
        hasShop = false,
    }

    buildBorder(level)
    if area == "olmec" then
        generateOlmec(level, rng)
    else
        generatePath(level, rng)
        addShop(level, rng)
        if area == "jungle" then
            level.hasCemetery = rng:integer(1, 10) == 1
            generateRooms(level, rng, chooseJungle, placeJungle)
        elseif area == "ice" then
            generateRooms(level, rng, chooseIce, placeIce)
        else
            generateRooms(level, rng, chooseTemple, placeTemple)
        end
    end
    EntityGenerator.populate(level, rng)
    applySurfaces(level, rng)
    return level
end

function ClassicAreaGenerator.getConfig(area)
    return AREA_CONFIG[area]
end

return ClassicAreaGenerator
