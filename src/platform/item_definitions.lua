-- Items and pickups keep their own definitions; callers share this lookup.
local Definitions = {}

for _, types in ipairs({
    require("src.platform.items.types"),
    require("src.platform.pickups.types"),
}) do
    for kind, definition in pairs(types) do Definitions[kind] = definition end
end

return Definitions
