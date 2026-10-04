-- oLevel.Draw / oScreen.Begin Step: two centered 8-pixel sprite-font lines,
-- white at y=216 and yellow at y=224 in the original 320x240 camera.
local OriginalMessages = {}
local Font = require("src.ui.original_small_font")

local function drawLine(text, width, y)
    local x = math.ceil((width - #text * 8) / 2)
    Font.draw(text, x, y)
end

function OriginalMessages.draw(run, viewport)
    local message = run:currentMessage()
    if not message then return end
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
