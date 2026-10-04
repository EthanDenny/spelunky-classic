local Font = {}
local glyphs

function Font.draw(text, x, y)
    if not glyphs then
        glyphs = {}
        local root = "original-game-reference/source/extracted/config/Sprites/sFontSmall.images/"
        for frame = 0, 58 do
            local image = love.graphics.newImage(root .. "image " .. frame .. ".png")
            image:setFilter("nearest", "nearest")
            glyphs[frame] = image
        end
    end
    text = tostring(text)
    for index = 1, #text do
        local glyph = glyphs[text:byte(index) - string.byte(" ")]
        if glyph then love.graphics.draw(glyph, x, y) end
        x = x + 8
    end
end

return Font
