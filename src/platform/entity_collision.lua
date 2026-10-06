local Collision = require("src.platform.sprite_collision")
local EntitySprites = require("src.world.original_entity_sprites")
local EntityCollision = {}

local function animationSprite(target)
    local spec = target.spec
    local animation = spec.animations[target.animationName or spec.fallback]
    local path = animation.paths[1]
    local metadata = EntitySprites[path:match("/entities/([^/]+)%.png$") or target.kind]
    local name = path:match("/animations/([^/]+)/") or path:match("/([^/]+)%.images/")
        or metadata.sourceSprite
    return name, target.animation, target.x-8, target.y-16, false
end

local function pose(target, player)
    if target == player then
        return target.spriteName, target.animationFrame, target.x, target.y, target.facing > 0
    end
    if target.spec and target.spec.animations and not target.config then return animationSprite(target) end
    if target.spec and target.spec.collisionSprite then return target.spec.collisionSprite(target) end
    if target.spriteName and target.config then
        return target.spriteName, target.animation, target.x-target.width/2, target.y-target.height, false
    end
    if target.kind == "rope" then
        if target.deployed then return nil end
        return "sRopeEnd", 0, target.x, target.y, false
    end
    if target.kind == "bomb" then
        return target.armed and "sBombArmed" or "sBomb", target.animation, target.x, target.y, false
    end
    if target.kind == "arrow" then return "sArrowRight", 0, target.x, target.y, false, target.arrowAngle end
    if target.kind == "ball" then return "sBall", 0, target.x, target.y, false end
    if target.kind == "push_block" then return "sBlock", 0, target.x, target.y, false end
    if target.kind == "boulder" then
        local name = target.vx < 0 and "sBoulderRotateL" or target.vx > 0 and "sBoulderRotateR" or "sBoulder"
        return name, target.animation, target.x, target.y, false
    end
    local definition = target.definition
    if not definition or not (definition.carryable or definition.pickup) then return nil end
    if definition.collisionSprite then return definition.collisionSprite(target) end
    local sprite = definition.sprite
    local metadata = EntitySprites[target.kind]
    local name = sprite and sprite.name or metadata and metadata.sourceSprite
    if not name then return nil end
    local anchor = definition.treasureAnchor
    return name, 0, target.x-(anchor and anchor[1] or 0),
        target.y-(anchor and anchor[2] or 0), false
end

function EntityCollision.overlaps(target, player, left, top, right, bottom, boundsOnly)
    local name, frame, x, y, mirrored, angle = pose(target, player)
    if not name then return false end
    return Collision.overlaps(name, frame, x, y, mirrored, left, top, right, bottom, boundsOnly, angle)
end

function EntityCollision.bounds(target, player)
    local name, frame, x, y, mirrored = pose(target, player)
    if not name then return target:getBounds() end
    local left, top, right, bottom = Collision.bounds(name, frame, x, y, mirrored)
    return left, top, right+1, bottom+1
end

function EntityCollision.touching(a, b, player)
    local al, at, ar, ab = EntityCollision.bounds(a, player)
    local bl, bt, br, bb = EntityCollision.bounds(b, player)
    local left, top = math.max(al, bl), math.max(at, bt)
    local right, bottom = math.min(ar, br), math.min(ab, bb)
    if left >= right or top >= bottom then return false end
    for y = math.floor(top), math.ceil(bottom)-1 do
        for x = math.floor(left), math.ceil(right)-1 do
            if EntityCollision.overlaps(a, player, x, y, x+1, y+1)
                and EntityCollision.overlaps(b, player, x, y, x+1, y+1) then return true end
        end
    end
    return false
end

function EntityCollision.distance(a, b, player)
    local al, at, ar, ab = EntityCollision.bounds(a, player)
    local bl, bt, br, bb = EntityCollision.bounds(b, player)
    local dx = math.max(0, al-br+1, bl-ar+1)
    local dy = math.max(0, at-bb+1, bt-ab+1)
    return math.sqrt(dx*dx+dy*dy)
end

return EntityCollision
