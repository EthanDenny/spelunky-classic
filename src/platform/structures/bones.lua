local Definition = { depth = 900 }
function Definition.update(entity, world)
    local x, y = entity.x*16, entity.y*16
    entity.vy = entity.vy or 0
    if not world:solidAtPoint(x+8,y+16) then
        y = y+entity.vy
        entity.vy = entity.vy+0.2
    end
    if world:solidAtPoint(x+8,y+15) then y = y-1 end
    entity.y = y/16
end
return Definition
