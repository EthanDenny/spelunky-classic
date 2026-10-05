local Definition = { depth = 201 }
function Definition.entityImage(_, tick)
    return require("src.platform.object_assets").frame("Blocks/Shop", "sLamp", 3, (tick or 0)*0.5)
end

return Definition
