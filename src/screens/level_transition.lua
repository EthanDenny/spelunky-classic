-- oTransition's Mines intermission, without advancing the live level simulation.
local Font = require("src.ui.original_small_font")
local Collision = require("src.platform.sprite_collision")
local EntitySprites = require("src.world.original_entity_sprites")
local Room = require("src.render.transition_room")
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
    local tunnel
    local progress = game.app.progress
    if game.levelNumber == 4 and progress and progress.tunnel1 > 0 and progress.tunnel2 > 0 then
        if progress.tunnel1 > 100000 then progress.tunnel1 = progress.tunnel1-1
        else tunnel = require("src.platform.characters.tunnel_man").new(progress) end
    end
    local room = Room.new(game.levelNumber == 4 and "rTransition1x" or "rTransition1",
        game.effects.random, game.app.controls.settings.graphicsHigh)
    local ball = game.run.kaliPunish >= 2 and require("src.platform.item").new({ kind = "ball", x = 40/16, y = 186/16 })
    return setmetatable({
        room = room, tunnel = tunnel, ball = ball, accessoryFrame = 0,
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

function Transition:pressAction(start, game)
    if self.tunnel and self.tunnel.talk < 3 then
        if not start then self.tunnel:pressAction(game) end
        self.actorStopped = self.tunnel.talk > 0 and self.tunnel.talk < 3
        self.hurryup = true
        return false
    end
    if self:isReady() then return true end
    self.hurryup = true
    return false
end

function Transition:pressDirection(direction, game)
    if self.tunnel then self.tunnel:pressDirection(direction, game) end
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
local paths, sprites
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

function Transition:step(game, input)
    self.accessoryFrame = self.accessoryFrame+1
    if self.tunnel then
        self.tunnel:step(input or {}, game)
        if self.tunnel.talk == 0 and not self.actorGone
            and Collision.overlaps("sTunnelManLeft", 0, 104, 184, false,
                self.actorX+8, 184, self.actorX+9, 185, true) then
            self.tunnel.talk, self.actorStopped = 1, true
        end
    end
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
    if self.kissPause == 0 and not self.actorGone and not self.actorStopped then
        self.actorFrame = self.actorFrame+1
        if self.actorX < 280 then self.actorX = self.actorX+2
        elseif not self.actorExit then
            self.actorExit, self.actorFrame = true, 0
            game.sounds:play("steps")
        elseif self.actorFrame >= #sprite("sPExit").frames then self.actorGone = true end
    end
    if self.ball then
        require("src.platform.physical_body").stepItem(self.room.world, self.ball)
        local actor = { x = self.actorX, y = 184, facing = 1, animationFrame = self.actorFrame,
            spriteName = self.actorExit and "sPExit" or "sRunLeft" }
        if require("src.platform.entity_collision").distance(self.ball, actor, actor) >= 24 then
            self.ball.x = self.actorX-24
        end
        self.room.world.time = self.room.world.time+1
    end
end

local function drawSprite(name, frame, x, y, mirrored)
    local spec = sprite(name)
    love.graphics.draw(spec.frames[math.floor(frame or 0) % #spec.frames+1], x, y,
        0, mirrored and -1 or 1, 1, spec.ox, spec.oy)
end

local function time(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d", math.floor(seconds/60), seconds % 60)
end

function Transition:draw(game, viewport)
    love.graphics.push("all")
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale)
    love.graphics.setColor(1, 1, 1, 1)
    Room.draw(self.room, drawSprite)
    if self.ball then drawSprite("sBall", 0, self.ball.x, self.ball.y) end
    if not self.actorGone then
        local name = self.actorExit and "sPExit" or (self.kissPause > 0 or self.actorStopped) and "sStandLeft" or "sRunLeft"
        if not self.actorExit then
            if game.run.equipment.cape then
                drawSprite(name == "sRunLeft" and "sCapeRight" or "sCapeDR", self.accessoryFrame,
                    self.actorX-4, 182)
            end
            if game.run.equipment.jetpack then drawSprite("sJetpackRight", 0, self.actorX-4, 183) end
        end
        drawSprite(name, self.actorFrame, self.actorX, 184, true)
        local held = game.run.heldItem
        local metadata = held and EntitySprites[held.kind]
        if metadata and not self.actorExit then drawSprite(metadata.sourceSprite, 0, self.actorX+4, 186) end
        if self.actorExit and game.run.equipment.jetpack then drawSprite("sJetpackBack", 0, self.actorX, 184) end
    end
    Room.drawFringe(self.room)
    Room.drawPanel(self.room, drawSprite)
    for _, icon in ipairs(self.icons) do drawSprite(icon.sprite, 0, icon.x, icon.y) end
    if self.ball then
        for link = 1, 4 do
            drawSprite("sChain", 0, self.ball.x+(self.actorX-self.ball.x)*link/4,
                self.ball.y+(184-self.ball.y)*link/4)
        end
    end
    if self.actorExit and not self.actorGone and game.run.equipment.cape then
        drawSprite("sCapeBack", self.accessoryFrame, self.actorX, 188)
    end
    if self.tunnel then drawSprite("sTunnelManLeft", 0, 104, 184) end
    if self.rescued then
        drawSprite(self.kissFrame and not self.kissed and "sDamselKissL" or "sDamselLeft",
            self.kissFrame or 0, 184, 184)
        if self.kissed and not self.tunnel then Font.draw("MY HERO!", 128, 216) end
    end
    if self.tunnel then
        local lines, top = self.tunnel:dialogue()
        for index, text in ipairs(lines) do Font.draw(text, math.ceil((320-#text*8)/2), top+(index-1)*8) end
        if self.tunnel.talk == 2 then
            love.graphics.setColor(1, 1, 0, 1)
            Font.draw("DONATE: " .. self.tunnel.donate, math.ceil((320-#lines[2]*8)/2), 224)
        end
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
        Font.draw("$" .. self.moneyCount .. " / $" .. game.run.money, 96, 112)
    end
    love.graphics.pop()
end

return Transition
