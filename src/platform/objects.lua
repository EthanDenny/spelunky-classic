-- Registry entries reference the owning per-object modules. Shared systems use
-- capabilities from these modules instead of maintaining parallel kind lists.
local Objects = {}
for _, types in ipairs({
    require("src.platform.item_definitions"),
    require("src.platform.enemies.types"),
    require("src.platform.traps.types"),
    require("src.platform.tools.types"),
    require("src.platform.structures.types"),
}) do
    for kind, definition in pairs(types) do
        assert(not Objects[kind], "Duplicate object definition: " .. kind)
        Objects[kind] = definition
    end
end

Objects.fake_bones = require("src.platform.fake_bones")
Objects.boulder = require("src.platform.traps.boulder")
Objects.spikes = require("src.platform.traps.spikes")
Objects.web = require("src.platform.environment.web")
Objects.web_ball = require("src.platform.projectiles.web_ball")
Objects.bullet = require("src.platform.projectiles.bullet")
Objects.pellet = require("src.platform.projectiles.pellet")
Objects.rope_throw = require("src.platform.tools.rope_throw")

return Objects
