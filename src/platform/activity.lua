local Activity = {}
function Activity.contains(world, body, margin)
    local view = world.activeView
    if not view or body.held or body.kind == "ghost" or body.kind == "ball" then return true end
    margin = margin or 16
    return body.x > view.x-margin and body.x < view.x+view.width+margin
        and body.y > view.y-margin and body.y < view.y+view.height+margin
end
return Activity
