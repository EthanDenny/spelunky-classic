local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ heavy = true, hold = { standing = 0, ducking = 2 }, pickup = { money = 5000 },
    trapOnPickup = "idol" })

Definition.depth = 100

return Definition
