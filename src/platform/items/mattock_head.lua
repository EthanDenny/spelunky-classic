local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ bounds = { 6, -4, 4 } })

Definition.depth = 100

function Definition.loadRenderAssets(self)
    local head = love.graphics.newImage("original-game-reference/source/extracted/spelunky/"
        .. "Sprites/Items/Weapons/sMattockHead.images/image 0.png")
    head:setFilter("nearest", "nearest")
    self.entitySprites.mattock_head = { image = head,
        metadata = { originX = 8, originY = 4, width = 16, height = 8 } }
end

return Definition
