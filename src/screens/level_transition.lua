-- oTransition's Mines intermission, without advancing the live level simulation.
local Font = require("src.ui.original_small_font")
local Collision = require("src.platform.sprite_collision")
local EntitySprites = require("src.world.original_entity_sprites")
local Transition = {}
Transition.__index = Transition

-- Alarm 0 consumes the source counters in this order.
local LOOT = {
    { "gold_chunk", "sGoldChunk" }, { "emerald", "sEmerald" },
    { "sapphire", "sSapphire" }, { "ruby", "sRuby" },
    { "gold_nugget", "sGoldNugget" }, { "gold_bar", "sGoldBarDraw" },
    { "gold_bars", "sGoldBarsDraw" }, { "emerald_big", "sEmeraldBig" },
    { "sapphire_big", "sSapphireBig" }, { "ruby_big", "sRubyBig" },
    { "diamond", "sDiamond" }, { "damsel", "sDamselLeft" },
    { "scarab", "sScarabDisp" }, { "gold_idol", "sGoldIdolIco" },
}
local KILLS = {
    { "bat", "sBatLeft" }, { "snake", "sSnakeLeft" }, { "spider", "sSpider" },
    { "skeleton", "sSkeletonLeft" }, { "caveman", "sCavemanLeft" },
    { "giant_spider", "sGiantSpiderDisp" }, { "damsel", "sDamselLeftIco" },
    { "shopkeeper", "sShopLeftIco" },
}

local function entries(order, counts)
    local result = {}
    for _, entry in ipairs(order) do
        for _ = 1, counts[entry[1]] or 0 do result[#result+1] = entry[2] end
    end
    return result
end

function Transition.new(game)
    local loot = {}
    for kind, count in pairs(game.levelStats.loot) do loot[kind] = count end
    loot.damsel = game.rescues or 0
    return setmetatable({
        levelNumber = game.levelNumber, levelTime = game.levelTime, totalTime = game.run.time,
        money = game.levelStats.money, totalMoney = game.run.money, moneyCount = 0,
        loot = entries(LOOT, loot), kills = entries(KILLS, game.levelStats.kills),
        icons = {}, phase = -2, alarm0 = 10, alarm1 = 30, hurryup = false,
        lootIndex = 1, killIndex = 1, drawX = 100, drawY = 83,
        actorX = 40, actorFrame = 0, actorExit = false, actorGone = false,
        rescued = loot.damsel > 0, kissFrame = nil, kissed = false, kissPause = 0,
    }, Transition)
end

function Transition:isReady()
    return self.phase == 2 and self.moneyCount == self.money
end

function Transition:pressAction()
    if self:isReady() then return true end
    self.hurryup = true
    return false
end

function Transition:emitIcon()
    if self.phase < 0 then return end
    if self.phase == 0 and self.drawX > 272 then
        self.drawX, self.drawY = 100, self.drawY+2
        if self.drawY > 87 then self.drawY = 83 end
    elseif self.phase == 1 and self.drawX > 232 then
        self.drawX, self.drawY = 96, self.drawY+2
        if self.drawY > 95 then self.drawY = 91 end
    end
    local sprite
    if self.phase == 0 then
        sprite = self.loot[self.lootIndex]
        if sprite then self.lootIndex = self.lootIndex+1
        else self.phase, self.drawX, self.drawY = 1, 96, 91 end
    end
    if self.phase == 1 then
        sprite = self.kills[self.killIndex]
        if sprite then self.killIndex = self.killIndex+1 else self.phase = 2 end
    end
    if sprite then
        self.icons[#self.icons+1] = { sprite = sprite, x = self.drawX, y = self.drawY }
        self.drawX = self.drawX+(self.phase == 0 and 4 or 8)
    end
end

local root = "original-game-reference/source/extracted/spelunky/"
local paths, sprites, room, background
local function index(directory)
    for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = directory .. "/" .. name
        if love.filesystem.getInfo(path).type == "directory" and not name:match("%.images$") then
            index(path)
        elseif name:match("%.xml$") then paths[name:sub(1, -5)] = path end
    end
end

local function sprite(name)
    if not paths then paths, sprites = {}, {}; index(root .. "Sprites") end
    if sprites[name] then return sprites[name] end
    local path = assert(paths[name], "Unknown transition sprite: " .. name)
    local xml = assert(love.filesystem.read(path))
    local ox, oy = xml:match('<origin x="(%d+)" y="(%d+)"')
    local frames = {}
    local directory = path:sub(1, -5) .. ".images"
    for _, file in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local frame = file:match("^image (%d+)%.png$")
        if frame then
            local image = love.graphics.newImage(directory .. "/" .. file)
            image:setFilter("nearest", "nearest")
            frames[tonumber(frame)+1] = image
        end
    end
    local result = { frames = frames, ox = tonumber(ox), oy = tonumber(oy) }
    sprites[name] = result
    return result
end

function Transition:step(game)
    self.alarm1 = self.alarm1-1
    if self.alarm1 == 0 then
        self.phase = self.phase+1
        self.alarm1 = self.phase < 0 and (self.hurryup and 1 or 30) or -1
    end
    self.alarm0 = self.alarm0-1
    if self.alarm0 == 0 then
        self:emitIcon()
        self.alarm0 = self.phase ~= 2 and (self.hurryup and 1 or 3) or -1
    end
    if self.phase == 2 then
        self.moneyCount = self.hurryup and self.money or math.min(self.money, self.moneyCount+100)
    end

    if self.kissPause > 0 then self.kissPause = self.kissPause-1 end
    if self.rescued and not self.kissed and not self.kissFrame
        and Collision.overlaps("sDamselLeft", 0, 184, 184, false,
            self.actorX+8, 184, self.actorX+9, 185) then
        self.kissFrame, self.kissPause = 0, 30
    end
    if self.kissFrame and not self.kissed then
        local previous = self.kissFrame
        self.kissFrame = self.kissFrame+0.5
        if previous < 7 and self.kissFrame >= 7 then game.sounds:play("kiss") end
        if self.kissFrame >= #sprite("sDamselKissL").frames then self.kissed = true end
    end
    if self.kissPause == 0 and not self.actorGone then
        self.actorFrame = self.actorFrame+1
        if self.actorX < 280 then self.actorX = self.actorX+2
        elseif not self.actorExit then
            self.actorExit, self.actorFrame = true, 0
            game.sounds:play("steps")
        elseif self.actorFrame >= #sprite("sPExit").frames then self.actorGone = true end
    end
end

local function drawSprite(name, frame, x, y, mirrored)
    local spec = sprite(name)
    love.graphics.draw(spec.frames[math.floor(frame or 0) % #spec.frames+1], x, y,
        0, mirrored and -1 or 1, 1, spec.ox, spec.oy)
end

local function loadRoom()
    room = {}
    local bricks = {}
    local xml = assert(love.filesystem.read(root .. "Rooms/rTransition1.xml"))
    for instance in xml:gmatch("<instance .->(.-)</instance>") do
        local object = instance:match("<object>(.-)</object>")
        local x, y = instance:match('<position x="(%d+)" y="(%d+)"')
        x, y = tonumber(x), tonumber(y)
        if object == "oBrick" then bricks[x .. ":" .. y] = true end
        if object ~= "oPDummy" and object ~= "oTransition" and object ~= "oBricks" then
            room[#room+1] = { object = object, x = x, y = y }
        end
    end
    for _, tile in ipairs(room) do
        if tile.object == "oBrick" then
            local up = tile.y == 0 or bricks[tile.x .. ":" .. (tile.y-16)]
            local down = tile.y >= 224 or bricks[tile.x .. ":" .. (tile.y+16)]
            tile.sprite = up and (down and "sBrick" or "sBrickDown")
                or (down and "sCaveUp" or "sCaveUp2")
        else tile.sprite = tile.object:gsub("^o", "s") end
    end
    background = love.graphics.newImage(root .. "Backgrounds/bgCave.png")
    background:setFilter("nearest", "nearest")
end

local function time(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d", math.floor(seconds/60), seconds % 60)
end

function Transition:draw(game, viewport)
    if not room then loadRoom() end
    love.graphics.push("all")
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale)
    love.graphics.setColor(1, 1, 1, 1)
    for y = 0, 239, background:getHeight() do
        for x = 0, 319, background:getWidth() do love.graphics.draw(background, x, y) end
    end
    for _, tile in ipairs(room) do drawSprite(tile.sprite, 0, tile.x, tile.y) end
    for _, icon in ipairs(self.icons) do drawSprite(icon.sprite, 0, icon.x, icon.y) end
    if not self.actorGone then
        local name = self.actorExit and "sPExit" or self.kissPause > 0 and "sStandLeft" or "sRunLeft"
        drawSprite(name, self.actorFrame, self.actorX, 184, true)
        local held = game.run.heldItem
        local metadata = held and EntitySprites[held.kind]
        if metadata and not self.actorExit then drawSprite(metadata.sourceSprite, 0, self.actorX+4, 186) end
    end
    if self.rescued then
        drawSprite(self.kissFrame and not self.kissed and "sDamselKissL" or "sDamselLeft",
            self.kissFrame or 0, 184, 184)
        if self.kissed then Font.draw("MY HERO!", 128, 216) end
    end
    love.graphics.setColor(1, 1, 0, 1)
    Font.draw("LEVEL " .. self.levelNumber .. " COMPLETED!", 32, 48)
    love.graphics.setColor(1, 1, 1, 1)
    for index, label in ipairs({ "TIME  = ", "LOOT  = ", "KILLS = ", "MONEY = " }) do
        Font.draw(label, 32, 48+index*16)
    end
    if self.phase > -2 then Font.draw(time(self.levelTime) .. " / " .. time(self.totalTime), 96, 64) end
    if self.phase >= 1 and #self.loot == 0 then Font.draw("NONE", 96, 80) end
    if self.phase == 2 then
        if #self.kills == 0 then Font.draw("NONE", 96, 96) end
        Font.draw("$" .. self.moneyCount .. " / $" .. self.totalMoney, 96, 112)
    end
    love.graphics.pop()
end

return Transition
