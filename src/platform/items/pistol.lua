local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "gun", price = 5000, gun = {
    projectile = "bullet", count = 1, minSpeed = 6, maxSpeed = 8,
    damage = 4, recoil = 1, cooldown = 20,
} })

Definition.depth = 101
Definition.shopOffsetY = 12

Definition.leftSprite = { group = "Items/Saleable", name = "sPistolLeft" }

Definition.pickupMessage = "YOU GOT A PISTOL!"
Definition.buyMessage = "A PISTOL FOR $%s."

return Definition
