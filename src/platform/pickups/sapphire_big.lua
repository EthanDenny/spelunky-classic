local Traits = require("src.platform.item_traits")

local Definition = Traits.money(1200)

Definition.collectDelay = 20
Definition.ghostConvertible = true
Definition.depth = 101

return Definition
