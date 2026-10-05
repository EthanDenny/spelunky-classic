local Definition = setmetatable({}, { __index = require("src.platform.structures.lamp") })
function Definition.entityImage(_, tick)
    return require("src.platform.object_assets").frame("Blocks/Shop", "sLampRed", 3, (tick or 0)*0.5)
end
return Definition
