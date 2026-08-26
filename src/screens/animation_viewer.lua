local Catalog = require("src.animation.original_catalog")

local AnimationViewer = {}
AnimationViewer.__index = AnimationViewer

local SIDEBAR_WIDTH = 250
local HEADER_HEIGHT = 86
local FOOTER_HEIGHT = 30
local CARD_MIN_WIDTH = 264
local CARD_HEIGHT = 218
local GAP = 12

local COLORS = {
    background = { 0.045, 0.04, 0.035 },
    panel = { 0.095, 0.08, 0.065 },
    panelDark = { 0.065, 0.057, 0.049 },
    card = { 0.12, 0.102, 0.082 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.72, 0.18, 0.10 },
    selectedText = { 1, 0.94, 0.78 },
    guide = { 0.35, 0.27, 0.19 },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function animationSide(animation, facing)
    if facing == "left" then
        if animation.left then
            return animation.left, false
        elseif animation.neutral then
            return animation.neutral, false
        end
        return animation.right, true
    end

    if animation.right then
        return animation.right, false
    elseif animation.neutral then
        return animation.neutral, false
    end
    return animation.left, true
end

local function speedDescription(animation)
    local rules = animation.speedRules or {}
    if #rules == 0 then
        return string.format("Preview %.1f fps", animation.previewFps or 0)
    end

    if #rules == 1 and tonumber(rules[1]) then
        return string.format("image_speed %s  =  %.1f fps", rules[1], tonumber(rules[1]) * Catalog.roomSpeed)
    end

    return table.concat(rules, " / ")
end

function AnimationViewer.new(app)
    return setmetatable({
        app = app,
        pageIndex = 1,
        facing = "left",
        elapsed = 0,
        scrollY = 0,
        maxScroll = 0,
        loadedPageIndex = nil,
        loadedAnimations = {},
        pageRows = {},
        facingButton = nil,
    }, AnimationViewer)
end

function AnimationViewer:enter()
    self:loadPage(self.pageIndex)
end

function AnimationViewer:leave()
    self.pageRows = {}
    self.facingButton = nil
end

function AnimationViewer:loadPage(index)
    self.pageIndex = ((index - 1) % #Catalog.pages) + 1
    if self.loadedPageIndex == self.pageIndex then
        return
    end

    self.loadedAnimations = {}
    local page = Catalog.pages[self.pageIndex]
    for animationIndex, animation in ipairs(page.animations) do
        local loaded = { animation = animation, sides = {} }
        for _, facing in ipairs({ "left", "right" }) do
            local side, mirrored = animationSide(animation, facing)
            local frames = {}
            for _, path in ipairs(side.frames) do
                local image = love.graphics.newImage(path)
                image:setFilter("nearest", "nearest")
                frames[#frames + 1] = image
            end
            loaded.sides[facing] = {
                data = side,
                frames = frames,
                mirrored = mirrored,
            }
        end
        self.loadedAnimations[animationIndex] = loaded
    end

    self.loadedPageIndex = self.pageIndex
    self.scrollY = 0
    collectgarbage("collect")
end

function AnimationViewer:setPage(index)
    self:loadPage(index)
end

function AnimationViewer:update(dt)
    self.elapsed = self.elapsed + dt
end

function AnimationViewer:getGridLayout()
    local width, height = love.graphics.getDimensions()
    local contentX = SIDEBAR_WIDTH + GAP
    local contentWidth = width - contentX - GAP
    local columns = math.max(1, math.floor((contentWidth + GAP) / (CARD_MIN_WIDTH + GAP)))
    local cardWidth = math.floor((contentWidth - GAP * (columns - 1)) / columns)
    local rows = math.ceil(#self.loadedAnimations / columns)
    local viewportY = HEADER_HEIGHT
    local viewportHeight = height - HEADER_HEIGHT - FOOTER_HEIGHT
    local contentHeight = rows * CARD_HEIGHT + math.max(0, rows - 1) * GAP + GAP

    return {
        x = contentX,
        width = contentWidth,
        columns = columns,
        cardWidth = cardWidth,
        viewportY = viewportY,
        viewportHeight = viewportHeight,
        contentHeight = contentHeight,
    }
end

function AnimationViewer:changeFacing()
    self.facing = self.facing == "left" and "right" or "left"
end

function AnimationViewer:keypressed(key, _, isRepeat)
    if isRepeat then
        return
    end

    if key == "left" or key == "a" then
        self:setPage(self.pageIndex - 1)
    elseif key == "right" or key == "d" then
        self:setPage(self.pageIndex + 1)
    elseif key == "up" or key == "w" then
        self.scrollY = clamp(self.scrollY - 80, 0, self.maxScroll)
    elseif key == "down" or key == "s" then
        self.scrollY = clamp(self.scrollY + 80, 0, self.maxScroll)
    elseif key == "pageup" then
        self.scrollY = clamp(self.scrollY - 600, 0, self.maxScroll)
    elseif key == "pagedown" then
        self.scrollY = clamp(self.scrollY + 600, 0, self.maxScroll)
    elseif key == "home" then
        self.scrollY = 0
    elseif key == "end" then
        self.scrollY = self.maxScroll
    elseif key == "f" or key == "tab" then
        self:changeFacing()
    end
end

function AnimationViewer:wheelmoved(_, y)
    self.scrollY = clamp(self.scrollY - y * 72, 0, self.maxScroll)
end

function AnimationViewer:mousemoved(x, y)
    for _, row in ipairs(self.pageRows) do
        row.hovered = x >= row.x and x <= row.x + row.width
            and y >= row.y and y <= row.y + row.height
    end
end

function AnimationViewer:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if self.facingButton
        and x >= self.facingButton.x and x <= self.facingButton.x + self.facingButton.width
        and y >= self.facingButton.y and y <= self.facingButton.y + self.facingButton.height then
        self:changeFacing()
        return
    end

    for _, row in ipairs(self.pageRows) do
        if x >= row.x and x <= row.x + row.width
            and y >= row.y and y <= row.y + row.height then
            self:setPage(row.index)
            return
        end
    end
end

function AnimationViewer:drawSidebar(width, height)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, SIDEBAR_WIDTH, height)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH - 1, 0, 1, height)

    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("ANIMATION INDEX", 16, 17)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print(string.format("%d ENTITY PAGES", #Catalog.pages), 16, 45)

    local listTop = 78
    local listBottom = height - FOOTER_HEIGHT
    local rowHeight = 29
    local visibleRows = math.max(1, math.floor((listBottom - listTop) / rowHeight))
    local first = clamp(self.pageIndex - math.floor(visibleRows / 2), 1,
        math.max(1, #Catalog.pages - visibleRows + 1))
    local last = math.min(#Catalog.pages, first + visibleRows - 1)
    self.pageRows = {}

    love.graphics.setScissor(0, listTop, SIDEBAR_WIDTH, listBottom - listTop)
    for index = first, last do
        local y = listTop + (index - first) * rowHeight
        local selected = index == self.pageIndex
        local row = {
            index = index,
            x = 8,
            y = y,
            width = SIDEBAR_WIDTH - 16,
            height = rowHeight - 2,
        }
        self.pageRows[#self.pageRows + 1] = row

        if selected then
            love.graphics.setColor(COLORS.accent)
            love.graphics.rectangle("fill", row.x, row.y, row.width, row.height, 3, 3)
        end

        love.graphics.setFont(self.app.fonts.small)
        love.graphics.setColor(selected and COLORS.selectedText or COLORS.text)
        love.graphics.print(string.format("%03d", index), row.x + 8, row.y + 5)
        love.graphics.printf(Catalog.pages[index].name, row.x + 46, row.y + 5, row.width - 54, "left")
    end
    love.graphics.setScissor()

    if first > 1 then
        love.graphics.setColor(COLORS.muted)
        love.graphics.printf("▲", 0, listTop - 5, SIDEBAR_WIDTH, "center")
    end
    if last < #Catalog.pages then
        love.graphics.setColor(COLORS.muted)
        love.graphics.printf("▼", 0, listBottom - 18, SIDEBAR_WIDTH, "center")
    end
end

function AnimationViewer:drawHeader(width)
    local page = Catalog.pages[self.pageIndex]
    love.graphics.setColor(COLORS.panelDark)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH, 0, width - SIDEBAR_WIDTH, HEADER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH, HEADER_HEIGHT - 1, width - SIDEBAR_WIDTH, 1)

    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(page.name, SIDEBAR_WIDTH + GAP, 10)

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print(string.format("%s  •  %d animations  •  original room speed %d steps/s",
        page.category, #page.animations, Catalog.roomSpeed), SIDEBAR_WIDTH + GAP + 2, 59)

    local buttonWidth = 144
    self.facingButton = {
        x = width - buttonWidth - GAP,
        y = 21,
        width = buttonWidth,
        height = 42,
    }
    love.graphics.setColor(COLORS.accent)
    love.graphics.rectangle("fill", self.facingButton.x, self.facingButton.y,
        self.facingButton.width, self.facingButton.height, 4, 4)
    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(COLORS.selectedText)
    love.graphics.printf(self.facing == "left" and "◀  FACING LEFT" or "FACING RIGHT  ▶",
        self.facingButton.x, self.facingButton.y + 9, self.facingButton.width, "center")
end

function AnimationViewer:getFrameIndex(animation, frameCount)
    if frameCount <= 1 then
        return 1
    end

    -- Some GameMaker sprites are frame banks selected with image_index while
    -- image_speed remains zero. Cycle those slowly here so every source frame
    -- can still be inspected; the card continues to report the exact 0 fps.
    local fps = animation.previewFps or 12
    if fps <= 0 then
        fps = 6
    end
    if animation.pattern and animation.pattern:find("one%-shot") then
        local holdFrames = math.max(1, math.floor(fps * 0.35))
        local tick = math.floor(self.elapsed * fps) % (frameCount + holdFrames)
        return math.min(tick + 1, frameCount)
    end

    return (math.floor(self.elapsed * fps) % frameCount) + 1
end

function AnimationViewer:drawCard(loaded, x, y, width)
    local animation = loaded.animation
    local side = loaded.sides[self.facing]
    local frameIndex = self:getFrameIndex(animation, #side.frames)
    local image = side.frames[frameIndex]
    local sprite = side.data

    love.graphics.setColor(COLORS.card)
    love.graphics.rectangle("fill", x, y, width, CARD_HEIGHT, 5, 5)
    love.graphics.setColor(COLORS.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, CARD_HEIGHT - 1, 5, 5)

    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(animation.name, x + 10, y + 8)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(sprite.sprite, x + 10, y + 32, width - 20, "right")

    local previewX = x + 10
    local previewY = y + 54
    local previewWidth = width - 20
    local previewHeight = 82
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, 3, 3)

    local scale = math.max(1, math.min(4,
        math.floor((previewWidth - 20) / math.max(1, sprite.width)),
        math.floor((previewHeight - 14) / math.max(1, sprite.height))))
    local centerX = math.floor(previewX + previewWidth / 2)
    local centerY = math.floor(previewY + previewHeight / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, centerX, centerY, 0,
        side.mirrored and -scale or scale, scale, sprite.width / 2, sprite.height / 2)

    local originOffsetX = (sprite.originX - sprite.width / 2) * scale
    if side.mirrored then
        originOffsetX = -originOffsetX
    end
    local originX = math.floor(centerX + originOffsetX)
    local originY = math.floor(centerY + (sprite.originY - sprite.height / 2) * scale)
    love.graphics.setColor(COLORS.guide)
    love.graphics.line(originX - 5, originY, originX + 5, originY)
    love.graphics.line(originX, originY - 5, originX, originY + 5)

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(string.format("FRAME %d/%d", frameIndex, #side.frames), x + 10, y + 141)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(string.format("%dx%d  ORIGIN %d,%d", sprite.width, sprite.height,
        sprite.originX, sprite.originY), x + 110, y + 141, width - 120, "right")

    love.graphics.setColor(COLORS.text)
    love.graphics.printf(speedDescription(animation), x + 10, y + 160, width - 20, "left")
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(string.upper(animation.pattern or "loop"), x + 10, y + 199, width - 20, "left")
end

function AnimationViewer:drawGrid(width, height)
    local layout = self:getGridLayout()
    self.maxScroll = math.max(0, layout.contentHeight - layout.viewportHeight)
    self.scrollY = clamp(self.scrollY, 0, self.maxScroll)

    love.graphics.setScissor(layout.x, layout.viewportY, layout.width, layout.viewportHeight)
    for index, loaded in ipairs(self.loadedAnimations) do
        local column = (index - 1) % layout.columns
        local row = math.floor((index - 1) / layout.columns)
        local x = layout.x + column * (layout.cardWidth + GAP)
        local y = layout.viewportY + GAP + row * (CARD_HEIGHT + GAP) - self.scrollY
        if y + CARD_HEIGHT >= layout.viewportY and y <= layout.viewportY + layout.viewportHeight then
            self:drawCard(loaded, x, y, layout.cardWidth)
        end
    end
    love.graphics.setScissor()

    if self.maxScroll > 0 then
        local trackX = width - 5
        local trackY = layout.viewportY + 4
        local trackHeight = layout.viewportHeight - 8
        local thumbHeight = math.max(32, trackHeight * layout.viewportHeight / layout.contentHeight)
        local thumbY = trackY + (trackHeight - thumbHeight) * self.scrollY / self.maxScroll
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("fill", trackX, trackY, 3, trackHeight, 2, 2)
        love.graphics.setColor(COLORS.text)
        love.graphics.rectangle("fill", trackX, thumbY, 3, thumbHeight, 2, 2)
    end
end

function AnimationViewer:drawFooter(width, height)
    love.graphics.setColor(COLORS.panelDark)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, 1)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf("A/D OR ←/→  ENTITY     W/S OR WHEEL  SCROLL     F/TAB  FACING     ESC  MENU",
        10, height - 23, width - 20, "center")
end

function AnimationViewer:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(COLORS.background)
    self:drawHeader(width)
    self:drawGrid(width, height)
    self:drawSidebar(width, height)
    self:drawFooter(width, height)
end

return AnimationViewer
