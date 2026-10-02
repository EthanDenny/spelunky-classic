local Assets = {}

function Assets.image(group, sprite, frame)
    local path = "original-game-reference/source/extracted/spelunky/Sprites/"
        .. group .. "/" .. sprite .. ".images/image " .. (frame or 0) .. ".png"
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

return Assets
