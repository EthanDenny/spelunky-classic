local MinesGenerator = require("src.world.mines_generator")
local RunState = require("src.game.run_state")

local Selection = {}

Selection.choices = {
    { key = "random", label = "Random" },
    { key = "standard", label = "Standard" },
    { key = "idol", label = "Idol" },
    { key = "altar", label = "Kali Altar", minDepth = 2 },
    { key = "snake_pit", label = "Snake Pit" },
    { key = "shop", label = "Shop", minDepth = 2 },
    { key = "dark", label = "Dark", minDepth = 2 },
}

local MAX_SEED = 2147483646
local MAX_ATTEMPTS = 512

function Selection.nextSeed(seed)
    return (seed % MAX_SEED) + 1
end

function Selection.requiredDepth(key)
    for _, choice in ipairs(Selection.choices) do
        if choice.key == key then return choice.minDepth or 1 end
    end
    error("Unknown Mines level type: " .. tostring(key))
end

function Selection.matches(level, key)
    if key == "random" then return true end
    if key == "standard" then
        return not (level.hasIdol or level.hasAltar or level.hasSnakePit
            or level.hasShop or level.dark)
    end
    if key == "idol" then return level.hasIdol end
    if key == "altar" then return level.hasAltar end
    if key == "snake_pit" then return level.hasSnakePit end
    if key == "shop" then return level.hasShop end
    if key == "dark" then return level.dark end
    error("Unknown Mines level type: " .. tostring(key))
end

-- Select an ordinary Classic-generated seed; never inject rooms or alter its RNG.
-- The fresh run is only a probe for dark-level eligibility. Live play applies
-- the accepted seed to its own run state afterward.
function Selection.find(startSeed, depth, key)
    assert(depth >= Selection.requiredDepth(key),
        "Mines level type " .. key .. " is unavailable at depth " .. depth)
    local seed = startSeed
    for _ = 1, MAX_ATTEMPTS do
        local level = MinesGenerator.generate(seed, { levelNumber = depth, run = RunState.new(seed) })
        if Selection.matches(level, key) then return seed, level end
        seed = Selection.nextSeed(seed)
    end
    return nil, nil, "No " .. key .. " Mines level found in " .. MAX_ATTEMPTS .. " seeds"
end

return Selection
