local PhysicalBody = {}

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

local function round(value)
    local integer = math.floor(value)
    if value - integer == 0.5 then
        return integer % 2 == 0 and integer or integer + 1
    end
    return math.floor(value + 0.5)
end

local function bounds(body)
    local halfWidth = body.getCollisionHalfWidth and body:getCollisionHalfWidth()
        or body.radius or 4
    local top, bottom = -halfWidth, halfWidth
    if body.getVerticalBounds then top, bottom = body:getVerticalBounds() end
    return halfWidth, top, bottom
end

-- moveTo pulses fractional velocity using oGame.time, with GM8 rounding.
function PhysicalBody.pixels(amount, time)
    local magnitude = math.abs(amount)
    local pixels = math.floor(magnitude)
    local fraction = magnitude - pixels
    if fraction ~= 0 then
        local period = round(1 / fraction)
        if period ~= 0 and (time or 0) % period == 0 then pixels = pixels + 1 end
    end
    return pixels * sign(amount)
end

function PhysicalBody.probe(world, body, axis, direction, distance, topInset)
    local halfWidth, top, bottom = bounds(body)
    distance = distance or 1
    if axis == "x" then
        local x = round(direction < 0 and body.x - halfWidth - distance
            or body.x + halfWidth + distance - 1)
        local y1 = round(body.y + top + (topInset or 0))
        local y2 = round(body.y + bottom - 1)
        return world:overlaps("solid", x, math.min(y1, y2), x + 1, math.max(y1, y2) + 1)
    end
    local y = round(direction < 0 and body.y + top - distance
        or body.y + bottom + distance - 1)
    return world:overlaps("solid", round(body.x - halfWidth), y,
        round(body.x + halfWidth - 1) + 1, y + 1)
end

-- Only oCharacter and its immediate children can land on oPlatform. Items,
-- bombs, damsels, and treasure move through platforms and ladder tops.
function PhysicalBody.move(world, body, axis, amount)
    local pixels = PhysicalBody.pixels(amount, world.time)
    local direction = sign(pixels)
    for _ = 1, math.abs(pixels) do
        local nextX = body.x + (axis == "x" and direction or 0)
        local nextY = body.y + (axis == "y" and direction or 0)
        if PhysicalBody.probe(world, body, axis, direction, 1, axis == "x" and 5 or 0) then
            return axis == "x" and "wall" or direction > 0 and "floor" or "ceiling"
        end
        body.x, body.y = nextX, nextY
    end
end

local function floorResponse(body)
    body.vy = body.vy > 1 and -body.vy * (body.bounceFactor or 0.5) or 0
    body.vx = math.abs(body.vx) < 0.1 and 0 or body.vx * (body.frictionFactor or 0.3)
end

local function separateSide(body, left, right, stopVertical)
    if left then
        if not right then body.x = body.x + 1 end
    elseif right then body.x = body.x - 1 end
    if stopVertical and (left or right) then body.vy = 0 end
end

local function impact(body, side, speed)
    local spec = body.definition and body.definition.breakOnImpact
    local key = (side == "left" or side == "right") and "wall" or side
    local threshold = spec and spec[key]
    if threshold and speed > threshold then
        body.justHit = true
        body.impactSide = body.impactSide or side
    end
end

local function escapeSolid(world, body)
    if not world:solidAtPoint(body.x, body.y + (body.physicsOriginY or 0)) then return false end
    local left = PhysicalBody.probe(world, body, "x", -1)
    local right = PhysicalBody.probe(world, body, "x", 1)
    local top = PhysicalBody.probe(world, body, "y", -1)
    local bottom = PhysicalBody.probe(world, body, "y", 1)
    if top and not bottom then body.y = body.y + 1
    elseif left and not right then body.x = body.x + 1
    elseif right and not left then body.x = body.x - 1
    else body.vx, body.vy = 0, 0 end
    return true
end

-- The oItem parent, oDice override, and oJar/oSkull overrides share movement,
-- but deliberately keep their different gravity/contact ordering.
function PhysicalBody.stepItem(world, body)
    local rule = body.definition and body.definition.flight or "item"
    if rule == "item" and escapeSolid(world, body) then return end
    PhysicalBody.move(world, body, "x", body.vx)
    PhysicalBody.move(world, body, "y", body.vy)
    local left = PhysicalBody.probe(world, body, "x", -1)
    local right = PhysicalBody.probe(world, body, "x", 1)
    local bottom = PhysicalBody.probe(world, body, "y", 1)
    local top = PhysicalBody.probe(world, body, "y", -1)
    local gravity = body.gravity or 0.6

    if rule == "fragile" then
        if body.vy < 6 then body.vy = body.vy + gravity end
        if top and body.vy < 0 then
            impact(body, "ceiling", -body.vy)
            body.vy = -body.vy * 0.8
        end
        if left or right then
            impact(body, body.vx < 0 and "left" or "right", math.abs(body.vx))
            body.vx = -body.vx * 0.5
        end
        if body.definition and body.definition.breakWhenEmbedded
            and world:solidAtPoint(body.x, body.y) then
            body.justHit, body.impactSide = true, body.impactSide or "embedded"
        end
        if bottom then
            impact(body, "floor", body.vy)
            floorResponse(body)
        end
        separateSide(body, left, right, true)
        if PhysicalBody.probe(world, body, "y", 1, 0) and math.abs(body.vy) < 1 then
            body.y, body.vy = body.y - 1, 0
        end
    else
        if not left and not right then body.stuck = false end
        if not bottom and not body.stuck and (rule ~= "die" or body.vy < 6) then
            body.vy = body.vy + gravity
        end
        if rule ~= "die" then body.vy = math.min(8, body.vy) end
        if left or right then body.vx = -body.vx * 0.5 end
        if bottom then
            floorResponse(body)
            if math.abs(body.vy) < 1 then
                body.y = body.y - 1
                if not PhysicalBody.probe(world, body, "y", 1) then body.y = body.y + 1 end
                body.vy = 0
            end
        end
        if body.sticky then
            body.stuck = not not (left or right or top or bottom)
            if body.stuck then
                body.vx, body.vy = 0, 0
                if bottom then body.y = body.y + 1 end
            end
        elseif body.definition and body.definition.stickOnWall
            and math.abs(body.vx) > body.definition.stickOnWall then
            if left then body.x, body.vx, body.vy = body.x - 2, 0, 0
            elseif right then body.x, body.vx, body.vy = body.x + 2, 0, 0 end
            body.stuck = true
        elseif not body.stuck then
            separateSide(body, left, right)
        end
        if not body.sticky and PhysicalBody.probe(world, body, "y", -1) then
            if body.vy < 0 then body.vy = -body.vy * 0.8
            else body.y = body.y + 1 end
        end
        if rule == "item" then body.gravity = 0.6 end
    end
end

-- oItem passes part of its velocity to the enemy; the item itself keeps flying.
function PhysicalBody.strikeEnemy(body, enemy)
    if enemy.stunned and enemy.stunned > 0 then return false end
    local fragile = body.definition and body.definition.flight == "fragile"
    local stunOnly = fragile and enemy.kind == "caveman"
    return enemy:damage(stunOnly and 0 or 1, body.x, {
        kind = "item", fragile = fragile, vx = body.vx * 0.3,
        vy = enemy.kind == "caveman" and -6 or nil,
    })
end

-- Classic oWeb stops loose oItem/oTreasure motion. Rope and held objects are
-- exempt; the same check also applies to thrown bombs (an oItem child).
function PhysicalBody.stopInWeb(world, body)
    if body.held or body.kind == "rope" then return false end
    local halfWidth = body.getCollisionHalfWidth and body:getCollisionHalfWidth()
        or body.radius or 4
    local topOffset, bottomOffset = -4, 4
    if body.getVerticalBounds then
        topOffset, bottomOffset = body:getVerticalBounds()
    elseif body.radius then
        topOffset, bottomOffset = -body.radius, body.radius
    end
    if not world:webRect(body.x - halfWidth, body.y + topOffset,
        body.x + halfWidth, body.y + bottomOffset) then return false end
    body.vx, body.vy = 0, 0
    body.xRemainder, body.yRemainder = 0, 0
    return true
end

return PhysicalBody
