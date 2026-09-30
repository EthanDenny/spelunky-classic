local TrapSystem = {}
TrapSystem.__index = TrapSystem

local TRAP_KINDS = {
    arrow_trap_left = true,
    arrow_trap_right = true,
    giant_tiki_head = true,
}

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function imagePath(group, sprite)
    return "original-game-reference/source/extracted/spelunky/Sprites/" .. group .. "/"
        .. sprite .. ".images/image 0.png"
end

local function clearLine(world, x1, x2, y)
    local direction = x2 < x1 and -4 or 4
    local x = x1
    while (direction < 0 and x > x2) or (direction > 0 and x < x2) do
        if world:solidAtPoint(x, y) then return false end
        x = x + direction
    end
    return true
end

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
    }, TrapSystem)
    for _, entity in ipairs(level.entities or {}) do
        if TRAP_KINDS[entity.kind] then
            local trap = {
                entity = entity,
                kind = entity.kind,
                x = entity.x * 16,
                y = entity.y * 16,
                alive = true,
                fired = false,
                cooldown = 0,
                state = "idle",
            }
            self.traps[#self.traps + 1] = trap
        end
    end
    return self
end

function TrapSystem:loadAssets()
    if self.assets then return end
    self.assets = {
        arrowLeft = loadImage(imagePath("Items/Weapons", "sArrowLeft")),
        arrowRight = loadImage(imagePath("Items/Weapons", "sArrowRight")),
        boulder = loadImage(imagePath("Traps", "sBoulder")),
    }
    self.arrowSound = love.audio.newSource("original-game-reference/sound/arrowtrap.wav", "static")
    self.thumpSound = love.audio.newSource("original-game-reference/sound/thump.wav", "static")
end

function TrapSystem:fireArrow(trap, direction)
    self.projectiles[#self.projectiles + 1] = {
        kind = "arrow", x = trap.x + (direction > 0 and 16 or 0), y = trap.y + 8,
        vx = direction * 8, vy = 0, direction = direction, alive = true,
    }
    trap.fired = true
    if self.arrowSound then self.arrowSound:clone():play() end
end

function TrapSystem:updateArrowTrap(trap, player, items)
    if trap.fired then return end
    local direction = trap.kind == "arrow_trap_left" and -1 or 1
    local originX, originY = trap.x + 8, trap.y + 8
    local function inBeam(x, y, moving)
        local delta = (x - originX) * direction
        return delta > 0 and delta <= 96 and math.abs(y - originY) < 8 and moving
            and clearLine(self.world, originX + direction * 10, x, originY)
    end
    if inBeam(player.x, player.y, math.abs(player.vx) > 0.05 or math.abs(player.vy) > 0.05) then
        self:fireArrow(trap, direction)
        return
    end
    for _, item in ipairs(items or {}) do
        if not item.held and inBeam(item.x, item.y, math.abs(item.vx) > 0.05 or math.abs(item.vy) > 0.05) then
            self:fireArrow(trap, direction)
            return
        end
    end
end


function TrapSystem:triggerIdol(player)
    local nearest, nearestDistance
    for _, trap in ipairs(self.traps) do
        if trap.alive and trap.kind == "giant_tiki_head" then
            local dx, dy = trap.x - player.x, trap.y - 64 - player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = trap, distance
            end
        end
    end
    if nearest then nearest.state, nearest.cooldown = "armed", 100 end
end

function TrapSystem:spawnBoulder(trap)
    self.boulders[#self.boulders + 1] = {
        x = trap.x, y = trap.y, vx = 0, vy = 0, alive = true, bounced = false,
    }
end

function TrapSystem:updateBoulder(boulder, player, enemies)
    boulder.vy = math.min(8, boulder.vy + 0.6)
    local xSteps = math.floor(math.abs(boulder.vx))
    local xDirection = boulder.vx < 0 and -1 or 1
    for _ = 1, xSteps do
        if self.world:solidRect(boulder.x + xDirection - 14, boulder.y - 16,
            boulder.x + xDirection + 14, boulder.y + 16) then
            boulder.vx = -boulder.vx * 0.8
            break
        end
        boulder.x = boulder.x + xDirection
    end
    local landed = false
    local yDirection = boulder.vy < 0 and -1 or 1
    for _ = 1, math.floor(math.abs(boulder.vy)) do
        if self.world:solidRect(boulder.x - 14, boulder.y + yDirection - 16,
            boulder.x + 14, boulder.y + yDirection + 16) then
            if yDirection > 0 then
                boulder.vy = boulder.vy > 3 and -boulder.vy * 0.3 or 0
                landed = true
            else
                boulder.vy = -boulder.vy * 0.8
            end
            break
        end
        boulder.y = boulder.y + yDirection
    end
    if landed then
        boulder.vx = boulder.vx * 0.99
        if not boulder.bounced and math.abs(boulder.vx) < 0.5 then
            boulder.vx = player.x < boulder.x and -4.5 or 4.5
            boulder.bounced = true
        end
    end
    if math.abs(player.x - boulder.x) < 18 and math.abs(player.y - boulder.y) < 20 then
        player.health = 0
    end
    for _, enemy in ipairs(enemies or {}) do
        if enemy.alive and math.abs(enemy.x - boulder.x) < 20
            and math.abs(enemy.y - boulder.y) < 20 then enemy:damage(99) end
    end
    if boulder.y > self.world.height * self.world.tileSize + 48 then boulder.alive = false end
end


function TrapSystem:updateProjectile(projectile, player, enemies)
    if not projectile.alive then return end
    projectile.vy = math.min(8, projectile.vy + 0.2)
    local steps = math.max(1, math.floor(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
    local dx, dy = projectile.vx / steps, projectile.vy / steps
    for _ = 1, steps do
        local nextX, nextY = projectile.x + dx, projectile.y + dy
        if self.world:solidAtPoint(nextX, nextY) then
            projectile.alive, projectile.vx, projectile.vy = false, 0, 0
            return
        end
        projectile.x, projectile.y = nextX, nextY
        if math.abs(projectile.x - player.x) < 7 and math.abs(projectile.y - player.y) < 8 then
            player:hurt(projectile.x)
            projectile.alive = false
            return
        end
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and math.abs(projectile.x - enemy.x) < 8
                and math.abs(projectile.y - enemy.y) < 8 then
                enemy:damage(2)
                projectile.alive = false
                return
            end
        end
    end
end

function TrapSystem:update(player, enemies, items)
    for _, trap in ipairs(self.traps) do
        if trap.alive then
            if trap.kind == "arrow_trap_left" or trap.kind == "arrow_trap_right" then
                self:updateArrowTrap(trap, player, items)
            elseif trap.kind == "giant_tiki_head" and trap.state == "armed" then
                trap.cooldown = trap.cooldown - 1
                if trap.cooldown <= 0 then
                    trap.state = "fired"
                    self:spawnBoulder(trap)
                    if self.thumpSound then self.thumpSound:clone():play() end
                end
            end
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        self:updateProjectile(projectile, player, enemies)
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then self:updateBoulder(boulder, player, enemies) end
    end
end

function TrapSystem:explode(x, y, radius)
    for _, trap in ipairs(self.traps) do
        local dx, dy = trap.x + 8 - x, trap.y + 8 - y
        if trap.alive and dx * dx + dy * dy <= (radius + 8) ^ 2 then
            trap.alive = false
            self.world:remove("solid", math.floor(trap.entity.x), math.floor(trap.entity.y))
        end
    end
    for _, boulder in ipairs(self.boulders) do
        local dx, dy = boulder.x - x, boulder.y - y
        if boulder.alive and dx * dx + dy * dy <= (radius + 16) ^ 2 then boulder.alive = false end
    end
end

function TrapSystem:draw()
    for _, trap in ipairs(self.traps) do
        if trap.alive then
            self.renderer:drawEntity({
                kind = trap.kind, x = trap.x / 16, y = trap.y / 16,
                properties = trap.entity.properties or {},
            })
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local image = projectile.direction < 0 and self.assets.arrowLeft or self.assets.arrowRight
            love.graphics.draw(image, math.floor(projectile.x), math.floor(projectile.y), 0, 1, 1, 4, 4)
        end
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then
            love.graphics.draw(self.assets.boulder, math.floor(boulder.x), math.floor(boulder.y),
                0, 1, 1, 16, 16)
        end
    end
end

function TrapSystem.isTrap(kind)
    return TRAP_KINDS[kind] or false
end

return TrapSystem
