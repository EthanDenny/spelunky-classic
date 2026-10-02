local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ flight = "fragile", hold = { standing = 0, ducking = 4 },
    breakOnImpact = { wall = 2, ceiling = 0, floor = 3, effect = "skull" } })

Definition.depth = 100

Definition.breakOnBullet = true

return Definition
