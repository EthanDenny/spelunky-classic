-- oLevel.Draw / oScreen.Begin Step: two centered 8-pixel sprite-font lines,
-- white at y=216 and yellow at y=224 in the original 320x240 camera.
local OriginalMessages = {}
local glyphs

local function drawLine(text, width, y)
    local x = math.ceil((width - #text * 8) / 2)
    for index = 1, #text do
        local glyph = glyphs[text:byte(index) - string.byte(" ")]
        if glyph then love.graphics.draw(glyph, x, y) end
        x = x + 8
    end
end

function OriginalMessages.draw(run, viewport)
    local message = run:currentMessage()
    if not message then return end
    if not glyphs then
        glyphs = {}
        local root = "original-game-reference/source/extracted/config/Sprites/sFontSmall.images/"
        for frame = 0, 58 do
            local image = love.graphics.newImage(root .. "image " .. frame .. ".png")
            image:setFilter("nearest", "nearest")
            glyphs[frame] = image
        end
    end
    local first, second = message.text:match("^([^\n]*)\n?(.*)$")
    love.graphics.push("all")
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale)
    love.graphics.setColor(1, 1, 1, 1)
    drawLine(first, viewport.logicalWidth, viewport.logicalHeight - 24)
    love.graphics.setColor(1, 1, 0, 1)
    drawLine(second, viewport.logicalWidth, viewport.logicalHeight - 16)
    love.graphics.pop()
end

return OriginalMessages
