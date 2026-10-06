local Progress = {}
Progress.__index = Progress
local FILE = "progress.cfg"

function Progress.new()
    -- scrResetHighscores stores one extra visit before each first request.
    return setmetatable({ tunnel1 = 100001, tunnel2 = 200001 }, Progress)
end

function Progress.load()
    local self = Progress.new()
    local contents = love.filesystem.read(FILE)
    if contents then
        local first, second = contents:match("^(%d+)%s+(%d+)%s*$")
        assert(first and second, "Could not read saved tunnel progress")
        self.tunnel1, self.tunnel2 = tonumber(first), tonumber(second)
    end
    return self
end

function Progress:save()
    assert(love.filesystem.write(FILE, string.format("%d\n%d\n", self.tunnel1, self.tunnel2)))
end

return Progress
