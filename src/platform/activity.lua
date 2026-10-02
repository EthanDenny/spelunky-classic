local Activity = {}
function Activity.contains(world, body, margin)
    local view = world.activeView
    if not view or body.held or body.kind == "ghost" or body.kind == "ball" then return true end
    margin = margin or 16
    return body.x > view.x-margin and body.x < view.x+view.width+margin
        and body.y > view.y-margin and body.y < view.y+view.height+margin
end
function Activity.enemy(world, body)
    if body.kind == "ghost" or body.held then return true end
    local x = body.x-(body.width or 16)/2
    local y = body.y-(body.height or 16)
    if body.definition and body.definition.treasureAnchor then y = body.y-body.definition.treasureAnchor[2] end
    if body.kind == "damsel" then
        return Activity.contains(world, { x = body.x, y = body.y-8 })
    end
    local view = world.activeView
    if not view then return true end
    local near, far = 20, 4
    if body.kind == "giant_spider" then near, far = 32, 0 end
    return x > view.x-near and x < view.x+view.width+far
        and y > view.y-near and y < view.y+view.height+far
end
return Activity
