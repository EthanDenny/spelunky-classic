local TrapSystem = {}
TrapSystem.__index = TrapSystem
local Depth = require("src.render.classic_depth")
local Types = require("src.platform.traps.types")
local ArrowTrap = require("src.platform.traps.arrow_trap_behavior")
local Head = require("src.platform.traps.giant_tiki_head")
local Boulder = require("src.platform.traps.boulder")
local Arrow = require("src.platform.items.arrow")

function TrapSystem.new(world, level, renderer)
    local self = setmetatable({
        world = world,
        renderer = renderer,
        traps = {},
        projectiles = {},
        boulders = {},
        assets = nil,
        arrowSound = nil,
        thumpSound = nil,
        crunchSound = nil,
    }, TrapSystem)
    for _, entity in ipairs(level.entities or {}) do
        if Types[entity.kind] then
            local trap = {
                entity = entity,
                kind = entity.kind,
                definition = Types[entity.kind],
                x = entity.x * 16,
                y = entity.y * 16,
                alive = true,
                fired = false,
                cooldown = 0,
                state = "idle",
            }
            if trap.definition.direction then ArrowTrap.initializeBeam(world, trap, trap.definition.direction) end
            self.traps[#self.traps + 1] = trap
        end
    end
    return self
end

function TrapSystem:loadAssets()
    if self.assets then return end
    self.assets = {}
    Arrow.loadTrapAssets(self.assets)
    Boulder.loadAssets(self.assets)
    Head.loadAssets(self.assets)
    self.arrowSound = love.audio.newSource("original-game-reference/sound/arrowtrap.wav", "static")
    self.thumpSound = love.audio.newSource("original-game-reference/sound/thump.wav", "static")
    self.crunchSound = love.audio.newSource("original-game-reference/sound/crunch.wav", "static")
end

TrapSystem.fireArrow = ArrowTrap.fire
TrapSystem.updateArrowTrap = ArrowTrap.update
TrapSystem.spawnBoulder = Boulder.spawn
TrapSystem.moveBoulder = Boulder.move
TrapSystem.updateBoulder = Boulder.update
TrapSystem.updateProjectile = Arrow.updateTrapProjectile

TrapSystem.triggerIdol = Head.triggerIdol

function TrapSystem:update(player, enemies, items, movingTargets)
    -- Collision-created arrows do not receive a Step in their creation tick.
    for _, projectile in ipairs(self.projectiles) do
        self:updateProjectile(projectile, player, enemies, items)
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then self:updateBoulder(boulder, player, enemies) end
    end
    for _, trap in ipairs(self.traps) do
        if trap.alive and trap.entity.destroyed then
            self:destroyTrap(trap)
        elseif trap.alive then
            trap.definition.update(self, trap, player, enemies, items, movingTargets)
        end
    end
end

function TrapSystem:destroyTrap(trap)
    if not trap.alive then return end
    trap.alive = false
    if trap.definition.direction and not trap.fired and self.game then
        self.game:spawnEntity("arrow", trap.x+8, trap.y+8)
    end
end

function TrapSystem:explode(x, y, radius)
    for _, trap in ipairs(self.traps) do
        local dx, dy = trap.x + 8 - x, trap.y + 8 - y
        if trap.alive and trap.definition.direction and dx * dx + dy * dy <= (radius + 8) ^ 2 then
            self:destroyTrap(trap)
            self.world:remove("solid", math.floor(trap.entity.x), math.floor(trap.entity.y))
        end
    end
    for _, boulder in ipairs(self.boulders) do
        local dx, dy = boulder.x - x, boulder.y - y
        if boulder.alive and dx * dx + dy * dy <= (radius + 16) ^ 2 then
            boulder.alive = false
            if self.game then
                local effects = self.game.effects
                for index = 1, 9 do
                    effects:add(index <= 3 and "rubbleLarge" or "rubble", boulder.x+effects.random:random(-15,15),
                        boulder.y+effects.random:random(-15,15)).variant = "tan"
                    if index <= 3 and effects.random:random(1,3) == 1 then
                        self.game:spawnEntity("rock", boulder.x, boulder.y)
                    end
                end
            end
            if boulder.solid then self.world:removeDynamicSolid(boulder.solid) end
        end
    end
end

function TrapSystem:submit(queue)
    for _, trap in ipairs(self.traps) do
        if trap.alive and not trap.entity.destroyed then
            local current = trap
            queue:add(Depth.entity(current.kind), function()
                if not current.definition.draw or not current.definition.draw(self, current) then
                    self.renderer:drawEntity({
                        kind = current.kind, x = current.x / 16, y = current.y / 16,
                        properties = current.entity.properties or {},
                    }, self.world.time)
                end
            end)
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local current = projectile
            queue:add(Depth.entity("arrow"), function()
                Arrow.drawTrapProjectile(self, current)
            end)
        end
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then
            local current = boulder
            queue:add(Depth.entity("boulder"), function()
                Boulder.draw(self, current)
            end)
        end
    end
end

function TrapSystem.isTrap(kind)
    return Types[kind] ~= nil
end

return TrapSystem
