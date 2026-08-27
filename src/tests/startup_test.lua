local Startup = require("src.startup")

local Test = {}

function Test.run()
    local config = { window = {} }
    Startup.configureSplash(config)
    assert(config.identity == "spelunky-classic-clone", "Splash must retain the save identity")
    assert(config.window.width == 320 and config.window.height == 240,
        "Startup window must match the original 320x240 loading bitmap")
    assert(config.window.borderless and config.window.centered and not config.window.resizable,
        "The loading bitmap must appear in a centered frameless window")
    assert(not config.window.maximized, "The splash must not inherit the main window's maximized state")
    assert(Startup.MINIMUM_SPLASH_TIME > 0,
        "Interactive startup must keep the splash visible long enough to render")

    local image = Startup.loadSplashImage()
    assert(image:getWidth() == 320 and image:getHeight() == 240,
        "The extracted GameMaker splash dimensions changed")

    local imageData = love.image.newImageData(Startup.SPLASH_PATH)
    local red, green, blue = imageData:getPixel(0, 0)
    assert(red == 1 and green == 1 and blue == 1,
        "The original splash's top-left color key must remain white")

    local transparentImageData = Startup.loadSplashImageData()
    local _, _, _, transparentAlpha = transparentImageData:getPixel(0, 0)
    assert(transparentAlpha == 0,
        "The splash's white background must be converted to transparent pixels")
end

return Test
