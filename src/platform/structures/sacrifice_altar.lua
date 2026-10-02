local Definition = { depth = 110, worldLayer = "solid", cellsWide = 2 }

function Definition.draw(renderer, entity)
    love.graphics.draw(renderer.entitySprites.sac_altar_left.image, entity.x * 16, entity.y * 16)
    love.graphics.draw(renderer.entitySprites.sac_altar_right.image, (entity.x + 1) * 16, entity.y * 16)
end

return Definition
