local Traits = require("src.platform.item_traits")
local Holdable = require("src.platform.holdable")
local Assets = require("src.platform.object_assets")
local Timing = require("src.platform.tool_timing")

local Bomb = {}
Bomb.__index = Bomb
Bomb.definition = Traits.body({ hold = { standing = 2, ducking = 4 }, webAfterImpact = true })

function Bomb.definition.enemyContact(bomb, enemy)
    if not bomb.sticky then return false end
    bomb.attached = enemy
    bomb.attachX = enemy.x - bomb.x
    bomb.attachY = enemy.y - bomb.y
    bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
    return true
end

function Bomb:getCollisionHalfWidth() return 4 end
function Bomb:getVerticalBounds() return -4, 4 end

function Bomb:overlapsRectangle(left, top, right, bottom)
    return left <= self.x + 4 and right >= self.x - 4
        and top <= self.y + 4 and bottom >= self.y - 4
end

function Bomb:pickup(player)
    self.attached, self.stuck = nil, false
    return self.alive and Holdable.pickup(self, player) or false
end

function Bomb:updateHeldPosition(player)
    Holdable.position(self, player)
end

function Bomb:throw(player, input, world)
    Holdable.throw(self, player, input, world)
end

function Bomb.arm(bomb)
    bomb.armed, bomb.animation = true, 0
end

function Bomb.definition.useHeld(game, bomb, input)
    if not bomb.armed then Bomb.arm(bomb)
    else
        bomb:throw(game.player, input, game.world)
        require("src.platform.item_cycle").restore(game)
        if game.throwSound then game.throwSound:clone():play() end
    end
    return true
end

function Bomb:dropFromHurt(player)
    Bomb.arm(self)
    Holdable.dropFromHurt(self, player)
end

function Bomb.throwFromPlayer(self, player, input)
    if player.whipping or player:isDead() or player:isStunned() then return nil end
    input = input or {}
    local bomb = self:spawnBomb(player.x, player.y, {
        vx = player.facing * 8 + player.vx,
        vy = input.up and -9 or input.down and 3 or -3,
        sticky = player.equipment and player.equipment.paste or false,
    })
    if input.down and self.world:groundBelow(player) then bomb.vx = bomb.vx * 0.1 end
    return bomb
end

function Bomb.spawn(self, x, y, options)
    options = options or {}
    local bomb = setmetatable({
        kind = "bomb",
        definition = Bomb.definition,
        heavy = false,
        held = false,
        safeTimer = 0,
        radius = 4,
        gravity = 0.6,
        animation = 0,
        x = x,
        y = y,
        vx = options.vx or 0,
        vy = options.vy or 0,
        xRemainder = 0,
        yRemainder = 0,
        timer = options.timer or Timing.scaledTicks(80 + 40, self.tickRate),
        flashStart = Timing.scaledTicks(40, self.tickRate),
        alive = true,
        armed = options.armed ~= false,
        sticky = options.sticky or false,
        stuck = false,
    }, Bomb)
    self.bombs[#self.bombs + 1] = bomb
    return bomb
end

function Bomb.update(self, bomb, enemies, player)
    if bomb.armed then
        bomb.timer = bomb.timer - 1
        bomb.animation = bomb.animation + (bomb.timer <= bomb.flashStart and 1 or 0.2)
    end
    if bomb.armed and bomb.timer <= 0 then
        bomb.alive = false
        bomb.held = false
        self:explode(bomb.x, bomb.y)
        return
    end

    if bomb.held then
        if player then bomb:updateHeldPosition(player) end
        return
    end

    if bomb.attached then
        if bomb.attached.alive or bomb.attached.corpse then
            bomb.x = bomb.attached.x - bomb.attachX
            bomb.y = bomb.attached.y - bomb.attachY
            return
        end
        bomb.attached, bomb.stuck = nil, false
    end
    bomb.definition.bodyStep(self.world, bomb, player, self, enemies)
end

function Bomb.draw(self, bomb)
    if not self.assets or not bomb.alive then return end
    love.graphics.setColor(1, 1, 1, 1)
    local frame = math.floor(bomb.animation) % 2 + 1
    local image = bomb.armed and self.assets.bombArmed[frame] or self.assets.bomb
    love.graphics.draw(image, math.floor(bomb.x), math.floor(bomb.y), 0, 1, 1, 4, 4)
end

function Bomb.depth(state)
    if state == "sticky" then return 1 end
    if state == "armed" then return 49 end
    return 99
end

function Bomb.loadAssets(assets)
    assets.bomb = Assets.image("Items/Weapons", "sBomb")
    assets.bombArmed = { Assets.image("Items/Weapons", "sBombArmed", 0),
        Assets.image("Items/Weapons", "sBombArmed", 1) }
end

return Bomb
