local Assets = require("src.platform.object_assets")
local Font = require("src.ui.original_small_font")
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

-- scrDrawHUD only draws these pickup types inside sHoldItemIcon. Heavy
-- carryables (including crates and idols) leave the icon's center empty.
local HELD_SLOT_ITEMS = {
    rock = true, jar = true, skull = true, arrow = true,
    machete = true, mattock = true, pistol = true, web_cannon = true,
    teleporter = true, shotgun = true, bow = true, key = true,
    flare = true, mattock_head = true,
}

local EQUIPMENT_ORDER = {
    { "udjat_eye", "sUdjatEyeIcon", "Items/Saleable" },
    { "ankh", "sAnkhIcon", "Items/Saleable" },
    { "crown", "sCrownIcon", "Items/Saleable" },
    { "kapala", "sKapalaIcon" }, { "spectacles", "sSpectaclesIcon" },
    { "gloves", "sGlovesIcon" }, { "mitt", "sMittIcon" },
    { "spring_shoes", "sSpringShoesIcon" }, { "spike_shoes", "sSpikeShoesIcon" },
    { "cape", "sCapeIcon" }, { "jetpack", "sJetpackIcon" },
    { "compass", "sCompassIcon" }, { "parachute", "sParachuteIcon" },
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
    self.images.bowDisplay = loadImage(
        "original-game-reference/source/extracted/spelunky/Sprites/Items/Saleable/"
            .. "sBowDisp.images/image 0.png")
    local compassRoot = "original-game-reference/source/extracted/spelunky/Sprites/Items/Saleable/"
    for _, direction in ipairs({ "LL", "LR", "Down", "Left", "Right" }) do
        self.images["compass" .. direction] = loadImage(compassRoot
            .. "sCompass" .. direction .. ".images/image 0.png")
    end

    for _, entry in ipairs(EQUIPMENT_ORDER) do
        self.images[entry[1]] = {}
        for frame = 0, entry[1] == "kapala" and 4 or 0 do
            self.images[entry[1]][frame+1] = Assets.image(entry[3] or "HUD", entry[2], frame)
        end
    end
    self.images.udjatBlink = Assets.image("Items/Saleable", "sUdjatEyeIcon2")
    self.images.arrowIcon = Assets.image("HUD", "sArrowIcon")
    for _, direction in ipairs({ "LL", "LR", "Down", "Left", "Right" }) do
        self.images["compassSmall" .. direction] = Assets.image("Items/Saleable", "sCompassSmall" .. direction)
    end
    self.glyphs = {}
    local fontRoot = "original-game-reference/source/extracted/config/Sprites/sFont.images/"
    for frame = 0, 58 do
        self.glyphs[frame] = loadImage(fontRoot .. "image " .. frame .. ".png")
    end
end

function OriginalHUD:drawCompass(compass, messageTimer)
    if not compass then return end
    local exitX = compass.exitX - compass.cameraX
    local exitY = compass.exitY - compass.cameraY
    local width, height = compass.width, compass.height
    local image, x, y
    if exitY > height then
        y = height - 16
        if exitX < 0 then image, x = self.images.compassLL, 0
        elseif exitX > width - 16 then image, x = self.images.compassLR, width - 16
        else image, x = self.images.compassDown, exitX end
    elseif exitX < 0 then
        image, x, y = self.images.compassLeft, 0, exitY
    elseif exitX > width - 16 then
        image, x, y = self.images.compassRight, width - 16, exitY
    end
    if image then
        if (messageTimer or 0) > 0 then
            for _, direction in ipairs({ "LL", "LR", "Down", "Left", "Right" }) do
                if image == self.images["compass" .. direction] then
                    image = self.images["compassSmall" .. direction]; break
                end
            end
        end
        love.graphics.draw(image, math.floor(x), math.floor(y))
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
    if not item or not HELD_SLOT_ITEMS[item.kind] then return end

    if item.kind == "bow" then
        love.graphics.draw(self.images.bowDisplay, layout.heldX, layout.heldY)
        return
    end

    local sprite = self.renderer.entitySprites[item.kind]
    if not sprite then return end
    local metadata = sprite.metadata
    love.graphics.draw(sprite.image,
        layout.heldX + 8 - metadata.originX,
        layout.heldY + 8 - metadata.originY)
end

function OriginalHUD:drawEquipment(equipment, blood, udjatBlink)
    local x = 28
    for _, entry in ipairs(EQUIPMENT_ORDER) do
        local kind = entry[1]
        if equipment and equipment[kind] then
            local frame = kind == "kapala" and math.min(4, math.ceil((blood or 0)/2)) or 0
            local image = kind == "udjat_eye" and udjatBlink and self.images.udjatBlink
                or self.images[kind][frame+1]
            love.graphics.draw(image, x, 24)
            x = x+20
        end
    end
    return x
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
    local nextX = self:drawEquipment(state.equipment, state.blood, state.udjatBlink)
    if state.heldItem and state.heldItem.kind == "bow" then
        for index = 0, (state.arrows or 0)-1 do love.graphics.draw(self.images.arrowIcon, nextX+index*4, 24) end
    end
    self:drawCompass(state.compass, state.messageTimer)
    if (state.pendingMoney or 0) > 0 then
        love.graphics.setColor(1, 1, 0, 1)
        Font.draw("+"..state.pendingMoney, layout.moneyX, 24)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return OriginalHUD
