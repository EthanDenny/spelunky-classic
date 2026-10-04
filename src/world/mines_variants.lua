local MinesVariants = {}

local function darkRoll(seed, depth)
    local value = (math.floor(seed or 1) * 1103515245 + depth * 17 * 12345) % 2147483647
    return value / 2147483647
end

local function solid(value)
    return value and (value.kind == "solid" or value.kind == "brick"
        or value.kind == "block" or value.kind == "smooth_brick"
        or value.kind == "push_block")
end

function MinesVariants.apply(level, run, forceDark)
    local depth = level.levelNumber or 1
    level.dark = depth > 1 and (forceDark or not run.hadDarkLevel
        and darkRoll(level.seed, depth) < (1 / 12))
    if not level.dark then return level end

    run.hadDarkLevel = true
    local random = love.math.newRandomGenerator(level.seed + depth*17)
    for y = 2, level.height-3 do
        for x = 2, level.width-3 do
            local tile = level.tiles[y+1] and level.tiles[y+1][x+1]
            local below = level.tiles[y+2] and level.tiles[y+2][x+1]
            local lower = level.tiles[y+3] and level.tiles[y+3][x+1]
            if solid(tile) and not solid(below) and not solid(lower) then
                local kind = random:random(1,60) == 1 and "lamp"
                    or random:random(1,40) == 1 and "scarab"
                if kind then
                    local blocked = false
                    for _, entity in ipairs(level.entities) do
                        if entity.x == x and entity.y == y+1
                            and entity.kind ~= "bat" and entity.kind ~= "spider" then blocked = true end
                    end
                    if not blocked then
                        for index = #level.entities, 1, -1 do
                            local entity = level.entities[index]
                            if entity.x == x and entity.y == y+1
                                and (entity.kind == "bat" or entity.kind == "spider") then
                                table.remove(level.entities, index)
                            end
                        end
                        level.entities[#level.entities+1] = { kind = kind, x = x, y = y+1, properties = {} }
                    end
                end
            end
        end
    end
    return level
end

return MinesVariants
