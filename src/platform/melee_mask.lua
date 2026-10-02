-- Classic's oMachetePre/oMattockPre and oSlash/oMattockHit use PRECISE,
-- per-frame sprite masks. Keep hit testing aligned with the drawn image.
local MeleeMask = {}
local masks = {}

local function mask(name, frame)
    local key = name .. ":" .. frame
    if masks[key] then return masks[key] end
    local path = "original-game-reference/source/extracted/spelunky/"
        .. "Sprites/Items/Weapons/" .. name .. ".images/image " .. frame .. ".png"
    local image = love.image.newImageData(path)
    local width, height = image:getDimensions()
    local rows = {}
    for y = 0, height - 1 do
        local row = {}
        for x = 0, width - 1 do
            local _, _, _, alpha = image:getPixel(x, y)
            row[x] = alpha > 0
        end
        rows[y] = row
    end
    masks[key] = { width = width, height = height, rows = rows }
    return masks[key]
end

function MeleeMask.pose(player, spec, phase, age)
    local facing = player.meleeFacing or player.facing
    local left = facing < 0
    local name, frame
    if phase == "back" then
        name = spec.strike == "slash" and (left and "sMachetePreL" or "sMachetePreR")
            or (left and "sMattockPreL" or "sMattockPreR")
        frame = 0
    elseif phase == "front" and age and age < math.ceil(3 / spec.strikeSpeed) then
        name = spec.strike == "slash" and (left and "sSlashLeft" or "sSlashRight")
            or (left and "sMattockHitL" or "sMattockHitR")
        frame = math.min(2, math.floor(age * spec.strikeSpeed))
    else
        return nil
    end
    local x = player.x + facing * (phase == "back" and -16 or 16)
    local originX = name == "sSlashLeft" and 4 or name == "sSlashRight" and 28 or 8
    local originY = name:find("sSlash") and 24 or 8
    return name, frame, math.floor(x - originX), math.floor(player.y - originY)
end

function MeleeMask.overlaps(name, frame, x, y, left, top, right, bottom)
    local sprite = mask(name, frame)
    local x0 = math.max(0, math.floor(left - x))
    local y0 = math.max(0, math.floor(top - y))
    local x1 = math.min(sprite.width - 1, math.ceil(right - x) - 1)
    local y1 = math.min(sprite.height - 1, math.ceil(bottom - y) - 1)
    for row = y0, y1 do
        for column = x0, x1 do
            if sprite.rows[row][column] and x + column < right
                and x + column + 1 > left and y + row < bottom
                and y + row + 1 > top then return true end
        end
    end
    return false
end

return MeleeMask
