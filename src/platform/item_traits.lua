-- Shared capabilities for per-kind item and pickup definitions.
local Traits = {}

local light = { standing = 2, ducking = 4 }
local heavy = { standing = -4, ducking = -2 }

function Traits.carry(spec)
    spec = spec or {}
    spec.carryable = true
    spec.hold = spec.hold or (spec.heavy and heavy or light)
    return spec
end

function Traits.money(value, sound)
    return { pickup = { money = value, sound = sound or "gem" } }
end

function Traits.equipment(price, bounds)
    return Traits.carry({ pickup = { equipment = true }, price = price,
        bounds = bounds or { 6, -6, 6 }, consumeOnPickup = true })
end

function Traits.supply(price, resource, amount, bounds)
    return Traits.carry({ pickup = { resource = resource, amount = amount }, price = price,
        bounds = bounds, consumeOnPickup = true })
end

return Traits
