local Startup = {}
local NativeSplashWindow = require("src.native_splash_window")

Startup.SPLASH_PATH = "original-game-reference/source/extracted/spelunky/loading image.png"
Startup.TRANSPARENT_SPLASH_FILENAME = "loading-transparent.png"
Startup.SPLASH_WIDTH = 320
Startup.SPLASH_HEIGHT = 240
Startup.MINIMUM_SPLASH_TIME = 0.85

Startup.MAIN_WIDTH = 1280
Startup.MAIN_HEIGHT = 900
Startup.MAIN_MIN_WIDTH = 1040
Startup.MAIN_MIN_HEIGHT = 896
Startup.MAIN_TITLE = "Spelunky Classic Clone"

function Startup.configureSplash(config)
    config.identity = "spelunky-classic-clone"
    config.window.title = ""
    config.window.width = Startup.SPLASH_WIDTH
    config.window.height = Startup.SPLASH_HEIGHT
    config.window.resizable = false
    config.window.borderless = true
    config.window.centered = true
    config.window.maximized = false
    config.window.highdpi = false
    config.window.vsync = 1
end

function Startup.loadSplashImageData()
    local imageData = love.image.newImageData(Startup.SPLASH_PATH)
    imageData:mapPixel(function(_, _, red, green, blue, alpha)
        if red == 1 and green == 1 and blue == 1 then
            return red, green, blue, 0
        end
        return red, green, blue, alpha
    end)
    imageData:encode("png", Startup.TRANSPARENT_SPLASH_FILENAME)
    Startup.transparentSplashPath = love.filesystem.getSaveDirectory()
        .. "/" .. Startup.TRANSPARENT_SPLASH_FILENAME
    return imageData
end

function Startup.loadSplashImage()
    local imageData = Startup.loadSplashImageData()
    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")
    assert(image:getWidth() == Startup.SPLASH_WIDTH
        and image:getHeight() == Startup.SPLASH_HEIGHT,
        "Original splash image must remain exactly 320x240")
    return image
end

function Startup.drawSplash(image)
    NativeSplashWindow.enable(Startup.transparentSplashPath)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, 0, 0)
end

function Startup.openMainWindow(maximize)
    NativeSplashWindow.disable()
    local opened = love.window.setMode(Startup.MAIN_WIDTH, Startup.MAIN_HEIGHT, {
        fullscreen = false,
        resizable = true,
        borderless = false,
        centered = true,
        minwidth = Startup.MAIN_MIN_WIDTH,
        minheight = Startup.MAIN_MIN_HEIGHT,
        vsync = 1,
        highdpi = false,
    })
    assert(opened, "Could not create the main game window")
    love.window.setTitle(Startup.MAIN_TITLE)
    if maximize then love.window.maximize() end
end

return Startup
