-- Read the bundled GameMaker sprite masks independently of movement bounds.
local Collision = {}
local Mask = require("src.platform.sprite_mask")
local root = "original-game-reference/source/extracted/spelunky/Sprites"
local paths, sprites = nil, {}

local function index(directory)
    for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = directory .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info.type == "directory" and not name:match("%.images$") then index(path)
        elseif name:match("%.xml$") then paths[name:sub(1, -5)] = path end
    end
end

local function sprite(name)
    if sprites[name] then return sprites[name] end
    if not paths then paths = {}; index(root) end
    local path = assert(paths[name], "Unknown collision sprite: " .. tostring(name))
    local xml = assert(love.filesystem.read(path))
    local ox, oy = xml:match('<origin x="(%d+)" y="(%d+)"')
    local frames = {}
    local directory = path:sub(1, -5) .. ".images"
    for _, file in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local frame = file:match("^image (%d+)%.png$")
        if frame then frames[tonumber(frame)+1] = directory .. "/" .. file end
    end
    local result = { originX = tonumber(ox), originY = tonumber(oy), frames = frames,
        precise = xml:find("<shape>PRECISE</shape>", 1, true) ~= nil, masks = {} }
    assert(xml:find('mode="AUTO"', 1, true), "Unsupported sprite mask bounds: " .. name)
    assert(xml:find("<separate>true</separate>", 1, true), "Unsupported combined sprite mask: " .. name)
    sprites[name] = result
    return result
end

local function mask(sprite, frame)
    local index = math.floor(frame or 0) % #sprite.frames + 1
    if sprite.masks[index] then return sprite.masks[index] end
    local result = Mask.load(sprite.frames[index])
    sprite.masks[index] = result
    return result
end

function Collision.bounds(name, frame, x, y, mirrored, angle)
    local spec = sprite(name)
    local pixels = mask(spec, frame)
    if angle and math.abs(angle) > 0.000001 then
        local cos, sin = math.cos(angle), math.sin(angle)
        local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
        for row = pixels.top, pixels.bottom-1 do
            for column = pixels.left, pixels.right-1 do
                local dx = (column-spec.originX+0.5)*(mirrored and -1 or 1)
                local dy = row-spec.originY+0.5
                local px, py = math.floor(x+dx*cos-dy*sin), math.floor(y+dx*sin+dy*cos)
                left, top = math.min(left, px), math.min(top, py)
                right, bottom = math.max(right, px), math.max(bottom, py)
            end
        end
        return left, top, right, bottom
    end
    if mirrored then
        return x+spec.originX-pixels.right, y-spec.originY+pixels.top,
            x+spec.originX-pixels.left-1, y-spec.originY+pixels.bottom-1
    end
    return x-spec.originX+pixels.left, y-spec.originY+pixels.top,
        x-spec.originX+pixels.right-1, y-spec.originY+pixels.bottom-1
end

function Collision.overlaps(name, frame, x, y, mirrored, left, top, right, bottom, boundsOnly, angle)
    local spec = sprite(name)
    local pixels = mask(spec, frame)
    if angle and math.abs(angle) > 0.000001 then
        local cos, sin = math.cos(angle), math.sin(angle)
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for row = pixels.top, pixels.bottom-1 do
            for column = pixels.left, pixels.right-1 do
                if boundsOnly or not spec.precise or pixels.rows[row][column] then
                    local dx = (column-spec.originX+0.5)*(mirrored and -1 or 1)
                    local dy = row-spec.originY+0.5
                    local px, py = math.floor(x+dx*cos-dy*sin), math.floor(y+dx*sin+dy*cos)
                    if not boundsOnly and px < right and px+1 > left
                        and py < bottom and py+1 > top then return true end
                    x0, y0 = math.min(x0, px), math.min(y0, py)
                    x1, y1 = math.max(x1, px+1), math.max(y1, py+1)
                end
            end
        end
        return boundsOnly and x0 < right and x1 > left and y0 < bottom and y1 > top or false
    end
    return Mask.overlaps(pixels, mirrored and x+spec.originX or x-spec.originX,
        y-spec.originY, left, top, right, bottom, mirrored, boundsOnly or not spec.precise)
end

return Collision
