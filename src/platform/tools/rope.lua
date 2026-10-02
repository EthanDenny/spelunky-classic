local PhysicalBody = require("src.platform.physical_body")
local Assets = require("src.platform.object_assets")

local Rope = { depth = 200 }

local function snap(value, grid)
    return math.floor(value / grid + 0.5) * grid
end

local function ropeSideClear(world, gridX, candidateX, y)
    local left = candidateX < gridX and candidateX or candidateX - 1
    return not world:solidRect(left, y, left + 2, y + 17)
end

function Rope.throwFromPlayer(self, player, input)
    if player.whipping or player:isDead() or player:isStunned() then return nil end
    local downward = input and input.down
    if not downward and self.world:collidesSolid(player, player.x, player.y - 1) then
        return nil
    end
    local rope = {
        kind = "rope",
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
    }
    if downward then
        local direction = player.facing < 0 and -1 or 1
        local gridX = snap(player.x + direction * 16, self.world.tileSize)
        local gridY = snap(player.y, 1)
        -- oPlayer1 first checks the side of the player, then tries the edge
        -- nearest the player and finally the far edge of the snapped cell.
        if self.world:solidAtPoint(player.x + direction * 8, player.y) then
            self.ropes[#self.ropes+1] = rope
            return rope
        end
        local nearX = gridX - direction * 8
        local farX = gridX + direction * 8
        if ropeSideClear(self.world, gridX, nearX, gridY) then
            rope.x = nearX
        elseif ropeSideClear(self.world, gridX, farX, gridY) then
            rope.x = farX
        else
            self.ropes[#self.ropes+1] = rope
            return rope
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

    PhysicalBody.stepItem(self.world, rope)
    -- The moving oRopeThrow inherits oItem's fast-item collision. Its fixed
    -- oRope body does not: only the flying end can damage an enemy.
    if math.abs(rope.vy) > 2 then
        rope.hitEnemies = rope.hitEnemies or {}
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and not rope.hitEnemies[enemy]
                and enemy:overlapsRectangle(rope.x - 2, rope.y - 2, rope.x + 2, rope.y + 2)
                and PhysicalBody.strikeEnemy(rope, enemy) then
                rope.hitEnemies[enemy] = true
                if self.onRopeHit then self:onRopeHit(enemy, rope) end
            end
        end
    end
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
