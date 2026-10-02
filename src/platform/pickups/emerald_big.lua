local Traits = require("src.platform.item_traits")

local Definition = Traits.money(800)

Definition.collectDelay = 20
Definition.ghostConvertible = true
Definition.depth = 101

return Definition
