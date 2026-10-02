local Definition = { rubbleMaterial = "tan", depth = 110, worldLayer = "solid" }

function Definition.spriteKey(entity)
    return "shop_sign_" .. string.lower(entity.properties.shopType or "general")
end

return Definition
