local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "gun", price = 2000, gun = {
    projectile = "web", count = 1, minSpeed = 6, maxSpeed = 8,
    damage = 0, gravity = 0.2, radius = 4,
    recoil = 1, cooldown = 20, muzzleOffset = 12,
} })

Definition.depth = 101
Definition.shopOffsetY = 12

Definition.leftSprite = { group = "Items/Saleable", name = "sWebCannonL" }

return Definition
