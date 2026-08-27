local NativeSplashWindow = {}

local available
local runtime
local state

local function loadRuntime()
    if runtime then return runtime end

    local ffi = require("ffi")
    ffi.cdef([[
        typedef signed char BOOL;
        typedef struct { double x; double y; } NSPoint;
        typedef struct { double width; double height; } NSSize;
        typedef struct { NSPoint origin; NSSize size; } NSRect;
        void *objc_getClass(const char *name);
        void *sel_registerName(const char *str);
        void *objc_msgSend(void *self, void *op, ...);
    ]])

    local objc = ffi.load("/usr/lib/libobjc.A.dylib")
    local function selector(name) return objc.sel_registerName(name) end

    runtime = {
        ffi = ffi,
        objc = objc,
        selector = selector,
        sendObject = ffi.cast("void *(*)(void *, void *)", objc.objc_msgSend),
        sendObjectCString = ffi.cast(
            "void *(*)(void *, void *, const char *)",
            objc.objc_msgSend
        ),
        sendObjectObject = ffi.cast(
            "void *(*)(void *, void *, void *)",
            objc.objc_msgSend
        ),
        sendVoid = ffi.cast("void (*)(void *, void *)", objc.objc_msgSend),
        sendVoidObject = ffi.cast(
            "void (*)(void *, void *, void *)",
            objc.objc_msgSend
        ),
        sendVoidBool = ffi.cast(
            "void (*)(void *, void *, BOOL)",
            objc.objc_msgSend
        ),
        initializeWindow = ffi.cast(
            "void *(*)(void *, void *, NSRect, unsigned long, unsigned long, BOOL)",
            objc.objc_msgSend
        ),
        initializeView = ffi.cast(
            "void *(*)(void *, void *, NSRect)",
            objc.objc_msgSend
        ),
    }
    return runtime
end

local function applicationWindow(mac)
    local applicationClass = mac.objc.objc_getClass("NSApplication")
    local application = mac.sendObject(applicationClass, mac.selector("sharedApplication"))
    local window = mac.sendObject(application, mac.selector("keyWindow"))
    if window == nil then window = mac.sendObject(application, mac.selector("mainWindow")) end
    return window
end

local function configureWindow(mac, window, transparent)
    if window == nil then return end

    local colorClass = mac.objc.objc_getClass("NSColor")
    local colorName = transparent and "clearColor" or "windowBackgroundColor"
    local color = mac.sendObject(colorClass, mac.selector(colorName))
    mac.sendVoidBool(window, mac.selector("setOpaque:"), transparent and 0 or 1)
    mac.sendVoidBool(window, mac.selector("setHasShadow:"), transparent and 0 or 1)
    mac.sendVoidObject(window, mac.selector("setBackgroundColor:"), color)
end

local function showMacSplash(imagePath)
    local mac = loadRuntime()
    local selector = mac.selector
    local loveWindow = applicationWindow(mac)
    if loveWindow == nil then return false end

    local rect = mac.ffi.new("NSRect")
    rect.size.width = 320
    rect.size.height = 240

    local stringClass = mac.objc.objc_getClass("NSString")
    local path = mac.sendObjectCString(
        stringClass,
        selector("stringWithUTF8String:"),
        imagePath
    )
    local imageClass = mac.objc.objc_getClass("NSImage")
    local image = mac.sendObject(imageClass, selector("alloc"))
    image = mac.sendObjectObject(image, selector("initWithContentsOfFile:"), path)
    if image == nil then return false end

    local imageViewClass = mac.objc.objc_getClass("NSImageView")
    local imageView = mac.sendObject(imageViewClass, selector("alloc"))
    imageView = mac.initializeView(imageView, selector("initWithFrame:"), rect)
    if imageView == nil then return false end
    mac.sendVoidObject(imageView, selector("setImage:"), image)

    local windowClass = mac.objc.objc_getClass("NSWindow")
    local splashWindow = mac.sendObject(windowClass, selector("alloc"))
    splashWindow = mac.initializeWindow(
        splashWindow,
        selector("initWithContentRect:styleMask:backing:defer:"),
        rect,
        0, -- NSWindowStyleMaskBorderless
        2, -- NSBackingStoreBuffered
        0
    )
    if splashWindow == nil then return false end

    configureWindow(mac, splashWindow, true)
    mac.sendVoidBool(splashWindow, selector("setReleasedWhenClosed:"), 0)
    mac.sendVoidBool(splashWindow, selector("setIgnoresMouseEvents:"), 1)
    mac.sendVoidObject(splashWindow, selector("setContentView:"), imageView)
    mac.sendVoid(splashWindow, selector("center"))

    mac.sendVoidObject(loveWindow, selector("orderOut:"), nil)
    mac.sendVoidObject(splashWindow, selector("makeKeyAndOrderFront:"), nil)

    state = {
        loveWindow = loveWindow,
        splashWindow = splashWindow,
        imageView = imageView,
        image = image,
        path = path,
    }
    return true
end

function NativeSplashWindow.enable(imagePath)
    if state then return true end
    if available == false then return false end
    if not love.system or love.system.getOS() ~= "OS X" then
        available = false
        return false
    end

    local ok, result = pcall(showMacSplash, imagePath)
    available = ok and result
    return available
end

function NativeSplashWindow.disable()
    if not state then return end

    local mac = loadRuntime()
    local selector = mac.selector
    mac.sendVoidObject(state.splashWindow, selector("orderOut:"), nil)
    mac.sendVoid(state.splashWindow, selector("close"))
    configureWindow(mac, state.loveWindow, false)
    mac.sendVoidObject(state.loveWindow, selector("makeKeyAndOrderFront:"), nil)
    state = nil
end

return NativeSplashWindow
