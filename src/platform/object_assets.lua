local Assets = {}
local animations = {}

function Assets.image(group, sprite, frame)
    local path = "original-game-reference/source/extracted/spelunky/Sprites/"
        .. group .. "/" .. sprite .. ".images/image " .. (frame or 0) .. ".png"
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function Assets.frame(group, sprite, count, frame)
    local key = group .. "/" .. sprite
    if not animations[key] then
        local images = {}
        for index = 0, count-1 do images[index+1] = Assets.image(group, sprite, index) end
        animations[key] = images
    end
    return animations[key][math.floor(frame or 0) % count + 1]
end

return Assets
