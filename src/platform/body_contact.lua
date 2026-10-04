-- Shared contact traversal; eligibility, geometry overrides, and response
-- remain with the source object that owns the interaction.
local Contact = {}

function Contact.moving(body, threshold)
    return math.abs(body.vx) > threshold or math.abs(body.vy) > threshold
end

function Contact.overlaps(body, actor, reach)
    local y = body.y+(body.physicsOriginY or 0)
    return actor:overlapsRectangle(body.x-reach, y-reach, body.x+reach, y+reach)
end

function Contact.scan(body, actors, reach, eligible, hit, overlaps)
    overlaps = overlaps or Contact.overlaps
    for _, actor in ipairs(actors or {}) do
        if eligible(actor) and overlaps(body, actor, reach) and hit(actor) then return end
    end
end

return Contact
