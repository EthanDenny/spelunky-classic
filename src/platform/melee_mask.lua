-- Classic's oMachetePre/oMattockPre and oSlash/oMattockHit use PRECISE,
-- per-frame sprite masks. Keep hit testing aligned with the drawn image.
local MeleeMask = {}
local Mask = require("src.platform.sprite_mask")

local function mask(name, frame)
    return Mask.load("original-game-reference/source/extracted/spelunky/"
        .. "Sprites/Items/Weapons/" .. name .. ".images/image " .. frame .. ".png")
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
    return Mask.overlaps(mask(name, frame), x, y, left, top, right, bottom)
end

return MeleeMask
