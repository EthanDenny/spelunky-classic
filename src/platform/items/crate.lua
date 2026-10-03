local Traits = require("src.platform.item_traits")

local crateLoot = {
    { odds = 500, kind = "jetpack" }, { odds = 200, kind = "cape" },
    { odds = 100, kind = "shotgun" }, { odds = 100, kind = "mattock" },
    { odds = 100, kind = "teleporter" }, { odds = 90, kind = "gloves" },
    { odds = 90, kind = "spectacles" }, { odds = 80, kind = "web_cannon" },
    { odds = 80, kind = "pistol" }, { odds = 80, kind = "mitt" },
    { odds = 60, kind = "paste" }, { odds = 60, kind = "spring_shoes" },
    { odds = 60, kind = "spike_shoes" }, { odds = 60, kind = "machete" },
    { odds = 40, kind = "bomb_box" }, { odds = 40, kind = "bow" },
    { odds = 20, kind = "compass" }, { odds = 10, kind = "parachute" },
    { odds = 2, kind = "rope_pile" },
}

local Definition = Traits.carry({ heavy = true, bounds = { 6, 0, 8 }, action = "open",
    container = { mode = "chain", rolls = crateLoot, fallback = "bomb_bag",
        effect = "smoke" } })

Definition.depth = 900

return Definition
