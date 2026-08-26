local SpriteData = require("src.platform.player_sprite_data")

local Analyzer = {}

local MOVEMENT_SPRITES = {
    "sStandLeft",
    "sRunLeft",
    "sDuckLeft",
    "sCrawlLeft",
    "sLookLeft",
    "sLookRunL",
    "sJumpLeft",
    "sFallLeft",
    "sHangLeft",
}

local function colorDistance(r1, g1, b1, r2, g2, b2)
    return math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)
end

local function screenPixel(image, x, y, scale)
    return image:getPixel(x * scale + math.floor(scale / 2), y * scale + math.floor(scale / 2))
end

local function findAnchor(frame)
    local best
    for y = 0, frame:getHeight() - 1 do
        for x = 0, frame:getWidth() - 1 do
            local r, g, b, a = frame:getPixel(x, y)
            if a > 0.99 then
                local brightness = r + g + b
                if not best or brightness > best.brightness then
                    best = { x = x, y = y, r = r, g = g, b = b, brightness = brightness }
                end
            end
        end
    end
    return assert(best, "Sprite frame has no opaque pixels")
end

local function scoreAt(screen, frame, left, top, facing, scale)
    local total = 0
    local count = 0
    for y = 0, frame:getHeight() - 1 do
        for x = 0, frame:getWidth() - 1 do
            local r, g, b, a = frame:getPixel(x, y)
            if a > 0.99 then
                local screenX = left + (facing == "left" and x or frame:getWidth() - 1 - x)
                local sr, sg, sb = screenPixel(screen, screenX, top + y, scale)
                total = total + colorDistance(r, g, b, sr, sg, sb)
                count = count + 1
            end
        end
    end
    return total / count
end

local function locateFrame(screen, frame, facing, scale)
    local anchor = findAnchor(frame)
    local anchorX = facing == "left" and anchor.x or frame:getWidth() - 1 - anchor.x
    local logicalWidth = screen:getWidth() / scale
    local logicalHeight = screen:getHeight() / scale
    local best

    for y = 0, logicalHeight - 1 do
        for x = 0, logicalWidth - 1 do
            local r, g, b = screenPixel(screen, x, y, scale)
            if colorDistance(r, g, b, anchor.r, anchor.g, anchor.b) < 0.01 then
                local left = x - anchorX
                local top = y - anchor.y
                if left >= 0 and top >= 22
                    and left + frame:getWidth() <= logicalWidth
                    and top + frame:getHeight() <= math.min(logicalHeight, 190) then
                    local score = scoreAt(screen, frame, left, top, facing, scale)
                    if not best or score < best.score then
                        best = { left = left, top = top, score = score }
                    end
                end
            end
        end
    end
    return best
end

function Analyzer.run(path)
    assert(path, "--analyze-oracle requires a screenshot path")
    local screen = love.image.newImageData(path)
    local scale = screen:getWidth() / 320
    assert(scale == math.floor(scale) and screen:getHeight() == 240 * scale,
        "Oracle screenshot must be an integer-scaled 320x240 frame")

    local best
    for _, spriteName in ipairs(MOVEMENT_SPRITES) do
        local sprite = SpriteData[spriteName]
        for frameIndex, framePath in ipairs(sprite.frames) do
            local frame = love.image.newImageData(framePath)
            for _, facing in ipairs({ "left", "right" }) do
                local match = locateFrame(screen, frame, facing, scale)
                if match and (not best or match.score < best.score) then
                    local originX = facing == "left"
                        and sprite.originX
                        or sprite.width - sprite.originX
                    best = {
                        sprite = spriteName,
                        frame = frameIndex - 1,
                        facing = facing,
                        x = match.left + originX,
                        y = match.top + sprite.originY,
                        score = match.score,
                    }
                end
            end
        end
    end

    assert(best, "Could not locate the player in oracle screenshot")
    io.write(string.format("%s frame=%d facing=%s x=%d y=%d score=%.6f\n",
        best.sprite, best.frame, best.facing, best.x, best.y, best.score))
    return best
end

return Analyzer
