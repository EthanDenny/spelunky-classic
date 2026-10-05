local Definition = setmetatable({}, { __index = require("src.platform.traps.arrow_trap_left") })
function Definition.entityImage(_, tick)
    return require("src.platform.object_assets").frame("Traps", "sArrowTrapLeftLit", 5, tick or 0)
end
return Definition
