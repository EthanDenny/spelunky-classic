local Brick = require("src.platform.tiles.brick")
local Solid = { solid = true, worldLayer = "solid", depth = 100 }

function Solid.image(tile)
    return Brick.images[tile.style] or Brick.images[tile.baseStyle] or "block"
end

return Solid
