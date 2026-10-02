local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ flight = "die", hitSpeed = 3, heavy = true, bounds = { 6, 0, 8 },
    hold = { standing = -2, ducking = 0 } })

Definition.depth = 100

function Definition.initialize(self)
    self.diceValue = love.math.random(1, 6)
    self.diceRolling = false
    self.diceAge = 0
end

function Definition.updateLoose(self, world, player)
    local PhysicalBody = require("src.platform.physical_body")
    self.diceAge = self.diceAge + 1
    self.diceRolling = math.abs(self.vx) > 2 or math.abs(self.vy) > 2
    if self.diceRolling then
        self.diceValue = love.math.random(1, 6)
        if player and (player.bet or 0) > 0 then self.betRolling = true end
    elseif PhysicalBody.probe(world, self, "y", 1) and self.vy == 0 and self.betRolling then
        if self.rolled then self.diceCheated = true end
        self.rolled, self.betRolling = true, false
    end
end

function Definition.loadRenderAssets(self)
    local spriteRoot = "original-game-reference/source/extracted/spelunky/Sprites/"
    self.itemAnimationSprites.diceRoll, self.itemAnimationSprites.diceFaces = {}, {}
    for frame = 0, 5 do
        local image = love.graphics.newImage(string.format(
            "%sItems/Other/sDiceRoll.images/image %d.png", spriteRoot, frame))
        image:setFilter("nearest", "nearest")
        self.itemAnimationSprites.diceRoll[frame + 1] = image
        local face = love.graphics.newImage(string.format(
            "%sItems/Other/sDice%d.images/image 0.png", spriteRoot, frame + 1))
        face:setFilter("nearest", "nearest")
        self.itemAnimationSprites.diceFaces[frame + 1] = face
    end
end

function Definition.itemImage(renderer, item)
    local sprites = renderer.itemAnimationSprites
    return item.diceRolling and sprites.diceRoll[item.diceAge % 6 + 1]
        or sprites.diceFaces[item.diceValue or 1]
end

return Definition
