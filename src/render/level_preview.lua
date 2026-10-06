local DepthQueue = require("src.render.depth_queue")
local Preview = {}

function Preview.drawRoomPath(level, font)
    local pathColors = {
        [0] = { 0.15, 0.13, 0.11, 0.10 },
        [1] = { 0.20, 0.68, 0.34, 0.22 },
        [2] = { 0.20, 0.68, 0.34, 0.22 },
        [3] = { 0.20, 0.68, 0.34, 0.22 },
        [4] = { 0.82, 0.53, 0.16, 0.28 },
        [5] = { 0.82, 0.53, 0.16, 0.28 },
        [7] = { 0.55, 0.25, 0.62, 0.28 },
        [8] = { 0.55, 0.25, 0.62, 0.28 },
        [9] = { 0.55, 0.25, 0.62, 0.28 },
    }

    love.graphics.setFont(font)
    love.graphics.setLineWidth(1)
    for roomY = 0, 3 do
        for roomX = 0, 3 do
            local value = level.roomPath[roomY + 1][roomX + 1]
            local origin = level.roomOrigins and level.roomOrigins[roomY + 1][roomX + 1]
            local x = (origin and origin.x or (1 + roomX * 10)) * 16
            local y = (origin and origin.y or (1 + roomY * 8)) * 16
            love.graphics.setColor(pathColors[value] or pathColors[0])
            love.graphics.rectangle("fill", x, y, 160, 128)
            love.graphics.setColor(1, 0.94, 0.78, 0.42)
            love.graphics.rectangle("line", x, y, 160, 128)
            love.graphics.print(tostring(value), x + 5, y + 3)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Preview.draw(renderer, level, viewport, showRoomPath, font)
    local worldWidth = level.width * level.tileSize
    local worldHeight = level.height * level.tileSize
    local fitScale = math.min(viewport.width / worldWidth, viewport.height / worldHeight)
    local scale = fitScale >= 1 and math.floor(fitScale) or fitScale
    local drawWidth = worldWidth * scale
    local drawHeight = worldHeight * scale
    local drawX = math.floor(viewport.x + (viewport.width - drawWidth) / 2)
    local drawY = math.floor(viewport.y + (viewport.height - drawHeight) / 2)

    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(drawX, drawY)
    love.graphics.scale(scale, scale)

    love.graphics.setColor(1, 1, 1, 1)
    local background = renderer.images.bg_cave
    local backgroundQuad = love.graphics.newQuad(0, 0, worldWidth, worldHeight,
        background:getDimensions())
    love.graphics.draw(background, backgroundQuad, 0, 0)

    local queue = DepthQueue.new()
    renderer:submitLevel(queue, level)
    queue:draw()

    if showRoomPath then
        Preview.drawRoomPath(level, font)
    end

    love.graphics.pop()
    love.graphics.setScissor()

    love.graphics.setColor(0.30, 0.22, 0.14)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", drawX, drawY, drawWidth, drawHeight)
end

return Preview
