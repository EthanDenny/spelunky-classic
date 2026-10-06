local Templates = require("src.world.mines_templates")
local EntityGenerator = require("src.world.entity_generator")
local MinesVariants = require("src.world.mines_variants")
local RunState = require("src.game.run_state")

local Tiles = require("src.platform.tiles.types")

local MinesGenerator = {}

local LEVEL_WIDTH = 42
local LEVEL_HEIGHT = 34
local ROOM_COLUMNS = 4
local ROOM_ROWS = 4
local ROOM_WIDTH = 10
local ROOM_HEIGHT = 8

local function newRandom(seed)
    local source = love.math.newRandomGenerator(seed)

    return {
        integer = function(_, minimum, maximum)
            return source:random(minimum, maximum)
        end,
    }
end

local function makeGrid(width, height)
    local grid = {}

    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = { kind = "empty" }
        end
    end

    return grid
end

local function getTile(level, x, y)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then
        return nil
    end

    return level.tiles[y + 1][x + 1]
end

local function setTile(level, x, y, tile)
    if x < 0 or x >= level.width or y < 0 or y >= level.height then
        return
    end

    level.tiles[y + 1][x + 1] = tile
end

local function isBrick(tile)
    return tile and tile.kind == "brick"
end

local function isSolid(tile)
    if not tile then
        return false
    end

    return Tiles[tile.kind] and Tiles[tile.kind].solid or false
end

local function addEntity(level, kind, x, y, properties)
    level.entities[#level.entities + 1] = {
        kind = kind,
        x = x,
        y = y,
        properties = properties or {},
    }
end

local function addBackdrop(level, kind, x, y, variant)
    level.backdrops[#level.backdrops + 1] = {
        kind = kind,
        x = x,
        y = y,
        variant = variant,
    }
end

local function createBrick(level, rng, x, y, options)
    options = options or {}

    local style = "brick"
    if rng:integer(1, 10) == 1 then
        style = "brick_alt"
    end

    local contentsRoll = rng:integer(1, 100)
    if contentsRoll < 20 then
        style = "brick_gold"
    elseif contentsRoll < 30 then
        style = "brick_gold_big"
    elseif x >= 1 and x <= 40 and y >= 1 and y <= 32 then
        if rng:integer(1, 100) == 1 then
            addEntity(level, "hidden_sapphire", x, y)
        elseif rng:integer(1, 120) == 1 then
            addEntity(level, "hidden_emerald", x, y)
        elseif rng:integer(1, 140) == 1 then
            addEntity(level, "hidden_ruby", x, y)
        elseif rng:integer(1, 1200) == 1 then
            addEntity(level, "hidden_item", x, y)
        end
    end

    if options.forceNormal then
        style = "brick"
    end

    setTile(level, x, y, {
        kind = "brick",
        style = style,
        invincible = options.invincible or false,
        shopWall = options.shopWall or false,
    })
end

local function createBlock(level, x, y, kind)
    setTile(level, x, y, { kind = kind or "block" })
end

local function buildBorder(level, rng)
    -- scrInitLevel iterates one column beyond room_width. We consume those brick
    -- creation rolls too, while only storing the visible 42 x 34 tile room.
    for x = 0, 42 do
        for y = 0, 33 do
            if x == 0 or x == 41 or y == 0 or y == 33 then
                createBrick(level, rng, x, y, { forceNormal = true, invincible = true })
            end
        end
    end
end

local function newRoomPath()
    local path = {}
    for y = 1, ROOM_ROWS do
        path[y] = { 0, 0, 0, 0 }
    end
    return path
end

local function getRoom(path, x, y)
    if x < 0 or x >= ROOM_COLUMNS or y < 0 or y >= ROOM_ROWS then
        return 0
    end
    return path[y + 1][x + 1]
end

local function setRoom(path, x, y, value)
    if x >= 0 and x < ROOM_COLUMNS and y >= 0 and y < ROOM_ROWS then
        path[y + 1][x + 1] = value
    end
end

local function generateRoomPath(level, rng)
    local path = level.roomPath
    local roomX = rng:integer(0, 3)
    local roomY = 0
    local previousX = roomX
    local previousY = 0

    level.startRoomX = roomX
    level.startRoomY = 0
    setRoom(path, roomX, roomY, 1)

    -- scrLevelGen initializes this roll before its area-specific branches. It is
    -- unused by mines, but remains part of the original random-call sequence.
    rng:integer(0, 3)

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
                if getRoom(path, roomX - 1, roomY) == 0 then
                    roomX = roomX - 1
                end
            elseif roomX < 3 then
                if getRoom(path, roomX + 1, roomY) == 0 then
                    roomX = roomX + 1
                end
            else
                direction = 5
            end
        elseif direction == 3 or direction == 4 then
            if roomX < 3 then
                if getRoom(path, roomX + 1, roomY) == 0 then
                    roomX = roomX + 1
                end
            elseif roomX > 0 then
                if getRoom(path, roomX - 1, roomY) == 0 then
                    roomX = roomX - 1
                end
            else
                direction = 5
            end
        end

        if direction == 5 then
            roomY = roomY + 1
            movedDown = true

            if roomY < 4 then
                setRoom(path, previousX, previousY, 2)
                setRoom(path, roomX, roomY, 3)
            else
                level.endRoomX = roomX
                level.endRoomY = roomY - 1
            end
        end

        if not movedDown then
            setRoom(path, roomX, roomY, 1)
        end

        previousX = roomX
        previousY = roomY
    end

    for y = 0, 1 do
        for x = 0, 3 do
            if getRoom(path, x, y) == 0
                and getRoom(path, x, y + 1) == 0
                and getRoom(path, x, y + 2) == 0
                and rng:integer(1, 8) == 1 then
                setRoom(path, x, y, 7)
                setRoom(path, x, y + 1, 8)

                if y == 0 and getRoom(path, x, y + 3) == 0 then
                    setRoom(path, x, y + 2, 8)
                    setRoom(path, x, y + 3, 9)
                else
                    setRoom(path, x, y + 2, 9)
                end

                level.hasSnakePit = true
                return
            end
        end
    end
end

local function addShopToPath(level, rng)
    if level.levelNumber <= 1 or rng:integer(1, level.levelNumber) > 2 then
        return
    end

    local possibilities = {}
    for y = 0, 3 do
        for x = 0, 3 do
            if getRoom(level.roomPath, x, y) == 0 then
                if x < 3 then
                    local right = getRoom(level.roomPath, x + 1, y)
                    if right == 1 or right == 2 then
                        possibilities[#possibilities + 1] = { x = x, y = y, value = 4 }
                    end
                elseif x > 0 then
                    local left = getRoom(level.roomPath, x - 1, y)
                    if left == 1 or left == 2 then
                        possibilities[#possibilities + 1] = { x = x, y = y, value = 5 }
                    end
                end
            end
        end
    end

    if #possibilities > 0 then
        local choice = possibilities[rng:integer(1, #possibilities)]
        setRoom(level.roomPath, choice.x, choice.y, choice.value)
        level.hasShop = true
    end
end

local function resolveVariant(template, rng)
    if type(template) == "table" then
        return template[rng:integer(1, #template)]
    end
    return template
end

local function chooseShopTemplate(roomPath, rng)
    local shopTypeIndex = rng:integer(1, 7)
    local shopTypes = { "General", "Bomb", "Weapon", "Rare", "Clothing", "Craps", "Kissing" }
    local shopType = shopTypes[shopTypeIndex]

    if roomPath == 4 then
        if shopType == "Craps" then
            return Templates.shopLeftCraps, shopType
        elseif shopType == "Kissing" then
            return Templates.shopLeftKissing, shopType
        end
        return Templates.shopLeft, shopType
    end

    if shopType == "Craps" then
        return Templates.shopRightCraps, shopType
    elseif shopType == "Kissing" then
        return Templates.shopRightKissing, shopType
    end
    return Templates.shopRight, shopType
end

local function chooseRoomTemplate(level, rng, roomX, roomY)
    local roomPath = getRoom(level.roomPath, roomX, roomY)
    local roomPathAbove = roomY == 0 and -1 or getRoom(level.roomPath, roomX, roomY - 1)

    if roomX == level.startRoomX and roomY == level.startRoomY then
        local index = roomPath == 2 and rng:integer(5, 8) or rng:integer(1, 4)
        return Templates.start[index]
    elseif roomX == level.endRoomX and roomY == level.endRoomY then
        local index = roomPathAbove == 2 and rng:integer(2, 4) or rng:integer(3, 6)
        return Templates.finish[index]
    elseif roomPath == 0 then
        local index
        if level.levelNumber > 1 and not level.hasAltar and rng:integer(1, 16) == 1 then
            index = 11
            level.hasAltar = true
        elseif level.hasIdol or roomY == 3 then
            index = rng:integer(1, 9)
        else
            index = rng:integer(1, 10)
            if index == 10 then
                level.hasIdol = true
            end
        end
        return Templates.side[index]
    elseif roomPath == 1 then
        return resolveVariant(Templates.main[rng:integer(1, 12)], rng)
    elseif roomPath == 3 then
        return resolveVariant(Templates.enteredFromAbove[rng:integer(1, 8)], rng)
    elseif roomPath == 4 or roomPath == 5 then
        return chooseShopTemplate(roomPath, rng)
    elseif roomPath == 8 then
        return Templates.snakeMiddle
    elseif roomPath == 9 then
        return Templates.snakeBottom
    end

    local index
    if roomPath == 7 then
        index = rng:integer(4, 12)
    elseif roomPathAbove ~= 2 then
        index = rng:integer(1, 12)
    else
        index = rng:integer(1, 8)
    end
    return Templates.drop[index]
end

local function expandObstacles(template, rng)
    assert(#template == ROOM_WIDTH * ROOM_HEIGHT,
        "Invalid mines room template length: " .. tostring(#template))

    local characters = {}
    for index = 1, #template do
        characters[index] = template:sub(index, index)
    end

    for index = 1, #characters do
        local obstacleSet = Templates.obstacles[characters[index]]
        if obstacleSet then
            local obstacle = obstacleSet[rng:integer(1, #obstacleSet)]
            for row = 0, 2 do
                for column = 0, 4 do
                    characters[index + row * ROOM_WIDTH + column] = obstacle[row + 1]:sub(column + 1, column + 1)
                end
            end
        end
    end

    return table.concat(characters)
end

local function generateSymbol(level, rng, symbol, x, y, roomX, roomY, shopType)
    if symbol == "1" and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 10) == 1 then
            createBlock(level, x, y)
        else
            createBrick(level, rng, x, y)
        end
    elseif symbol == "2" and rng:integer(1, 2) == 1 and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 10) == 1 then
            createBlock(level, x, y)
        else
            createBrick(level, rng, x, y)
        end
    elseif symbol == "L" then
        setTile(level, x, y, { kind = "ladder" })
    elseif symbol == "P" then
        setTile(level, x, y, { kind = "ladder_top" })
    elseif symbol == "7" and rng:integer(1, 3) == 1 then
        addEntity(level, "spikes", x, y)
    elseif symbol == "4" and rng:integer(1, 4) == 1 then
        createBlock(level, x, y, "push_block")
    elseif symbol == "9" then
        createBrick(level, rng, x, y + 1, { invincible = roomX ~= level.startRoomX or roomY ~= level.startRoomY })
        if roomX == level.startRoomX and roomY == level.startRoomY then
            addEntity(level, "entrance", x, y)
            level.entrance = { x = x, y = y }
        else
            addEntity(level, "exit", x, y)
            level.exit = { x = x, y = y }
        end
    elseif symbol == "A" then
        addEntity(level, "altar_left", x, y)
        addEntity(level, "altar_right", x + 1, y)
    elseif symbol == "x" then
        addEntity(level, "sacrifice_altar", x, y)
        addBackdrop(level, "kali_body", x - 1, y - 3)
        addEntity(level, "kali_head", x + 1, y - 4,
            { variant = rng:integer(1, 3) })
    elseif symbol == "a" then
        addEntity(level, "chest", x, y)
    elseif symbol == "I" then
        addEntity(level, "gold_idol", x + 1, y + 0.75)
    elseif symbol == "B" then
        addEntity(level, "giant_tiki_head", x + 1, y + 0.75)
        addBackdrop(level, "tiki_body", x, y + 2)
        addBackdrop(level, "tiki_arm_right", x + 2, y + 2, rng:integer(0, 2))
        addBackdrop(level, "tiki_arm_left", x - 1, y + 2, rng:integer(0, 2))
    elseif symbol == "+" then
        createBlock(level, x, y)
    elseif symbol == "." and not isSolid(getTile(level, x, y)) then
        if rng:integer(1, 10) == 1 then
            createBlock(level, x, y)
        else
            createBrick(level, rng, x, y, { shopWall = true })
        end
    elseif symbol == "b" then
        setTile(level, x, y, { kind = "smooth_brick", shopWall = true })
    elseif symbol == "l" then
        addEntity(level, shopType == "Kissing" and "lamp_red" or "lamp", x, y)
    elseif symbol == "K" then
        addEntity(level, "shopkeeper", x, y, { shopType = shopType })
    elseif symbol == "k" then
        addEntity(level, "shop_sign", x, y, { shopType = shopType })
    elseif symbol == "i" or symbol == "q" then
        addEntity(level, "shop_item", x, y, { shopType = shopType, highEnd = symbol == "q" })
    elseif symbol == "d" then
        addEntity(level, "die", x + 0.5, y + 0.5)
    elseif symbol == "D" then
        addEntity(level, "damsel", x + 0.5, y + 0.5, { forSale = true })
        level.hasDamsel = true
    elseif symbol == "s" then
        if rng:integer(1, 10) == 1 then
            addEntity(level, "snake", x, y)
        elseif rng:integer(1, 2) == 1 then
            createBrick(level, rng, x, y)
        end
    elseif symbol == "S" then
        addEntity(level, "snake", x, y)
    elseif symbol == "T" then
        addEntity(level, "ruby_big", x + 0.5, y + 0.5)
    elseif symbol == "M" then
        createBrick(level, rng, x, y)
        addEntity(level, "mattock", x + 0.5, y + 0.5)
    end

    if symbol ~= "0" then
        level.symbols[y + 1][x + 1] = symbol
    end
end

local function generateRooms(level, rng)
    for roomY = 0, ROOM_ROWS - 1 do
        for roomX = 0, ROOM_COLUMNS - 1 do
            local template, shopType = chooseRoomTemplate(level, rng, roomX, roomY)
            local expanded = expandObstacles(template, rng)
            local originX = 1 + roomX * ROOM_WIDTH
            local originY = 1 + roomY * ROOM_HEIGHT

            level.roomTemplates[roomY + 1][roomX + 1] = expanded

            for localY = 0, ROOM_HEIGHT - 1 do
                for localX = 0, ROOM_WIDTH - 1 do
                    local index = localY * ROOM_WIDTH + localX + 1
                    generateSymbol(level, rng, expanded:sub(index, index),
                        originX + localX, originY + localY, roomX, roomY, shopType)
                end
            end
        end
    end
end

local function applyWallSprites(level, rng)
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = getTile(level, x, y)
            if isBrick(tile) then
                local up = y == 0 or isBrick(getTile(level, x, y - 1))
                local down = y >= 33 or isBrick(getTile(level, x, y + 1))

                if not up then
                    tile.style = down and "cave_up" or "cave_up2"
                    if level.graphicsHigh then level.decorations[#level.decorations + 1] = {
                        kind = "cave_top",
                        variant = rng:integer(1, 3) < 3 and 1 or 2,
                        x = x,
                        y = y - 1,
                    } end
                elseif not down then
                    tile.style = "brick_down"
                end
            end
        end
    end
end

local function validateTemplates()
    local groups = {
        Templates.start,
        Templates.finish,
        Templates.side,
        Templates.main,
        Templates.enteredFromAbove,
        Templates.drop,
    }

    local function validate(template)
        if type(template) == "table" then
            for _, variant in ipairs(template) do
                validate(variant)
            end
        else
            assert(#template == 80, "Mines template must contain 80 tiles, found " .. #template)
        end
    end

    for _, group in ipairs(groups) do
        validate(group)
    end

    validate(Templates.shopLeft)
    validate(Templates.shopLeftCraps)
    validate(Templates.shopLeftKissing)
    validate(Templates.shopRight)
    validate(Templates.shopRightCraps)
    validate(Templates.shopRightKissing)
    validate(Templates.snakeMiddle)
    validate(Templates.snakeBottom)
end

function MinesGenerator.generate(seed, options)
    options = options or {}
    validateTemplates()

    local rng = newRandom(seed)
    local level = {
        area = "mines",
        seed = seed,
        graphicsHigh = options.graphicsHigh ~= false,
        levelNumber = math.max(1, math.min(4, options.levelNumber or 1)),
        absoluteLevel = math.max(1, math.min(4, options.levelNumber or 1)),
        width = LEVEL_WIDTH,
        height = LEVEL_HEIGHT,
        tileSize = 16,
        tiles = makeGrid(LEVEL_WIDTH, LEVEL_HEIGHT),
        symbols = makeGrid(LEVEL_WIDTH, LEVEL_HEIGHT),
        entities = {},
        backdrops = {},
        decorations = {},
        roomPath = newRoomPath(),
        roomTemplates = { {}, {}, {}, {} },
        hasAltar = false,
        hasIdol = false,
        hasShop = false,
        hasSnakePit = false,
    }

    buildBorder(level, rng)
    generateRoomPath(level, rng)
    addShopToPath(level, rng)
    generateRooms(level, rng)
    applyWallSprites(level, rng)
    EntityGenerator.resolveRooms(level, rng)
    MinesVariants.apply(level, options.run or RunState.new(seed), rng, options.forceDark)
    EntityGenerator.populate(level, rng, options.run)

    return level
end

return MinesGenerator
