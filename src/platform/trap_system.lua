local TrapSystem = {}
TrapSystem.__index = TrapSystem

local TRAP_KINDS = {
    arrow_trap_left = true,
    arrow_trap_right = true,
    spear_trap_bottom = true,
    spear_trap_top = true,
    spring_trap = true,
    smash_trap = true,
    thwomp_trap = true,
    ceiling_trap = true,
    trap_block = true,
    giant_tiki_head = true,
    door = true,
}

local MOVING_SOLIDS = {
    smash_trap = true,
    thwomp_trap = true,
    ceiling_trap = true,
    door = true,
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

local function overlapsPlayer(trap, player, padding)
    padding = padding or 0
    local half = player:getCollisionHalfWidth()
    local top, bottom = player:getVerticalBounds()
    return player.x + half > trap.x - padding and player.x - half < trap.x + 16 + padding
        and player.y + bottom > trap.y - padding and player.y + top < trap.y + 16 + padding
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
        spears = {},
        boulders = {},
        assets = nil,
        arrowSound = nil,
        boingSound = nil,
        thumpSound = nil,
    }, TrapSystem)
    for _, entity in ipairs(level.entities or {}) do
        if TRAP_KINDS[entity.kind] then
            local trap = {
                entity = entity,
                kind = entity.kind,
                x = entity.x * 16,
                y = entity.y * 16,
                homeX = entity.x * 16,
                homeY = entity.y * 16,
                alive = true,
                fired = false,
                cooldown = 0,
                state = "idle",
                vx = 0,
                vy = 0,
            }
            self.traps[#self.traps + 1] = trap
            if MOVING_SOLIDS[trap.kind] then
                world:remove("solid", math.floor(entity.x), math.floor(entity.y))
                trap.block = world:addDynamicSolid({
                    x = trap.x, y = trap.y, width = 16, height = 16,
                trap = trap, moveable = false, vx = 0, vy = 0,
                height = trap.kind == "door" and 32 or 16,
                })
            end
        end
    end
    return self
end

function TrapSystem:loadAssets()
    if self.assets then return end
    self.assets = {
        arrowLeft = loadImage(imagePath("Items/Weapons", "sArrowLeft")),
        arrowRight = loadImage(imagePath("Items/Weapons", "sArrowRight")),
        spearsLeft = loadImage(imagePath("Traps", "sSpearsLeft")),
        spearsRight = loadImage(imagePath("Traps", "sSpearsRight")),
        spring = loadImage(imagePath("Traps", "sSpringTrapSprung")),
        boulder = loadImage(imagePath("Traps", "sBoulder")),
    }
    self.arrowSound = love.audio.newSource("original-game-reference/sound/arrowtrap.wav", "static")
    self.boingSound = love.audio.newSource("original-game-reference/sound/boing.wav", "static")
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

function TrapSystem:updateSpearTrap(trap, player)
    if trap.cooldown > 0 then trap.cooldown = trap.cooldown - 1 end
    local centerX, centerY = trap.x + 8, trap.y + 8
    if trap.cooldown == 0 and math.abs(player.y - centerY) < 4
        and math.abs(player.x - centerX) < 64 then
        local direction = player.x < centerX and -1 or 1
        self.spears[#self.spears + 1] = {
            x = direction < 0 and trap.x - 16 or trap.x + 16,
            y = trap.y, direction = direction, timer = 10, alive = true,
        }
        trap.cooldown = 50
    end
end

function TrapSystem:updateSpring(trap, player, items)
    if trap.cooldown > 0 then trap.cooldown = trap.cooldown - 1 end
    if trap.cooldown == 0 and player.vy >= 0 and math.abs(player.x - (trap.x + 8)) < 6
        and player.y + 8 >= trap.y and player.y + 8 <= trap.y + 8 then
        player.y = player.y - 16
        player.vy = -16
        player:setState("jumping")
        trap.cooldown = 10
        if self.boingSound then self.boingSound:clone():play() end
    end
    for _, item in ipairs(items or {}) do
        if trap.cooldown == 0 and not item.held and math.abs(item.x - (trap.x + 8)) < 6
            and item.y >= trap.y - 8 and item.y <= trap.y + 8 then
            item.y = item.y - 24
            item.vy = -8
            trap.cooldown = 10
            if self.boingSound then self.boingSound:clone():play() end
        end
    end
end

local function moveTrapPixel(system, trap, dx, dy)
    local block = trap.block
    if system.world:solidRect(block.x + dx, block.y + dy,
        block.x + dx + 16, block.y + dy + 16, block) then return false end
    block.x, block.y = block.x + dx, block.y + dy
    trap.x, trap.y = block.x, block.y
    return true
end

function TrapSystem:updateThwomp(trap, player)
    if trap.state == "idle" and player.y > trap.y
        and math.abs(player.x - (trap.x + 8)) < 8
        and math.abs(player.y - trap.y) < 96 then
        trap.state = "drop"
    elseif trap.state == "drop" then
        trap.vy = math.min(6, trap.vy + 1)
        for _ = 1, math.floor(trap.vy) do
            if not moveTrapPixel(self, trap, 0, 1) then
                trap.state, trap.cooldown, trap.vy = "wait", 100, 0
                if self.thumpSound then self.thumpSound:clone():play() end
                break
            end
        end
    elseif trap.state == "wait" then
        trap.cooldown = trap.cooldown - 1
        if trap.cooldown <= 0 then trap.state = "return" end
    elseif trap.state == "return" then
        if trap.y <= trap.homeY or not moveTrapPixel(self, trap, 0, -1) then
            trap.y, trap.block.y, trap.state = trap.homeY, trap.homeY, "idle"
        end
    end
    if (trap.state == "drop" or trap.state == "wait") and overlapsPlayer(trap, player, -1) then
        player.health = 0
    end
end

function TrapSystem:updateCeiling(trap, player)
    if trap.state == "idle" and player.y > trap.y
        and math.abs(player.x - (trap.x + 8)) < 12
        and player.y - trap.y < 96 then
        trap.state, trap.cooldown = "drop", 3
    elseif trap.state == "drop" then
        trap.cooldown = trap.cooldown - 1
        if trap.cooldown <= 0 then
            trap.cooldown = 3
            if not moveTrapPixel(self, trap, 0, 1) then trap.state = "landed" end
        end
    end
    if trap.state == "drop" and overlapsPlayer(trap, player, -1) then player.health = 0 end
end

function TrapSystem:triggerIdol(player, area)
    if area == "mines" then
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
    elseif area == "jungle" then
        for _, trap in ipairs(self.traps) do
            local dx, dy = trap.x - player.x, trap.y - player.y
            if trap.kind == "trap_block" and dx * dx + dy * dy < 90 * 90 then
                trap.state, trap.cooldown = "dying", 1
            end
        end
    elseif area == "temple" then
        for _, trap in ipairs(self.traps) do
            local dx, dy = trap.x - player.x, trap.y - player.y
            if trap.kind == "ceiling_trap" or trap.kind == "door" then
                trap.state, trap.cooldown = "drop", 3
            elseif trap.kind == "trap_block" and dx * dx + dy * dy < 90 * 90 then
                trap.state, trap.cooldown = "dying", 1
            end
        end
    end
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

function TrapSystem:updateSmash(trap, player)
    if trap.cooldown > 0 then trap.cooldown = trap.cooldown - 1 end
    if trap.state == "idle" and trap.cooldown == 0 then
        local dx, dy = player.x - (trap.x + 8), player.y - (trap.y + 8)
        if dx * dx + dy * dy < 90 * 90 then
            if math.abs(dy) < 8 then trap.vx, trap.vy = dx < 0 and -0.5 or 0.5, 0
            elseif math.abs(dx) < 8 then trap.vx, trap.vy = 0, dy < 0 and -0.5 or 0.5 end
            if trap.vx ~= 0 or trap.vy ~= 0 then trap.state = "attack" end
        end
    elseif trap.state == "attack" then
        trap.vx = math.max(-4, math.min(4, trap.vx * 1.5))
        trap.vy = math.max(-4, math.min(4, trap.vy * 1.5))
        local moved = true
        for _ = 1, math.max(math.abs(math.floor(trap.vx)), math.abs(math.floor(trap.vy))) do
            if not moveTrapPixel(self, trap, trap.vx == 0 and 0 or (trap.vx < 0 and -1 or 1),
                trap.vy == 0 and 0 or (trap.vy < 0 and -1 or 1)) then moved = false break end
        end
        if not moved then trap.state, trap.cooldown, trap.vx, trap.vy = "idle", 50, 0, 0 end
    end
    if trap.state == "attack" and overlapsPlayer(trap, player, -1) then player.health = 0 end
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
            elseif trap.kind == "spear_trap_top" or trap.kind == "spear_trap_bottom" then
                self:updateSpearTrap(trap, player)
            elseif trap.kind == "spring_trap" then self:updateSpring(trap, player, items)
            elseif trap.kind == "thwomp_trap" then self:updateThwomp(trap, player)
            elseif trap.kind == "ceiling_trap" then self:updateCeiling(trap, player)
            elseif trap.kind == "door" and trap.state ~= "idle" then self:updateCeiling(trap, player)
            elseif trap.kind == "smash_trap" then self:updateSmash(trap, player)
            elseif trap.kind == "giant_tiki_head" and trap.state == "armed" then
                trap.cooldown = trap.cooldown - 1
                if trap.cooldown <= 0 then
                    trap.state = "fired"
                    self:spawnBoulder(trap)
                    if self.thumpSound then self.thumpSound:clone():play() end
                end
            elseif trap.kind == "trap_block" and trap.state == "dying" then
                trap.cooldown = trap.cooldown - 1
                if trap.cooldown <= 0 then
                    trap.alive = false
                    self.world:remove("solid", math.floor(trap.entity.x), math.floor(trap.entity.y))
                end
            end
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        self:updateProjectile(projectile, player, enemies)
    end
    for _, spear in ipairs(self.spears) do
        if spear.alive then
            spear.timer = spear.timer - 1
            if spear.timer <= 0 then spear.alive = false
            elseif player.invincibleTimer == 0 and player.x > spear.x and player.x < spear.x + 16
                and math.abs(player.y - (spear.y + 8)) < 7 then
                player:hurt(spear.x + 8)
            end
        end
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
            if trap.block then trap.block.alive = false end
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
            if trap.kind == "spring_trap" and trap.cooldown > 0 then
                love.graphics.draw(self.assets.spring, math.floor(trap.x), math.floor(trap.y))
            else
                self.renderer:drawEntity({
                    kind = trap.kind, x = trap.x / 16, y = trap.y / 16,
                    properties = trap.entity.properties or {},
                })
            end
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local image = projectile.direction < 0 and self.assets.arrowLeft or self.assets.arrowRight
            love.graphics.draw(image, math.floor(projectile.x), math.floor(projectile.y), 0, 1, 1, 4, 4)
        end
    end
    for _, spear in ipairs(self.spears) do
        if spear.alive then
            love.graphics.draw(spear.direction < 0 and self.assets.spearsLeft or self.assets.spearsRight,
                math.floor(spear.x), math.floor(spear.y))
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

function TrapSystem.isMovingTrap(kind)
    return MOVING_SOLIDS[kind] or false
end

return TrapSystem
