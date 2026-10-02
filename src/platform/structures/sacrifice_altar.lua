local Definition = { depth = 110, worldLayer = "solid", cellsWide = 2, handlesDestructionEffects = true }

function Definition.at(game, x, y)
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "sacrifice_altar" and not entity.destroyed
            and x >= entity.x * 16 and x < (entity.x + 2) * 16
            and y >= entity.y * 16 and y < (entity.y + 1) * 16 then return entity end
    end
end

function Definition.update(game, entity)
    if entity.destroyed then return end
    local width, height = game.cameraWidth or 320, game.cameraHeight or 240
    for offset = 0, 1 do
        local x, y = (entity.x + offset) * 16, entity.y * 16
        if x > game.cameraX - 20 and x < game.cameraX + width + 4
            and y > game.cameraY - 20 and y < game.cameraY + height + 4
            and not game.world:solidAtPoint(x, y + 16) then
            game.world:remove("solid", entity.x + offset, entity.y)
            return
        end
    end
end

function Definition.destroy(game, entity)
    if entity.defileHandled then return end
    entity.defileHandled = true
    game.world:remove("solid", entity.x, entity.y)
    game.world:remove("solid", entity.x + 1, entity.y)
    entity.destroyed = true
    for offset = 0, 1 do
        game.effects:terrainBreak((entity.x + offset + 0.5) * 16, (entity.y + 0.5) * 16,
            16, nil, "tan")
    end
end

function Definition.draw(renderer, entity)
    love.graphics.draw(renderer.entitySprites.sac_altar_left.image, entity.x * 16, entity.y * 16)
    love.graphics.draw(renderer.entitySprites.sac_altar_right.image, (entity.x + 1) * 16, entity.y * 16)
end

return Definition
