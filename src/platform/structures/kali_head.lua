local Definition = { depth = 997 }

function Definition.draw(renderer, entity)
    love.graphics.draw(renderer.backdropImages.kali_heads[entity.properties.variant],
        entity.x * 16 - 16, entity.y * 16 - 16)
end

return Definition
