-- Opaque sprite pixels, shared by melee, whip, and object collision queries.
local Mask = {}
local images = {}

function Mask.load(path)
    if images[path] then return images[path] end
    local image = love.image.newImageData(path)
    local width, height = image:getDimensions()
    local result = { width = width, height = height, left = width, top = height,
        right = 0, bottom = 0, rows = {} }
    for y = 0, height-1 do
        local row = {}
        for x = 0, width-1 do
            local _, _, _, alpha = image:getPixel(x, y)
            row[x] = alpha > 0
            if row[x] then
                result.left, result.top = math.min(result.left, x), math.min(result.top, y)
                result.right, result.bottom = math.max(result.right, x+1), math.max(result.bottom, y+1)
            end
        end
        result.rows[y] = row
    end
    images[path] = result
    return result
end

function Mask.overlaps(mask, x, y, left, top, right, bottom, mirrored, boundsOnly)
    local x0 = mirrored and x-mask.right or x+mask.left
    local x1 = mirrored and x-mask.left or x+mask.right
    if x0 >= right or x1 <= left or y+mask.top >= bottom or y+mask.bottom <= top then return false end
    if boundsOnly then return true end
    for row = mask.top, mask.bottom-1 do
        local py = y+row
        if py < bottom and py+1 > top then
            local pixels = mask.rows[row]
            for column = mask.left, mask.right-1 do
                local px = mirrored and x-column-1 or x+column
                if px < right and px+1 > left then
                    local opaque = type(pixels) == "number" and math.floor(pixels/2^column) % 2 == 1
                        or type(pixels) == "table" and pixels[column]
                    if opaque then return true end
                end
            end
        end
    end
    return false
end

return Mask
