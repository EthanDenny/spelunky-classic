local Spikes = { depth = 120 }

function Spikes.check(self)
    if self.player:isDead() or self.player.vy <= 0
        or (self.player.fallTimer <= 4 and not self.player:isStunned()) then return end
    local x, y = self.player.x, self.player.y
    for _, spike in ipairs(self.spikeEntities) do
        local left = spike.x * 16
        local top = spike.y * 16
        if not spike.destroyed and x + 4 > left and x - 4 < left + 16
            and y + 8 > top and y - 4 < top + 16 then
            spike.bloody = true
            self.effects:blood(x, y, 3)
            self.player:kill("spikes", 0, 0)
            return
        end
    end
end

function Spikes.checkActor(game, body)
    if not body.alive or body.kind == "ghost" or body.held or body.vy <= 2 then return end
    for _, spike in ipairs(game.spikeEntities) do
        local x, y = spike.x*16, spike.y*16
        if not spike.destroyed and body.x >= x and body.x < x+16
            and body.y >= y and body.y < y+16 then
            body.hp, body.alive, body.vx, body.vy = 0, false, 0, 0.2
            body.corpse = body.spec and body.spec.sacrifice ~= nil
            body.impaled, body.countsAsKill, body.state = true, false, "dead"
            if not body.spec.bloodless then
                spike.bloody = true
                game.effects:blood(body.x, body.y, 3)
            end
            return
        end
    end
end

function Spikes.bloodImage()
    if not Spikes.image then
        Spikes.image = require("src.platform.object_assets").image("Traps", "sSpikesBlood")
    end
    return Spikes.image
end

function Spikes.drawBloody(entity)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Spikes.bloodImage(), entity.x * 16, entity.y * 16)
end

return Spikes
