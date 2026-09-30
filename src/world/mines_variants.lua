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

function MinesVariants.apply(level, run)
    local depth = level.levelNumber or 1
    level.dark = depth > 1 and not run.hadDarkLevel
        and darkRoll(level.seed, depth) < (1 / 12)
    if not level.dark then return level end

    run.hadDarkLevel = true
    for y = 2, level.height - 2 do
        for x = 2, level.width - 3 do
            local row = level.tiles[y + 1]
            local tile = row and row[x + 1]
            local above = level.tiles[y] and level.tiles[y][x + 1]
            local rightAbove = level.tiles[y] and level.tiles[y][x + 2]
            if solid(tile) and not solid(above) and not solid(rightAbove) then
                level.entities[#level.entities + 1] = { kind = "lamp", x = x, y = y - 1, properties = {} }
                level.entities[#level.entities + 1] = {
                    kind = "scarab", x = math.min(level.width - 2, x + 5), y = y - 2,
                    properties = {},
                }
                return level
            end
        end
    end
    return level
end

return MinesVariants
