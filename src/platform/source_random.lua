-- Classic's rand(a,b) is floor(random(b-a+1))+a, using shared random state.
local Random = {}
Random.__index = Random

function Random.new(seed)
    return setmetatable({ source = love.math.newRandomGenerator(seed or 1) }, Random)
end

function Random:random(minimum, maximum)
    local unit = self.source:random()
    if minimum == nil then return unit end
    if maximum == nil then minimum, maximum = 1, minimum end
    return minimum+math.floor(unit*(maximum-minimum+1))
end

Random.integer = Random.random

return Random
