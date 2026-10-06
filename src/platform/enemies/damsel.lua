local PhysicalBody = require("src.platform.physical_body")
local Traits = require("src.platform.item_traits")

local Damsel = {
    creatureConfig = { hp = 4, speed = 1.2, npc = true },
    creatureHalfWidth = 4,
    creatureVerticalBounds = { -12, 0 },
    canContact = false,
    canBeHeld = true,
    holdWhenHealthy = true,
    stunDuration = 120,
    recoveryState = "run",
    creatureAnimationPerTick = 0.5,
    -- oDamsel tests status==98 for its live bonus, but THROWN is 2. The
    -- executable Classic code therefore awards eight for both states.
    sacrifice = { favor = 8, deadFavor = 8, rewardOffset = 16 },
}

function Damsel.initializeCreature(self)
    self.heavy = true
    self.timer = 200
    self.gravity = 0.6
    self.physicsOriginY = -8
    self.definition = Traits.body({ hold = { standing = 8, ducking = 10 } })
end

function Damsel.creatureStep(self, world, player, game)
    self.definition.bodyStep(world, self, player, game)
    if self.vy > 2 then Damsel.onThrown(self) return end
    if self.forSale then
        if self.state == "kiss" then
            if self.animation % 10 == 7 and game then
                game.effects:add("heart", self.x+self.facing*8, self.y-16)
                game.sounds:play("kiss")
            end
            if self.animation >= 10 then self.state = "slave" end
        else
            self.facing = player.x < self.x and -1 or 1
            self.animation = self.animation % 1
        end
        return
    end
    if self.state == "run" then
        self.animation = self.animation+0.3
        if world:collidesSolid(self, self.x+self.facing*2, self.y) then self.facing = -self.facing end
        self.vx = self.facing*1.5
    elseif self.state == "yell" then
        if self.animation >= 10 then self.state, self.timer = "idle", 200 end
    else
        self.vx = 0
        self.timer = self.timer-1
        if self.timer <= 0 then
            self.state, self.animation = "yell", 0
            if game then game.sounds:play("damsel") end
        end
    end
end

function Damsel.melee(body, game, damage)
    if body.cooldown > 0 or body.rescued then return false end
    if damage > 0 then
        body.hp = body.hp-damage
        game.effects:blood(body.x, body.y-8, 1)
        if body.hp <= 0 then body.alive, body.corpse, body.state = false, true, "dead" end
    elseif body.stunned <= 0 then
        body.vy = -2
        if body.forSale then require("src.platform.shop").anger(game, body.x, body.y, "YOU'LL PAY FOR YOUR CRIMES!") end
    else return false end
    body.cooldown = 10
    game.sounds:play("damsel")
    return true
end

function Damsel.canDamage(body)
    return body.state ~= "exiting"
end

function Damsel.animationEnd(body)
    if body.state == "kiss" and body.animation >= 10 then body.state = "slave"
    elseif body.state == "yell" and body.animation >= 10 then body.state, body.timer = "idle", 200 end
end

function Damsel.rescue(body, game)
    if body.rescued or not body.alive then return false end
    body.rescued, body.held, body.state = true, false, "exiting"
    body.x, body.y = game.level.exit.x*16+8, game.level.exit.y*16+16
    body.vx, body.vy, body.animation, body.invincible = 0, 0, 0, 1
    game.run.damsels = game.run.damsels+1
    game.rescues = (game.rescues or 0)+1
    if game.heldNpc == body then game.heldNpc = nil end
    game.sounds:play("steps")
    return true
end

function Damsel.checkExit(body, game)
    local exit = game.level.exit
    if not exit or body.held or body.stunned > 0 or body.rescued or not body.alive then return end
    local x, y = body.x, body.y-8
    if x >= exit.x*16 and x < exit.x*16+16 and y >= exit.y*16 and y < exit.y*16+16 then
        Damsel.rescue(body, game)
    end
end

function Damsel.updateExit(body)
    if body.state ~= "exiting" then return false end
    body.animation = body.animation+0.5
    if body.animation >= 17 then body.alive = false end
    return true
end

function Damsel.stunnedStep(self, world, player, game)
    local web = self.definition.bodyStep(world, self, player, game)
    if web or PhysicalBody.probe(world, self, "y", 1, 2) then
        self.stunned = self.stunned - 1
    end
end

function Damsel.onThrown(self)
    self.state = "stunned"
    self.stunned = 120
end

local Assets = require("src.platform.object_assets")
local sprites = {}
function Damsel.collisionSprite(body)
    local name = "sDamselLeft"
    if body.state == "exiting" then name = "sDamselExit2"
    elseif body.state == "kiss" then name = "sDamselKissL"
    elseif body.state == "yell" then name = "sDamselYellL"
    elseif body.state == "run" then name = "sDamselRunL"
    elseif body.corpse then name = "sDamselDieL"
    elseif body.stunned > 0 then name = "sDamselStunL" end
    return name, body.animation, body.x, body.y-8, body.facing > 0 and body.state ~= "exiting"
end

function Damsel.drawCreature(body, renderer)
    if body.state == "exiting" or body.state == "yell" or body.state == "run" or body.state == "kiss" then
        local name = Damsel.collisionSprite(body)
        local count = body.state == "exiting" and 17
            or (body.state == "yell" or body.state == "kiss") and 10 or 4
        local frame = math.floor(body.animation) % count
        local key = name .. frame
        sprites[key] = sprites[key] or Assets.image("Character/Damsel", name, frame)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(sprites[key], math.floor(body.x), math.floor(body.y-8),
            0, (body.state == "exiting" or body.facing < 0) and 1 or -1, 1, 8, 8)
        return
    end
    if not body.corpse and body.stunned <= 0 then
        renderer:drawEntity({ kind = "damsel", x = body.x / 16,
            y = (body.y - 8) / 16, properties = body.entity.properties })
        return
    end
    local name = Damsel.collisionSprite(body)
    local frame = body.corpse and 0 or math.floor(body.animation) % 5
    local key = name .. frame
    sprites[key] = sprites[key] or Assets.image("Character/Damsel", name, frame)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprites[key], math.floor(body.x), math.floor(body.y - 8),
        0, body.facing < 0 and 1 or -1, 1, 8, 8)
end

function Damsel.depth(state) return state == "exiting" and 1000 or 100 end

Damsel.deathBlood = 0

return Damsel
