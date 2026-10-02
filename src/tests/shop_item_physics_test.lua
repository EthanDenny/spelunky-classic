local Test = {}

function Test.run(app)
    -- The recorded weapon shop starts bomb boxes two pixels into its floor.
    -- Classic's active oItem physics settles them and lets them fall if it breaks.
    local screen = app.screens.full_level_playtest
    screen:loadAssets()
    screen.run = nil
    screen.levelNumber = 2
    screen:generateLevel(1790808068)
    local shopBox
    for _, item in ipairs(screen.items) do
        if item.kind == "bomb_box" and item.properties.forSale then
            shopBox = item
            break
        end
    end
    assert(shopBox, "Generated shop stock must enter item physics")
    local floorCellY = math.floor(shopBox.y / 16) + 1
    local floorTop = floorCellY * 16
    for _ = 1, 5 do screen:simulationStepBody({}) end
    assert(shopBox.y == floorTop - 8 and shopBox.entity.y == shopBox.y / 16,
        "Bomb boxes must settle with their collision bottom on the shop floor")
    screen.world:remove("solid", math.floor(shopBox.x / 16), floorCellY)
    for _ = 1, 10 do screen:simulationStepBody({}) end
    assert(shopBox.y > floorTop - 8,
        "Shop stock must fall when its supporting floor is removed")
    screen.level = nil
    screen.run = nil
    screen.seed = nil
end

return Test
