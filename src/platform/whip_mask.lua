-- Opaque pixels from the original 16x16 whip sprites. GameMaker marks all four
-- sprites as PRECISE collision masks; transparent pixels cannot deal damage.
local masks = {
    sWhipLeft = {
        left = 3, top = 6, right = 16, bottom = 11,
        rows = { [6] = 0x0010, [7] = 0xF078, [8] = 0xFFF8,
            [9] = 0xFFF0, [10] = 0x0F80 },
    },
    sWhipRight = {
        left = 0, top = 6, right = 13, bottom = 11,
        rows = { [6] = 0x0800, [7] = 0x1E0F, [8] = 0x1FFF,
            [9] = 0x0FFF, [10] = 0x01F0 },
    },
    sWhipPreL = {
        left = 0, top = 0, right = 10, bottom = 12,
        rows = { [0] = 0x0070, [1] = 0x00F8, [2] = 0x01FC,
            [3] = 0x038E, [4] = 0x03E7, [5] = 0x01F7,
            [6] = 0x00FB, [7] = 0x001D, [8] = 0x005C,
            [9] = 0x00F8, [10] = 0x00F0, [11] = 0x0060 },
    },
    sWhipPreR = {
        left = 6, top = 0, right = 16, bottom = 12,
        rows = { [0] = 0x0E00, [1] = 0x1F00, [2] = 0x3F80,
            [3] = 0x71C0, [4] = 0xE7C0, [5] = 0xEF80,
            [6] = 0xDF00, [7] = 0xB800, [8] = 0x3A00,
            [9] = 0x1F00, [10] = 0x0F00, [11] = 0x0600 },
    },
}

local WhipMask = {}

function WhipMask.bounds(name, x, y)
    local mask = assert(masks[name], "Unknown whip sprite: " .. tostring(name))
    return x + mask.left, y + mask.top, x + mask.right, y + mask.bottom
end

function WhipMask.overlaps(name, x, y, left, top, right, bottom)
    local mask = assert(masks[name], "Unknown whip sprite: " .. tostring(name))
    if x + mask.left >= right or x + mask.right <= left
        or y + mask.top >= bottom or y + mask.bottom <= top then
        return false
    end
    for row = mask.top, mask.bottom - 1 do
        local pixelY = y + row
        if pixelY < bottom and pixelY + 1 > top then
            local bits = mask.rows[row]
            for column = mask.left, mask.right - 1 do
                local pixelX = x + column
                if pixelX < right and pixelX + 1 > left
                    and math.floor(bits / 2 ^ column) % 2 == 1 then
                    return true
                end
            end
        end
    end
    return false
end

return WhipMask
