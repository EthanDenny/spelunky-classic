local Traits = require("src.platform.item_traits")
local Assets = require("src.platform.object_assets")

local Rope = { depth = 200 }
Rope.__index = Rope
local Holdable = require("src.platform.holdable")
Rope.definition = Traits.body({ impactOnce = true, hold = { standing = 2, ducking = 4 } })

function Rope:getCollisionHalfWidth() return 4 end
function Rope:getVerticalBounds() return -4, 4 end
function Rope:updateHeldPosition(player) Holdable.position(self, player) end
function Rope:dropFromHurt(player)
    Holdable.dropFromHurt(self, player)
    self.armed = true
end

function Rope.hold(tools, player)
    local rope = setmetatable({ kind = "rope", definition = Rope.definition,
        x = player.x, y = player.y, launchX = player.x, vx = 0, vy = 0,
        gravity = 0.6, radius = 4, alive = true, held = true, armed = false,
        segments = {} }, Rope)
    rope:updateHeldPosition(player)
    tools.ropes[#tools.ropes+1] = rope
    return rope
end

function Rope.definition.useHeld(game, held, input)
    local rope = Rope.throwFromPlayer(game.tools, game.player, input, held)
    if not rope then return false end
    held.alive, held.held = false, false
    require("src.platform.item_cycle").restore(game)
    if game.throwSound then game.throwSound:clone():play() end
    return true
end

function Rope.definition.onEnemyHit(rope, enemy, context)
    if context and context.onRopeHit then context:onRopeHit(enemy, rope) end
end

local function snap(value, grid)
    return math.floor(value / grid + 0.5) * grid
end

local function ropeSideClear(world, gridX, candidateX, y)
    local left = candidateX < gridX and candidateX or candidateX - 1
    return not world:solidRect(left, y, left + 2, y + 17)
end

function Rope.throwFromPlayer(self, player, input, held)
    if player.whipping or player:isDead() or player:isStunned() then return nil end
    local downward = input and input.down
    if not downward and self.world:collidesSolid(player, player.x, player.y - 1) then
        return nil
    end
    local rope = {
        kind = "rope",
        definition = Rope.definition,
        radius = 4,
        gravity = 0.6,
        launchX = player.x,
        x = player.x,
        y = player.y,
        vx = 0,
        vy = -12,
        deploying = false,
        deployed = false,
        segments = {},
        alive = true,
        armed = true,
    }
    local function fallback()
        if held then
            rope.x, rope.y, rope.vx, rope.vy = held.x, held.y, player.facing*3.2, 0.5
        end
        self.ropes[#self.ropes+1] = rope
        return rope
    end
    if downward then
        local direction = player.facing < 0 and -1 or 1
        local gridX = snap(player.x + direction * 16, self.world.tileSize)
        local gridY = snap(player.y, 1)
        -- oPlayer1 first checks the side of the player, then tries the edge
        -- nearest the player and finally the far edge of the snapped cell.
        if self.world:solidAtPoint(player.x + direction * 8, player.y) then
            return fallback()
        end
        local nearX = gridX - direction * 8
        local farX = gridX + direction * 8
        if ropeSideClear(self.world, gridX, nearX, gridY) then
            rope.x = nearX
        elseif ropeSideClear(self.world, gridX, farX, gridY) then
            rope.x = farX
        else
            return fallback()
        end
        rope.y = gridY
        rope.vy = 0
        self:deployRope(rope)
    end
    self.ropes[#self.ropes + 1] = rope
    return rope
end

function Rope.deploy(self, rope)
    local tileSize = self.world.tileSize
    -- GameMaker's move_snap(16, 1) keeps the vertical hook position at
    -- pixel precision; only the horizontal axis snaps to the tile grid.
    rope.y = snap(rope.y, 1)
    rope.vx, rope.vy = 0, 0
    rope.deploying = true
    rope.deployed = true
    rope.deployY = rope.y
    rope.segmentCount = 0
    self.world:set("rope", math.floor(rope.x / tileSize), math.floor(rope.y / tileSize), "deployed")
end

function Rope.anchor(self, rope)
    -- oRopeThrow snaps to the grid, then shifts toward its launch point
    -- unless that half-cell is blocked.
    local gridX = snap(rope.x, self.world.tileSize)
    local nearX = gridX + (rope.launchX < gridX and -8 or 8)
    local farX = gridX + (rope.launchX < gridX and 8 or -8)
    rope.x = self.world:solidAtPoint(nearX, rope.y) and farX or nearX
    self:deployRope(rope)
end

function Rope.update(self, rope, enemies)
    if rope.held then
        if self.game then rope:updateHeldPosition(self.game.player) end
        return
    end
    if rope.deploying then
        local nextY = rope.deployY + 8
        rope.segmentCount = rope.segmentCount + 1
        if rope.segmentCount > 16
            or self.world:solidRect(rope.x - 3, nextY - 3, rope.x + 3, nextY + 4) then
            rope.deploying = false
            return
        end
        rope.deployY = nextY
        rope.segments[#rope.segments + 1] = nextY
        self.world:set("rope", math.floor(rope.x / self.world.tileSize),
            math.floor(nextY / self.world.tileSize), "deployed")
        return
    end
    if rope.deployed then return end

    -- Only the flying end owns item-body behavior; deployed segments do not.
    rope.definition.bodyStep(self.world, rope, nil, self, enemies)
    if rope.vy >= 0 then
        self:anchorThrownRope(rope)
        self:updateRope(rope, enemies)
    end
end

function Rope.draw(self, rope)
    if not self.assets or not rope.alive then return end
    love.graphics.setColor(1, 1, 1, 1)
    if rope.deployed then
        love.graphics.draw(self.assets.ropeTop, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
        for _, segmentY in ipairs(rope.segments) do
            love.graphics.draw(self.assets.rope, math.floor(rope.x - 8), math.floor(segmentY), 0, 1, 1, 4, 4)
        end
    else
        love.graphics.draw(self.assets.ropeEnd, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
    end
end

function Rope.loadAssets(assets)
    assets.ropeEnd = Assets.image("Items/Weapons", "sRopeEnd")
    assets.rope = Assets.image("Items/Weapons", "sRope")
    assets.ropeTop = Assets.image("Items/Weapons", "sRopeTop")
end

return Rope
