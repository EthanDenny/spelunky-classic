local Timing = {}

local ORIGINAL_FPS = 30

function Timing.scaledTicks(ticks, tickRate)
    return math.max(1, math.floor(ticks * tickRate / ORIGINAL_FPS + 0.5))
end

return Timing
