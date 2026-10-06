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

local Mask = require("src.platform.sprite_mask")
function WhipMask.overlaps(name, x, y, left, top, right, bottom)
    return Mask.overlaps(assert(masks[name], "Unknown whip sprite: " .. tostring(name)),
        x, y, left, top, right, bottom)
end

function WhipMask.touching(name, x, y, target)
    local pixels = assert(masks[name], "Unknown whip sprite: " .. tostring(name))
    return require("src.platform.entity_collision").touchingMask(target, nil,
        x+pixels.left, y+pixels.top, x+pixels.right, y+pixels.bottom, function(px, py)
            return Mask.overlaps(pixels, x, y, px, py, px+1, py+1)
        end)
end

return WhipMask
