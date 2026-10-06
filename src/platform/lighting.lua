local Lighting = {}
local Collision = require("src.platform.sprite_collision")
local mask

local function gap(a, b)
    local dx = math.max(0, a[1]-b[3], b[1]-a[3])
    local dy = math.max(0, a[2]-b[4], b[2]-a[4])
    return math.sqrt(dx*dx+dy*dy)
end

function Lighting.darkness(game)
    local player = game.player
    local playerBounds = { Collision.bounds(player.spriteName, player.animationFrame,
        player.x, player.y, player.facing > 0) }
    local nearest = {}
    local function source(kind, sprite, frame, x, y, adjustment)
        local range = (player.x-x)^2+(player.y-y)^2
        if not nearest[kind] or range < nearest[kind].range then
            nearest[kind] = { range = range,
                distance = gap(playerBounds, { Collision.bounds(sprite, frame, x, y) })+(adjustment or 0) }
        end
    end
    for _, entity in ipairs(game.level.entities) do
        if not entity.destroyed then
            if entity.kind == "lamp" or entity.kind == "lamp_red" then
                source("lamp", entity.kind == "lamp_red" and "sLampRed" or "sLamp",
                    (game.world.time or 0)*0.5, entity.x*16, entity.y*16)
            elseif entity.kind == "arrow_trap_left_lit" or entity.kind == "arrow_trap_right_lit" then
                source(entity.kind, entity.kind == "arrow_trap_left_lit" and "sArrowTrapLeftLit"
                    or "sArrowTrapRightLit", game.world.time or 0, entity.x*16, entity.y*16, 48)
            end
        end
    end
    for _, item in ipairs(game.items) do
        if item.alive and not item.opened and item.definition.lightRadius then
            source(item.kind, item.definition.sprite.name, item.spriteFrame or 0, item.x, item.y)
        end
    end
    for _, explosion in ipairs(game.tools.explosions) do
        if explosion.alive then
            local frame = explosion.age*0.8
            source("explosion", "sExplosion", frame, explosion.x, explosion.y,
                frame <= 3 and -frame*16 or (frame-3)*16)
        end
    end
    for _, flash in ipairs(game.projectiles and game.projectiles.flashes or {}) do
        local name = flash.direction < 0 and "sShotgunBlastLeft" or "sShotgunBlastRight"
        source(name, name, flash.age, flash.x, flash.y)
    end
    local distance = 160
    for _, light in pairs(nearest) do distance = math.min(distance, light.distance) end
    -- Explosions may make darkness negative: source keeps their expanded radius.
    return math.min(0.9, distance/160)
end

local function tint(game, darkness)
    local player = game.player
    local bounds = { Collision.bounds(player.spriteName, player.animationFrame,
        player.x, player.y, player.facing > 0) }
    local red, green, blue = math.min(1, 1-darkness), math.min(1, 1-darkness), 1
    local function redLamps(group, kind, sprite, items)
        local distance
        for _, lamp in ipairs(group) do
            if lamp.kind == kind and not lamp.destroyed and (not items or lamp.alive and not lamp.opened) then
                local x, y = lamp.x*(items and 1 or 16), lamp.y*(items and 1 or 16)
                local frame = items and (lamp.spriteFrame or 0) or (game.world.time or 0)*0.5
                local range = gap(bounds, { Collision.bounds(sprite, frame, x, y) })
                distance = math.min(distance or range, range)
            end
        end
        if distance and distance <= 96 then
            red, green, blue = (255-distance)/255, (24+distance)/255, (24+distance)/255
        end
    end
    redLamps(game.level.entities, "lamp_red", "sLampRed", false)
    redLamps(game.items, "lamp_red_item", "sLampRedItem", true)
    return red, green, blue
end

-- oScreen.Begin Step draws darkSurf at 320x240 before enlarging screen.
-- Rasterize the source's 24-segment circles on that grid, then scale whole pixels.
function Lighting.draw(game, viewport)
    if not game.level.dark or game.player:isDead() then return end
    local darkness = Lighting.darkness(game)
    if not mask or mask:getWidth() ~= viewport.logicalWidth
        or mask:getHeight() ~= viewport.logicalHeight then
        if mask then mask:release() end
        mask = love.graphics.newCanvas(viewport.logicalWidth, viewport.logicalHeight,
            { dpiscale = 1, msaa = 0 })
        mask:setFilter("nearest", "nearest")
    end
    local screenX, screenY = love.graphics.transformPoint(0, 0)
    local offsetX = (screenX-viewport.x)/viewport.scale
    local offsetY = (screenY-viewport.y)/viewport.scale
    local function circle(x, y, radius)
        love.graphics.circle("fill", x+offsetX, y+offsetY, radius, 24)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(mask)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(tint(game, darkness))
    circle(game.player.x, game.player.y, 96-64*darkness)
    for _, entity in ipairs(game.level.entities) do
        if (entity.kind == "lamp" or entity.kind == "lamp_red") and not entity.destroyed then
            circle(entity.x*16+8, entity.y*16+8, 96)
        elseif not entity.destroyed and (entity.kind == "arrow_trap_left_lit"
            or entity.kind == "arrow_trap_right_lit") then
            circle(entity.x*16+8, entity.y*16+8, 32)
        end
    end
    for _, item in ipairs(game.items) do
        if item.alive and not item.opened and item.definition.lightRadius then
            circle(item.x, item.y+(item.kind == "lamp_item" and -4 or 0), 96)
        end
    end
    for _, explosion in ipairs(game.tools.explosions) do
        if explosion.alive then circle(explosion.x, explosion.y, 96) end
    end
    for _, treasure in ipairs(game.collectibles) do
        if treasure.alive and treasure.kind == "scarab" then circle(treasure.x, treasure.y, 16) end
    end
    for _, enemy in ipairs(game.enemies) do
        if enemy.alive and enemy.kind == "ghost" then
            -- Creature coordinates are eight right and sixteen below the source origin.
            circle(enemy.x+8, enemy.y, 64)
        end
    end
    love.graphics.pop()

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.draw(mask, viewport.x, viewport.y, 0, viewport.scale, viewport.scale)
    love.graphics.pop()
end
return Lighting
