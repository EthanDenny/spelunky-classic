local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ heavy = true, bounds = { 6, -2, 8 },
    container = { mode = "fixed", reward = "udjat_eye", requires = "key",
        message = "THE UDJAT EYE", effect = "unlock" }, unlockWith = "key" })

Definition.depth = 900

Definition.container.scatter = true

return Definition
