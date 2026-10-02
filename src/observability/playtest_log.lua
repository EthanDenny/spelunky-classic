-- A write-through record of human playtests. This observes the live game; it
-- is deliberately not a replay format or a second simulation implementation.
local PlaytestLog = {}
PlaytestLog.__index = PlaytestLog

local DIRECTORY = "playtest-logs"
local CELL_KINDS = { "solid", "moveableSolid", "platform", "ladder", "ladderTop", "rope", "web" }
local PLAYER_FIELDS = {
    "x", "y", "vx", "vy", "ax", "ay", "xRemainder", "yRemainder", "tick",
    "state", "statePrev", "statePrevPrev", "status", "health", "maxHealth", "facing",
    "leftHeldSteps", "rightHeldSteps", "runHeld", "pushTimer", "jumpTime", "jumpReleased",
    "gravity", "gravityIntensity", "xVelocityLimit", "yVelocityLimit", "climbKind",
    "climbTileX", "hangTileX", "hangTileY", "transitionTicks", "transitionTarget",
    "hangCooldown", "ladderCooldown", "dropThroughTimer", "invincibleTimer", "stunTimer",
    "webTimer", "fallTimer", "parachuteOpen", "jetpackFuel", "deadBounced", "whipping",
    "whipCracked", "whipJustCracked", "attackPressedThisStep", "spriteName",
    "animationFrame", "wideCollision", "collisionTopOffset",
}
local ENTITY_FIELDS = {
    "kind", "x", "y", "vx", "vy", "state", "phase", "frame", "health", "hp", "alive", "facing", "timer",
    "stunTimer", "stunned", "safeTimer", "cooldown", "held", "corpse", "sacrificed",
    "sacrificeTicks", "opened", "targetX", "falling",
    "moveable", "width", "height", "age", "life", "radius", "damage", "stuck", "sticky",
    "durability", "attackTimer", "alertTimer", "angry", "heavy",
    "spriteName", "animation", "imageSpeed", "squirtTimer",
    "deploying", "deployed", "deployY", "segmentCount",
}
local RUN_FIELDS = {
    "seed", "health", "maxHealth", "bombs", "ropes", "money", "time", "kills",
    "damsels", "shopkeeperAnger", "thief", "murderer", "favor", "kaliGift", "kaliPunish", "blood",
    "hasKey", "heldCreature", "hadDarkLevel",
}

local function copyFields(source, fields)
    if not source then return nil end
    local result = {}
    for _, field in ipairs(fields) do
        local value = source[field]
        if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
            result[field] = value
        end
    end
    return result
end

local function copyFlags(source)
    local result = {}
    for key, value in pairs(source or {}) do
        if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
            result[key] = value
        end
    end
    return result
end

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function quote(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return ESCAPES[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function encode(value, seen)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "string" then return quote(value) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "null" end
        if value == 0 then return "0" end
        return string.format("%.17g", value)
    end
    if kind ~= "table" then return quote(tostring(value)) end
    seen = seen or {}
    if seen[value] then error("cyclic playtest log record") end
    seen[value] = true
    local length, array = 0, true
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then array = false break end
        if key > length then length = key end
    end
    if length == 0 then array = false end
    if array then
        local result = {}
        for index = 1, length do result[index] = encode(value[index], seen) end
        seen[value] = nil
        return "[" .. table.concat(result, ",") .. "]"
    end
    local keys, result = {}, {}
    for key in pairs(value) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    for _, key in ipairs(keys) do result[#result + 1] = quote(key) .. ":" .. encode(value[key], seen) end
    seen[value] = nil
    return "{" .. table.concat(result, ",") .. "}"
end

local function entityList(source)
    local result = {}
    for index, entity in ipairs(source or {}) do
        local state = copyFields(entity, ENTITY_FIELDS)
        state.index = index
        result[#result + 1] = state
    end
    return result
end

local function localCells(world, player)
    local result = {}
    local centerX = math.floor(player.x / world.tileSize)
    local centerY = math.floor(player.y / world.tileSize)
    for y = centerY - 4, centerY + 4 do
        for x = centerX - 4, centerX + 4 do
            local present = {}
            for _, kind in ipairs(CELL_KINDS) do
                if world:has(kind, x, y) then present[#present + 1] = kind end
            end
            if #present > 0 then result[#result + 1] = { x = x, y = y, kinds = present } end
        end
    end
    return result
end

function PlaytestLog.capture(screen)
    local player, world = screen.player, screen.world
    local result = {
        seed = screen.seed,
        levelNumber = screen.levelNumber,
        subtype = screen.level and screen.level.selectedSubtype,
        levelTime = screen.levelTime,
        deathTimer = screen.deathTimer,
        exitReady = screen.exitReady,
        kills = screen.kills,
        pageIndex = screen.pageIndex,
        facing = screen.facing,
        elapsed = screen.elapsed,
        scrollY = screen.scrollY,
        showRoomPath = screen.showRoomPath,
    }
    if screen.selector then
        local selected = screen.selector:getSelected()
        result.selectedArea = selected and selected.key
    end
    if player then
        result.player = copyFields(player, PLAYER_FIELDS)
        result.player.equipment = copyFlags(player.equipment)
        result.player.previousInput = copyFlags(player.previousInput)
    end
    if world then
        result.worldTime = world.time
        result.dynamicSolids = entityList(world.dynamicSolids)
        if player then result.nearbyCells = localCells(world, player) end
    end
    if screen.run then
        result.run = copyFields(screen.run, RUN_FIELDS)
        result.run.equipment = copyFlags(screen.run.equipment)
        result.run.visited = copyFlags(screen.run.visited)
        result.run.heldItem = screen.run.heldItem and copyFields(screen.run.heldItem, ENTITY_FIELDS)
        result.run.messages = {}
        for index, message in ipairs(screen.run.messages or {}) do
            result.run.messages[index] = { text = message.text, timer = message.timer }
        end
    end
    if screen.enemies then result.enemies = entityList(screen.enemies) end
    if screen.scenarios then
        result.scenarios = {}
        for index, scenario in ipairs(screen.scenarios) do
            result.scenarios[index] = {
                name = scenario.definition.title,
                tick = scenario.tick,
                runs = scenario.runs,
                event = scenario.event,
                enemy = copyFields(scenario.enemy, ENTITY_FIELDS),
                player = copyFields(scenario.player, PLAYER_FIELDS),
            }
            if scenario.tools then
                result.scenarios[index].ropesRemaining = scenario.ropesRemaining
                result.scenarios[index].ropes = entityList(scenario.tools.ropes)
            end
        end
    end
    if screen.items then result.items = entityList(screen.items) end
    if screen.fakeBones then result.fakeBones = entityList(screen.fakeBones) end
    if screen.spikeEntities then
        result.spikes = {}
        for index, spike in ipairs(screen.spikeEntities) do
            result.spikes[index] = { x = spike.x, y = spike.y,
                bloody = not not spike.bloody, destroyed = not not spike.destroyed }
        end
    end
    if screen.effects then result.effects = entityList(screen.effects.particles) end
    if screen.collectibles then
        result.collectibles = {}
        for index, collectible in ipairs(screen.collectibles) do
            result.collectibles[index] = {
                kind = collectible.entity.kind, x = collectible.entity.x,
                y = collectible.entity.y, alive = collectible.alive,
                vx = collectible.vx, vy = collectible.vy,
                active = collectible.active, pickupDelay = collectible.pickupDelay,
            }
        end
    end
    if screen.tools then
        result.tools = {
            bombs = entityList(screen.tools.bombs),
            ropes = entityList(screen.tools.ropes),
            explosions = entityList(screen.tools.explosions),
        }
    end
    if screen.projectiles then result.projectiles = entityList(screen.projectiles.projectiles) end
    if screen.traps then
        result.traps = {}
        for _, kind in ipairs({ "boulders", "projectiles", "springs", "thwomps" }) do
            if screen.traps[kind] then result.traps[kind] = entityList(screen.traps[kind]) end
        end
    end
    return result
end

local function worldCells(world)
    local result = {}
    for _, kind in ipairs(CELL_KINDS) do
        local cells = {}
        for key in pairs(world[kind]) do cells[#cells + 1] = key end
        table.sort(cells)
        result[kind] = cells
    end
    return result
end

local function sourceFingerprint()
    local files = { "main.lua", "conf.lua" }
    local function visit(directory)
        for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
            local path = directory .. "/" .. name
            local info = love.filesystem.getInfo(path)
            if info and info.type == "directory" then
                visit(path)
            elseif name:match("%.lua$") then
                files[#files + 1] = path
            end
        end
    end
    visit("src")
    table.sort(files)
    local parts = {}
    for _, path in ipairs(files) do
        local contents = assert(love.filesystem.read(path))
        parts[#parts + 1] = path .. "\0" .. contents .. "\0"
    end
    local digest = love.data.hash("sha256", table.concat(parts))
    return love.data.encode("string", "hex", digest)
end

function PlaytestLog:level(screenName, screen)
    if not screen.world then return end
    local level = screen.level
    local entities = {}
    for index, entity in ipairs(level and level.entities or {}) do
        entities[index] = { kind = entity.kind, x = entity.x, y = entity.y }
    end
    self:record("level", {
        screen = screenName,
        seed = screen.seed,
        area = level and level.area,
        depth = screen.levelNumber,
        subtype = level and level.selectedSubtype,
        width = screen.world.width,
        height = screen.world.height,
        tileSize = screen.world.tileSize,
        cells = worldCells(screen.world),
        entities = entities,
        state = PlaytestLog.capture(screen),
    })
    screen.world.playtestLog = self
end

function PlaytestLog:generatedLevel(screenName, level, depth)
    local rows, entities = {}, {}
    for y, row in ipairs(level.tiles or {}) do
        rows[y] = {}
        for x, tile in ipairs(row) do rows[y][x] = tile.kind or "empty" end
    end
    for index, entity in ipairs(level.entities or {}) do
        entities[index] = { kind = entity.kind, x = entity.x, y = entity.y }
    end
    self:record("generation", { screen = screenName, area = level.area,
        seed = level.seed, depth = depth, subtype = level.selectedSubtype,
        tiles = rows, entities = entities })
end

function PlaytestLog:tick(screenName, input, before, screen)
    local after = PlaytestLog.capture(screen)
    local changes = {}
    local oldPlayer, newPlayer = before.player, after.player
    if oldPlayer and newPlayer then
        for _, field in ipairs({ "state", "status", "health", "climbKind", "whipping" }) do
            if oldPlayer[field] ~= newPlayer[field] then
                changes[#changes + 1] = { field = "player." .. field, from = oldPlayer[field], to = newPlayer[field] }
            end
        end
        if newPlayer.whipJustCracked then changes[#changes + 1] = { event = "whip_cracked" } end
    end
    self:record("tick", { screen = screenName, input = input, before = before, after = after, changes = changes })
end

function PlaytestLog:tickStart(screenName, input, before)
    self:record("tick_start", { screen = screenName, input = input,
        player = before.player, worldTime = before.worldTime,
        nearbyCells = before.nearbyCells })
end

function PlaytestLog:record(kind, details)
    if not self.file then return false end
    self.sequence = self.sequence + 1
    local entry = { version = 1, session = self.id, sequence = self.sequence,
        elapsed = love.timer.getTime() - self.started, type = kind, details = details or {} }
    local ok, line = pcall(encode, entry)
    if ok then
        local written, err = self.file:write(line .. "\n")
        if written then written, err = self.file:flush() end
        if written then return true end
        line = err
    end
    io.stderr:write("Playtest logging stopped: " .. tostring(line) .. "\n")
    self.file:close()
    self.file = nil
    return false
end

function PlaytestLog:mark(screenName, screen)
    self:record("bookmark", { screen = screenName, state = screen and PlaytestLog.capture(screen) })
end

function PlaytestLog:close()
    if not self.file then return end
    self:record("session_end")
    if self.file then self.file:close() self.file = nil end
end

function PlaytestLog.start()
    local created, err = love.filesystem.createDirectory(DIRECTORY)
    if not created then
        io.stderr:write("Playtest logging unavailable: " .. tostring(err) .. "\n")
        return nil
    end
    local base = os.date("!%Y%m%dT%H%M%SZ") .. "-" .. tostring(math.floor(love.timer.getTime() * 1000000) % 1000000000)
    local id, suffix = base, 0
    while love.filesystem.getInfo(DIRECTORY .. "/" .. id .. ".jsonl") do
        suffix = suffix + 1
        id = base .. "-" .. suffix
    end
    local relativePath = DIRECTORY .. "/" .. id .. ".jsonl"
    local file = love.filesystem.newFile(relativePath)
    local opened, openError = file:open("w")
    if not opened then
        io.stderr:write("Playtest logging unavailable: " .. tostring(openError) .. "\n")
        return nil
    end
    local self = setmetatable({ id = id, path = relativePath, file = file,
        sequence = 0, started = love.timer.getTime() }, PlaytestLog)
    local major, minor, revision = love.getVersion()
    if not self:record("session_start", { startedUtc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        source = love.filesystem.getSource(), saveDirectory = love.filesystem.getSaveDirectory(),
        sourceFingerprint = sourceFingerprint(),
        loveVersion = string.format("%d.%d.%d", major, minor, revision),
        os = love.system.getOS() }) then return nil end
    local saved, saveError = love.filesystem.write(DIRECTORY .. "/latest.txt", relativePath .. "\n")
    if not saved then io.stderr:write("Could not update latest playtest pointer: " .. tostring(saveError) .. "\n") end
    return self
end

return PlaytestLog
