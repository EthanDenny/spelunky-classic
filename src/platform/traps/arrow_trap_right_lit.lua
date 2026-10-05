local Definition = setmetatable({}, { __index = require("src.platform.traps.arrow_trap_right") })
function Definition.entityImage(_, tick)
    return require("src.platform.object_assets").frame("Traps", "sArrowTrapRightLit", 5, tick or 0)
end
return Definition
