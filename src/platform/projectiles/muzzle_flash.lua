local Flash = { depth = 0 }
local shotImages

function Flash.loadImages()
    if shotImages then return shotImages end
    local root = "original-game-reference/source/extracted/spelunky/Sprites/"
    shotImages = { blastLeft = {}, blastRight = {} }
    for frame = 0, 9 do
        shotImages.blastLeft[frame + 1] = love.graphics.newImage(string.format(
            "%sEffects/sShotgunBlastLeft.images/image %d.png", root, frame))
        shotImages.blastRight[frame + 1] = love.graphics.newImage(string.format(
            "%sEffects/sShotgunBlastRight.images/image %d.png", root, frame))
    end
    for _, frames in ipairs({ shotImages.blastLeft, shotImages.blastRight }) do
        for _, image in ipairs(frames) do image:setFilter("nearest", "nearest") end
    end
    return shotImages
end

function Flash.draw(flash)
    local sprites = Flash.loadImages()
    local frames = flash.direction < 0 and sprites.blastLeft or sprites.blastRight
    local frame = math.min(10, math.floor(flash.age) + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(frames[frame], math.floor(flash.x - 8), math.floor(flash.y - 8))
end

return Flash
