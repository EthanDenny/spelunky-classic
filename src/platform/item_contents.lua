local ItemContents = {}

local function rollChain(spec, random)
    for _, choice in ipairs(spec.rolls) do
        if random:random(1, choice.odds) == 1 then
            return { { kind = choice.kind } }
        end
    end
    return spec.fallback and { { kind = spec.fallback } } or {}
end

function ItemContents.open(item, run, random)
    local spec = item.definition.container
    if not spec or item.opened then return nil end
    if spec.requires and not run.hasKey then return nil, "IT'S LOCKED" end
    if spec.requires then run.hasKey = false end
    item.opened = true
    if spec.mode == "fixed" then
        if spec.scatter then
            return { { kind = spec.reward,
                vx = random:random(0, 3) - random:random(0, 3), vy = -2 } },
                spec.message
        end
        return { { kind = spec.reward } }, spec.message
    elseif spec.roll then
        return spec.roll(random), spec.message
    end
    return rollChain(spec, random), spec.message
end

return ItemContents
