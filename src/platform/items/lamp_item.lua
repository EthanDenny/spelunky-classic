local Definition = require("src.platform.item_traits").carry({ heavy = true,
    hold = { standing = 0, ducking = 2 } })
Definition.depth = 100
Definition.lightRadius = 160
Definition.sprite = { group = "Items/Treasures", name = "sLampItem", size = 16, originY = 12 }
function Definition.update(item)
    item.spriteFrame = (item.spriteFrame or 0)+1
end
function Definition.itemImage(_, item)
    return require("src.platform.object_assets").frame("Items/Treasures", "sLampItem", 3, item.spriteFrame)
end
function Definition.collisionSprite(item)
    return "sLampItem", item.spriteFrame or 0, item.x, item.y, false
end
return Definition
