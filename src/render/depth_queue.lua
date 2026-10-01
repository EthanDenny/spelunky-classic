-- GameMaker draws larger depths first. Equal-depth order is not specified by
-- the source, so keep the caller's submission order stable.
local DepthQueue = {}
DepthQueue.__index = DepthQueue

function DepthQueue.new()
    return setmetatable({ entries = {} }, DepthQueue)
end

function DepthQueue:add(depth, draw)
    assert(type(depth) == "number" and type(draw) == "function", "Invalid draw command")
    self.entries[#self.entries + 1] = { depth = depth, order = #self.entries + 1, draw = draw }
end

function DepthQueue:draw()
    table.sort(self.entries, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.order < b.order
    end)
    for _, entry in ipairs(self.entries) do entry.draw() end
end

return DepthQueue
