local Definition = setmetatable({ lightRadius = false }, { __index = require("src.platform.items.lamp_item") })
Definition.sprite = { group = "Items/Treasures", name = "sLampRedItem", size = 16, originY = 12 }
function Definition.itemImage(_, item)
    return require("src.platform.object_assets").frame("Items/Treasures", "sLampRedItem", 3, item.spriteFrame)
end
function Definition.collisionSprite(item)
    return "sLampRedItem", item.spriteFrame or 0, item.x, item.y, false
end
return Definition
