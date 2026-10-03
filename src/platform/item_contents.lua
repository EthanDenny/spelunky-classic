local ItemContents = {}
local underground = {
    { "jetpack", 0, -2 }, { "cape" }, { "shotgun" }, { "mattock" },
    { "teleporter", 0, 3 }, { "gloves", 0, -1 }, { "spectacles" },
    { "web_cannon", -2 }, { "pistol" }, { "mitt", 0, -1 }, { "paste" },
    { "spring_shoes" }, { "spike_shoes" }, { "machete" },
    { "bomb_box", 0, -2 }, { "bow" }, { "compass" }, { "parachute" }, { "rope_pile" },
}
function ItemContents.underground(random)
    local choice = underground[random:random(1, #underground)]
    return choice[1], choice[2] or 0, choice[3] or 0
end

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
    if spec.requires and not run.hasKey then return nil end
    if spec.requires then run.hasKey = false end
    item.opened = true
    if spec.mode == "fixed" then
        if spec.scatter then
            return { { kind = spec.reward,
                vx = random:random(0, 3) - random:random(0, 3), vy = -2 } }
        end
        return { { kind = spec.reward } }
    elseif spec.roll then
        return spec.roll(random)
    end
    return rollChain(spec, random)
end

return ItemContents
