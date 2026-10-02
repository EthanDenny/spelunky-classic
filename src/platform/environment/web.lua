local Web = { depth = 200, worldLayer = "web" }

function Web.place(self, x, y)
    -- oWebBall's animation end creates oWeb at (x-8, y-8).
    local web = { x = x - 8, y = y - 8, life = 12, dying = true }
    self.world.dynamicWebs[#self.world.dynamicWebs + 1] = web
    self.webs[#self.webs + 1] = web
end

function Web.update(self)
    for index = #self.webs, 1, -1 do
        local web = self.webs[index]
        if web.dying then web.life = web.life - 0.02 end
        if web.destroyed or web.life <= 1 then
            for worldIndex = #self.world.dynamicWebs, 1, -1 do
                if self.world.dynamicWebs[worldIndex] == web then
                    table.remove(self.world.dynamicWebs, worldIndex)
                    break
                end
            end
            table.remove(self.webs, index)
        end
    end
end

function Web.draw(system, web)
    love.graphics.setColor(1, 1, 1, web.life / 12)
    local sprites = require("src.platform.projectiles.web_ball").loadImages()
    love.graphics.draw(sprites.web, math.floor(web.x), math.floor(web.y))
    love.graphics.setColor(1, 1, 1, 1)
end

function Web.alpha(entity)
    return (entity.life or 12) / 12
end

return Web
