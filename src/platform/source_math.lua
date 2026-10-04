-- Shared fractional travel; callers retain their existing rounding and clock.
local Math = {}

function Math.roundEven(value)
    local integer = math.floor(value)
    if value-integer == 0.5 then return integer % 2 == 0 and integer or integer+1 end
    return math.floor(value+0.5)
end

function Math.roundHalfUp(value)
    return math.floor(value+0.5)
end

function Math.pixels(amount, time, round)
    local magnitude = math.abs(amount)
    local pixels = math.floor(magnitude)
    local fraction = magnitude-pixels
    if fraction ~= 0 then
        local period = (round or Math.roundEven)(1/fraction)
        if period ~= 0 and (time or 0) % period == 0 then pixels = pixels+1 end
    end
    return amount < 0 and -pixels or pixels
end

function Math.halfUpPixels(amount, time)
    return Math.pixels(amount, time, Math.roundHalfUp)
end

return Math
