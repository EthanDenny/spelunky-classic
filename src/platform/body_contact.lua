-- Shared contact traversal; eligibility, geometry overrides, and response
-- remain with the source object that owns the interaction.
local Contact = {}
local Collision = require("src.platform.entity_collision")

function Contact.moving(body, threshold)
    return math.abs(body.vx) > threshold or math.abs(body.vy) > threshold
end

function Contact.overlaps(body, actor, reach)
    local y = body.y+(body.physicsOriginY or 0)
    return Collision.overlaps(actor, nil, body.x-reach, y-reach, body.x+reach+1, y+reach+1, true)
end

function Contact.enemy(actor)
    return actor.kind ~= "ghost" and actor.kind ~= "damsel" and (actor.alive or actor.corpse)
end

function Contact.find(body, actors, reach, damsel, nearest, rectangle)
    local contact, closest, distance
    local y = body.y+(body.physicsOriginY or 0)
    for _, actor in ipairs(actors or {}) do
        if actor ~= body and (damsel and actor.kind == "damsel" and (actor.alive or actor.corpse)
            or not damsel and Contact.enemy(actor)) then
            local overlaps = rectangle and Collision.overlaps(actor, nil,
                rectangle[1], rectangle[2], rectangle[3], rectangle[4], true)
                or not rectangle and Contact.overlaps(body, actor, reach)
            if overlaps and not contact then contact = actor end
            if nearest then
                local x0, y0 = Collision.origin(actor)
                local d = (x0-body.x)^2+(y0-y)^2
                if not distance or d < distance then closest, distance = actor, d end
            end
        end
    end
    return contact and (nearest and closest or contact)
end

return Contact
