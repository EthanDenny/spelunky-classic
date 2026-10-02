local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "melee", price = 8000, bounds = { 4, -6, 6 },
    melee = { damage = 2, strike = "mattock", breakChance = 20,
        playerSpeed = 0.2, strikeSpeed = 0.5 } })

Definition.depth = 101
Definition.shopOffsetY = 10

Definition.melee.blockJumpTicks = 20
Definition.melee.renewWindup = true
Definition.melee.digs = true

Definition.leftSprite = { group = "Items/Saleable", name = "sMattockLeft" }

return Definition
