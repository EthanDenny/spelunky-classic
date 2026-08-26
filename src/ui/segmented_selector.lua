local SegmentedSelector = {}
SegmentedSelector.__index = SegmentedSelector

function SegmentedSelector.new(items, selectedIndex)
    return setmetatable({
        items = items,
        selectedIndex = selectedIndex or 1,
        bounds = nil,
    }, SegmentedSelector)
end

function SegmentedSelector:getSelected()
    return self.items[self.selectedIndex]
end

function SegmentedSelector:select(index)
    if self.items[index] then
        self.selectedIndex = index
        return true
    end
    return false
end

function SegmentedSelector:move(direction)
    local count = #self.items
    self.selectedIndex = ((self.selectedIndex - 1 + direction) % count) + 1
    return self:getSelected()
end

function SegmentedSelector:indexAt(x, y)
    if not self.bounds or x < self.bounds.x or x > self.bounds.x + self.bounds.width
        or y < self.bounds.y or y > self.bounds.y + self.bounds.height then
        return nil
    end

    if self.bounds.vertical then
        local itemHeight = self.bounds.height / #self.items
        return math.min(#self.items, math.floor((y - self.bounds.y) / itemHeight) + 1)
    end
    local itemWidth = self.bounds.width / #self.items
    return math.min(#self.items, math.floor((x - self.bounds.x) / itemWidth) + 1)
end

function SegmentedSelector:mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end

    local index = self:indexAt(x, y)
    return index and self:select(index) or false
end

function SegmentedSelector:draw(x, y, width, height, font, vertical)
    self.bounds = { x = x, y = y, width = width, height = height, vertical = vertical }
    local itemWidth = width / #self.items
    local itemHeight = height
    if vertical then
        itemWidth = width
        itemHeight = height / #self.items
    end

    love.graphics.setFont(font)
    for index, item in ipairs(self.items) do
        local itemX = vertical and x or x + (index - 1) * itemWidth
        local itemY = vertical and y + (index - 1) * itemHeight or y
        local selected = index == self.selectedIndex

        if selected then
            love.graphics.setColor(item.implemented and 0.66 or 0.30, item.implemented and 0.20 or 0.25, 0.12)
        else
            love.graphics.setColor(0.085, 0.075, 0.062)
        end
        love.graphics.rectangle("fill", itemX, itemY, itemWidth - (vertical and 0 or 2),
            itemHeight - (vertical and 2 or 0), 3, 3)

        if selected then
            love.graphics.setColor(1, 0.94, 0.78)
        elseif item.implemented then
            love.graphics.setColor(0.80, 0.74, 0.61)
        else
            love.graphics.setColor(0.40, 0.37, 0.32)
        end
        love.graphics.printf(item.label, itemX + 3, itemY + (itemHeight - font:getHeight()) / 2,
            itemWidth - 8, "center")
    end
end

return SegmentedSelector
