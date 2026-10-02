local ToolSystem = {}
ToolSystem.__index = ToolSystem
local Depth = require("src.render.classic_depth")
local Effects = require("src.platform.effects")
local Bomb = require("src.platform.tools.bomb")
local Rope = require("src.platform.tools.rope")
local Explosion = require("src.platform.tools.explosion")

function ToolSystem.new(world, tickRate)
    return setmetatable({
        world = world,
        tickRate = tickRate or 30,
        bombs = {},
        ropes = {},
        explosions = {},
        effects = Effects.new(1),
        assets = nil,
        explosionSound = nil,
    }, ToolSystem)
end

function ToolSystem:loadAssets()
    if self.assets then return end
    self.assets = {}
    Bomb.loadAssets(self.assets)
    Rope.loadAssets(self.assets)
    Explosion.loadAssets(self.assets)
    self.explosionSound = love.audio.newSource("original-game-reference/sound/explosion.wav", "static")
    Effects.loadAssets()
end

ToolSystem.throwBomb = Bomb.throwFromPlayer
ToolSystem.spawnBomb = Bomb.spawn
ToolSystem.updateBomb = Bomb.update
ToolSystem.drawBomb = Bomb.draw
ToolSystem.throwRope = Rope.throwFromPlayer
ToolSystem.deployRope = Rope.deploy
ToolSystem.anchorThrownRope = Rope.anchor
ToolSystem.updateRope = Rope.update
ToolSystem.drawRope = Rope.draw
ToolSystem.explode = Explosion.spawn
ToolSystem.drawExplosions = Explosion.draw

function ToolSystem:update(player, enemies, items)
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then self:updateBomb(bomb, enemies, player) end
    end
    for _, rope in ipairs(self.ropes) do
        if rope.alive then self:updateRope(rope, enemies) end
    end
    Explosion.update(self, player, enemies, items)
    self.effects:update(self.world)
end

function ToolSystem:submit(queue, player)
    for _, rope in ipairs(self.ropes) do
        if rope.alive then
            local current = rope
            queue:add(Depth.entity(current.deployed and "rope" or "rope_throw"),
                function() self:drawRope(current) end)
        end
    end
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then
            local current = bomb
            local state = current.sticky and "sticky" or current.armed and "armed" or nil
            local depth = current.held and (player and Depth.heldItem(player) or Depth.HELD_ITEM)
                or Depth.entity("bomb", state)
            queue:add(depth, function() self:drawBomb(current) end)
        end
    end
    queue:add(Depth.EFFECT, function() self:drawExplosions() end)
    self.effects:submit(queue)
end

return ToolSystem
