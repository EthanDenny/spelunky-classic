local OriginalHUD = {}
OriginalHUD.__index = OriginalHUD

OriginalHUD.LAYOUT = {
    lifeX = 8,
    bombX = 64,
    ropeX = 120,
    moneyX = 176,
    top = 8,
    heldX = 8,
    heldY = 24,
}

local HUD_SPRITES = {
    heart = "sHeart",
    bomb = "sBombIcon",
    stickyBomb = "sStickyBombIcon",
    rope = "sRopeIcon",
    dollar = "sDollarSign",
    held = "sHoldItemIcon",
}

local EQUIPMENT_ORDER = {
    "spectacles", "compass", "parachute", "paste", "gloves", "mitt", "cape",
    "jetpack", "spike_shoes", "spring_shoes", "udjat_eye", "kapala",
}

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function OriginalHUD.new(renderer)
    return setmetatable({
        renderer = renderer,
        images = nil,
        glyphs = nil,
    }, OriginalHUD)
end

function OriginalHUD:loadAssets()
    if self.images then return end
    self.images = {}
    local hudRoot = "original-game-reference/source/extracted/spelunky/Sprites/HUD/"
    for key, spriteName in pairs(HUD_SPRITES) do
        self.images[key] = loadImage(hudRoot .. spriteName .. ".images/image 0.png")
    end

    self.glyphs = {}
    local fontRoot = "original-game-reference/source/extracted/config/Sprites/sFont.images/"
    for frame = 0, 58 do
        self.glyphs[frame] = loadImage(fontRoot .. "image " .. frame .. ".png")
    end
end

function OriginalHUD:drawText(value, x, y)
    local text = tostring(value):upper()
    for index = 1, #text do
        local frame = text:byte(index) - string.byte(" ")
        local glyph = self.glyphs[frame]
        if glyph then love.graphics.draw(glyph, x, y) end
        x = x + 16
    end
end

function OriginalHUD:drawHeldItem(item)
    local layout = OriginalHUD.LAYOUT
    love.graphics.draw(self.images.held, layout.heldX, layout.heldY)
    if not item then return end

    local sprite = self.renderer.entitySprites[item.kind]
    if not sprite then return end
    local metadata = sprite.metadata
    love.graphics.draw(sprite.image,
        layout.heldX + 8 - metadata.originX,
        layout.heldY + 8 - metadata.originY)
end

function OriginalHUD:drawEquipment(equipment)
    local x, y = 32, 25
    for _, kind in ipairs(EQUIPMENT_ORDER) do
        if equipment and equipment[kind] then
            local sprite = self.renderer.entitySprites[kind]
            if sprite then
                local metadata = sprite.metadata
                love.graphics.draw(sprite.image, x + 8 - metadata.originX,
                    y + 8 - metadata.originY)
            else
                love.graphics.setColor(0.95, 0.78, 0.28, 1)
                love.graphics.rectangle("line", x + 2, y + 2, 11, 11)
                love.graphics.setColor(1, 1, 1, 1)
            end
            x = x + 16
        end
    end
end

function OriginalHUD:draw(state)
    self:loadAssets()
    local layout = OriginalHUD.LAYOUT
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.draw(self.images.heart, layout.lifeX, layout.top)
    self:drawText(math.max(0, state.health or 0), layout.lifeX + 16, layout.top)

    love.graphics.draw(state.stickyBombs and self.images.stickyBomb or self.images.bomb,
        layout.bombX, layout.top)
    self:drawText(state.bombs or 0, layout.bombX + 16, layout.top)

    love.graphics.draw(self.images.rope, layout.ropeX, layout.top)
    self:drawText(state.ropes or 0, layout.ropeX + 16, layout.top)

    love.graphics.draw(self.images.dollar, layout.moneyX, layout.top)
    self:drawText(state.money or 0, layout.moneyX + 16, layout.top)

    self:drawHeldItem(state.heldItem)
    self:drawEquipment(state.equipment)
    if state.compassDirection then self:drawText(state.compassDirection, 352, layout.top) end
    love.graphics.setColor(1, 1, 1, 1)
end

return OriginalHUD
