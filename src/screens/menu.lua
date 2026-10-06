local Menu = {}
Menu.__index = Menu

local COLORS = {
    background = { 0.045, 0.04, 0.035 },
    panel = { 0.095, 0.08, 0.065 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    selected = { 0.72, 0.18, 0.10 },
    selectedText = { 1, 0.94, 0.78 },
}

function Menu.new(app)
    return setmetatable({
        app = app,
        selectedIndex = 1,
        items = {
            { label = "Animation Viewer", screen = "animation_viewer" },
            { label = "Scenario Tests", screen = "enemy_ai" },
            { label = "Full Level Playtest", screen = "full_level_playtest" },
            { label = "Full game", screen = "full_game" },
        },
    }, Menu)
end

function Menu:enter()
    self.selectedIndex = math.max(1, math.min(self.selectedIndex, #self.items))
end

function Menu:getLayout()
    local width, height = love.graphics.getDimensions()
    local itemWidth = math.min(460, width - 64)
    local itemHeight = 52
    local gap = 10
    local totalHeight = #self.items * itemHeight + (#self.items - 1) * gap

    return {
        x = (width - itemWidth) / 2,
        y = math.max(190, (height - totalHeight) / 2 + 46),
        width = itemWidth,
        itemHeight = itemHeight,
        gap = gap,
    }
end

function Menu:itemAt(x, y)
    local layout = self:getLayout()

    for index = 1, #self.items do
        local itemY = layout.y + (index - 1) * (layout.itemHeight + layout.gap)
        if x >= layout.x and x <= layout.x + layout.width
            and y >= itemY and y <= itemY + layout.itemHeight then
            return index
        end
    end
end

function Menu:activateSelected()
    self.app:showScreen(self.items[self.selectedIndex].screen)
end

function Menu:keypressed(key, _, isRepeat)
    if isRepeat then
        return
    end

    if key == "up" or key == "w" then
        self.selectedIndex = ((self.selectedIndex - 2) % #self.items) + 1
    elseif key == "down" or key == "s" then
        self.selectedIndex = (self.selectedIndex % #self.items) + 1
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activateSelected()
    else
        local number = tonumber(key)
        if number and self.items[number] then
            self.selectedIndex = number
            self:activateSelected()
        end
    end
end

function Menu:mousemoved(x, y)
    local hoveredIndex = self:itemAt(x, y)
    if hoveredIndex then
        self.selectedIndex = hoveredIndex
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local clickedIndex = self:itemAt(x, y)
    if clickedIndex then
        self.selectedIndex = clickedIndex
        self:activateSelected()
    end
end

function Menu:draw()
    local width, height = love.graphics.getDimensions()
    local layout = self:getLayout()
    local panelHeight = #self.items * (layout.itemHeight + layout.gap) + 158

    love.graphics.clear(COLORS.background)

    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", layout.x - 24, layout.y - 128,
        layout.width + 48, panelHeight, 8, 8)
    love.graphics.setColor(COLORS.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x - 24, layout.y - 128,
        layout.width + 48, panelHeight, 8, 8)

    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("SPELUNKY CLASSIC", 0, layout.y - 108, width, "center")

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf("PROTOTYPE LAB", 0, layout.y - 59, width, "center")

    love.graphics.setFont(self.app.fonts.menu)
    for index, item in ipairs(self.items) do
        local itemY = layout.y + (index - 1) * (layout.itemHeight + layout.gap)
        local selected = index == self.selectedIndex

        love.graphics.setColor(selected and COLORS.selected or COLORS.background)
        love.graphics.rectangle("fill", layout.x, itemY, layout.width, layout.itemHeight, 4, 4)

        love.graphics.setColor(selected and COLORS.selectedText or COLORS.text)
        love.graphics.print(index .. ".", layout.x + 18, itemY + 11)
        love.graphics.print(item.label, layout.x + 61, itemY + 11)
    end

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf("ARROWS / W S  SELECT     ENTER  OPEN     ESC  QUIT",
        16, height - 35, width - 32, "center")
end

return Menu
