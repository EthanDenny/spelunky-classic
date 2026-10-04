local Lighting = {}
function Lighting.darkness(game)
    local distance = 160
    local function light(x, y)
        distance = math.min(distance, math.sqrt((game.player.x-x)^2+(game.player.y-y)^2))
    end
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "lamp" and not entity.destroyed then light(entity.x*16, entity.y*16) end
    end
    for _, item in ipairs(game.items) do
        if item.alive and item.definition.lightRadius then light(item.x, item.y) end
    end
    local nearest, nearestDistance
    for _, explosion in ipairs(game.tools.explosions) do
        if explosion.alive then
            local range = math.sqrt((game.player.x-explosion.x)^2+(game.player.y-explosion.y)^2)
            if not nearestDistance or range < nearestDistance then
                nearest, nearestDistance = explosion, range
            end
        end
    end
    if nearest then
        local frame = nearest.age*0.8
        local expansion = frame <= 3 and -frame*16 or (frame-3)*16
        distance = math.min(distance, nearestDistance+expansion)
    end
    return math.max(0, math.min(0.9, distance/160))
end

-- oScreen.Begin Step multiplies the world by a black mask with blue-tinted
-- circles. Distance changes the player's radius and tint, not the whole screen.
function Lighting.draw(game, viewport)
    if not game.level.dark or game.player:isDead() then return end
    local darkness = Lighting.darkness(game)
    love.graphics.push("all")
    love.graphics.stencil(function()
        love.graphics.circle("fill", game.player.x, game.player.y, 96-64*darkness)
        for _, entity in ipairs(game.level.entities) do
            if entity.kind == "lamp" and not entity.destroyed then
                love.graphics.circle("fill", entity.x*16+8, entity.y*16+8, 96)
            end
        end
        for _, item in ipairs(game.items) do
            if item.alive and item.definition.lightRadius then
                love.graphics.circle("fill", item.x, item.y+(item.kind == "lamp_item" and -4 or 0), 96)
            end
        end
        for _, explosion in ipairs(game.tools.explosions) do
            if explosion.alive then love.graphics.circle("fill", explosion.x, explosion.y, 96) end
        end
        for _, treasure in ipairs(game.collectibles) do
            if treasure.alive and treasure.kind == "scarab" then
                love.graphics.circle("fill", treasure.x, treasure.y, 16)
            end
        end
        for _, enemy in ipairs(game.enemies) do
            if enemy.alive and enemy.kind == "ghost" then
                -- Creature coordinates are eight right and sixteen below the source origin.
                love.graphics.circle("fill", enemy.x+8, enemy.y, 64)
            end
        end
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", game.cameraX, game.cameraY,
        viewport.logicalWidth, viewport.logicalHeight)
    love.graphics.setStencilTest("equal", 1)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1-darkness, 1-darkness, 1, 1)
    love.graphics.rectangle("fill", game.cameraX, game.cameraY,
        viewport.logicalWidth, viewport.logicalHeight)
    love.graphics.pop()
end
return Lighting
