-- scrShopItemsGen and scrGenerateItem's high-end set. Rolls are sequential,
-- not uniform choices from the list of possible merchandise.
local Stock = {}
local highEnd = {
    { "jetpack", 40 }, { "cape", 25 }, { "shotgun", 20 },
    { "gloves", 10 }, { "teleporter", 10 }, { "mattock", 8 },
    { "paste", 8 }, { "spring_shoes", 8 }, { "spike_shoes", 8 },
    { "compass", 8 }, { "pistol", 8 }, { "machete", 8 },
}
local clothing = { "spring_shoes", "spectacles", "gloves", "mitt", "cape", "spike_shoes" }
local rare = { "spring_shoes", "compass", "mattock", "spectacles", "jetpack",
    "gloves", "mitt", "web_cannon", "cape", "teleporter", "spike_shoes" }
local weapons = { "pistol", "machete", "bomb_bag", "bow" }
local general = { "bomb_bag", "rope_pile", "parachute" }

local function roll(random, maximum)
    if random.integer then return random:integer(1, maximum) end
    return random:random(1, maximum)
end

function Stock.prize(random)
    for _, choice in ipairs(highEnd) do
        if roll(random, choice[2]) == 1 then return choice[1] end
    end
    return "bomb_box"
end

local function exists(level, kind)
    for _, entity in ipairs(level.entities) do
        if entity.kind == kind then return true end
    end
    return false
end

function Stock.choose(level, random, style)
    local attempts = 20
    while true do
        local kind
        if style == "Bomb" then
            if roll(random, 5) == 1 then kind = "paste"
            elseif roll(random, 4) == 1 then return "bomb_box"
            else return "bomb_bag" end
        elseif style == "Weapon" then
            local index = roll(random, 4)
            if attempts <= 0 then return "bomb_bag"
            elseif roll(random, 12) == 1 then kind = "web_cannon"
            elseif roll(random, 10) == 1 then kind = "shotgun"
            elseif roll(random, 6) == 1 then return "bomb_box"
            else kind = weapons[index] end
        elseif style == "Clothing" or style == "Rare" then
            local choices = style == "Clothing" and clothing or rare
            local index = roll(random, #choices)
            if roll(random, attempts) == 1 then
                return style == "Clothing" and "rope_pile" or "bomb_box"
            end
            kind = choices[index]
        else
            local index = roll(random, 3)
            if roll(random, 20) == 1 then kind = "mattock"
            elseif roll(random, 10) == 1 then kind = "gloves"
            elseif roll(random, 10) == 1 then kind = "compass"
            else return general[index] end
        end
        if kind == "bomb_bag" or not exists(level, kind) then return kind end
        if style == "Weapon" or style == "Clothing" or style == "Rare" then
            attempts = attempts - 1
        end
    end
end

return Stock
