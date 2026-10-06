local Room = {}
local World = require("src.platform.world")
local root = "original-game-reference/source/extracted/spelunky/"
local layouts, background, fringe, fringeQuads = {}, nil, nil, nil

function Room.new(name, random, graphicsHigh)
    if not layouts[name] then
        local layout = {}
        local xml = assert(love.filesystem.read(root .. "Rooms/" .. name .. ".xml"))
        for instance in xml:gmatch("<instance .->(.-)</instance>") do
            local object = instance:match("<object>(.-)</object>")
            local x, y = instance:match('<position x="(%d+)" y="(%d+)"')
            if object ~= "oPDummy" and object ~= "oTransition" and object ~= "oBricks" then
                layout[#layout+1] = { object = object, x = tonumber(x), y = tonumber(y) }
            end
        end
        layouts[name] = layout
    end
    local self = { tiles = {}, fringes = {}, world = World.new(20, 15, 16) }
    for _, tile in ipairs(layouts[name]) do
        local sprite = tile.object:gsub("^o", "s")
        if tile.object == "oBrick" then
            sprite = random:random(1,10) == 1 and "sBrick2" or "sBrick"
            local contents = random:random(1,100)
            if contents < 20 then sprite = "sBrickGold"
            elseif contents < 30 then sprite = "sBrickGoldBig" end
            self.world:set("solid", tile.x/16, tile.y/16)
        end
        self.tiles[#self.tiles+1] = { object = tile.object, sprite = sprite, x = tile.x, y = tile.y }
    end
    for _, tile in ipairs(self.tiles) do
        if tile.object == "oBrick" then
            local up = tile.y == 0 or self.world:solidAtPoint(tile.x, tile.y-16)
            local down = tile.y >= 224 or self.world:solidAtPoint(tile.x, tile.y+16)
            if not up then
                tile.sprite = down and "sCaveUp" or "sCaveUp2"
                if graphicsHigh then
                    self.fringes[#self.fringes+1] = { x = tile.x, y = tile.y-16,
                        variant = random:random(1,3) < 3 and 0 or 1 }
                end
            elseif not down then tile.sprite = "sBrickDown" end
        end
    end
    return self
end

function Room.draw(self, drawSprite)
    if not background then
        background = love.graphics.newImage(root .. "Backgrounds/bgCave.png")
        background:setFilter("nearest", "nearest")
    end
    for y = 0, 239, background:getHeight() do
        for x = 0, 319, background:getWidth() do love.graphics.draw(background, x, y) end
    end
    for _, tile in ipairs(self.tiles) do drawSprite(tile.sprite, 0, tile.x, tile.y) end
end

function Room.drawFringe(self)
    if not fringe then
        fringe = love.graphics.newImage(root .. "Backgrounds/bgCaveTop.png")
        fringe:setFilter("nearest", "nearest")
        fringeQuads = {
            love.graphics.newQuad(0, 0, 16, 16, fringe:getDimensions()),
            love.graphics.newQuad(16, 0, 16, 16, fringe:getDimensions()),
        }
    end
    for _, tile in ipairs(self.fringes) do
        love.graphics.draw(fringe, fringeQuads[tile.variant+1], tile.x, tile.y)
    end
end

return Room
