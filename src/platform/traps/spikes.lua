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
