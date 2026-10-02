-- GameMaker's keys.cfg/settings.cfg order is defined by scrInit.gml and
-- oKeyConfig's Room End event in the bundled Classic source.
local ClassicControls = {}
ClassicControls.__index = ClassicControls

local KEY_ORDER = {
    "up", "down", "left", "right", "jump", "attack", "item", "run",
    "bomb", "rope", "flare", "pay",
}
local DEFAULT_KEYS = {
    up = 38, down = 40, left = 37, right = 39,
    jump = 90, attack = 88, item = 67, run = 16,
    bomb = 65, rope = 83, flare = 70, pay = 80,
}
local SETTINGS_ORDER = {
    "fullscreen", "graphicsHigh", "downToRun", "gamepadOn",
    "screenScale", "musicVol", "soundVol",
}
local DEFAULT_SETTINGS = {
    fullscreen = true, graphicsHigh = true, downToRun = true,
    gamepadOn = false, screenScale = 3, musicVol = 15, soundVol = 15,
}
local SPECIAL_KEYS = {
    [8] = { "backspace" }, [9] = { "tab" }, [13] = { "return", "kpenter" },
    [16] = { "lshift", "rshift" }, [17] = { "lctrl", "rctrl" },
    [18] = { "lalt", "ralt" }, [27] = { "escape" },
    [32] = { "space" }, [33] = { "pageup" }, [34] = { "pagedown" },
    [35] = { "end" }, [36] = { "home" }, [37] = { "left" },
    [38] = { "up" }, [39] = { "right" }, [40] = { "down" },
    [45] = { "insert" }, [46] = { "delete" },
}

local function loveKeys(code)
    if code >= 65 and code <= 90 then return { string.char(code):lower() } end
    if code >= 48 and code <= 57 then return { string.char(code) } end
    if code >= 96 and code <= 105 then return { "kp" .. (code - 96) } end
    if code >= 112 and code <= 123 then return { "f" .. (code - 111) } end
    return SPECIAL_KEYS[code]
end

local function lines(contents)
    local result = {}
    local normalized = (contents or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if normalized:sub(-1) ~= "\n" then normalized = normalized .. "\n" end
    for line in normalized:gmatch("(.-)\n") do
        result[#result + 1] = line:match("^%s*(.-)%s*$")
    end
    return result
end

function ClassicControls.fromContents(keysContents, settingsContents)
    local self = setmetatable({ keys = {}, settings = {} }, ClassicControls)
    local keyLines = lines(keysContents)
    for index, action in ipairs(KEY_ORDER) do
        local code = tonumber(keyLines[index])
        if code and code % 1 == 0 and loveKeys(code) then
            self.keys[action] = code
        else
            self.keys[action] = DEFAULT_KEYS[action]
        end
    end
    local settingLines = lines(settingsContents)
    for index, name in ipairs(SETTINGS_ORDER) do
        local raw = settingLines[index]
        if index <= 4 then
            if raw == nil then
                self.settings[name] = DEFAULT_SETTINGS[name]
            else
                self.settings[name] = raw ~= "0"
            end
        else
            local value = tonumber(raw)
            if not value or value ~= value or value == math.huge or value == -math.huge then
                value = DEFAULT_SETTINGS[name]
            end
            if name == "musicVol" or name == "soundVol" then
                value = math.max(0, math.min(17, value))
            end
            self.settings[name] = value
        end
    end
    return self
end

function ClassicControls.load()
    local keys = love.filesystem.read("keys.cfg")
    local settings = love.filesystem.read("settings.cfg")
    local keySource = keys and "keys.cfg" or "original-game-reference/keys.cfg"
    local settingsSource = settings and "settings.cfg" or "original-game-reference/settings.cfg"
    keys = keys or love.filesystem.read(keySource)
    settings = settings or love.filesystem.read(settingsSource)
    local self = ClassicControls.fromContents(keys, settings)
    self.keySource = keySource
    self.settingsSource = settingsSource
    return self
end

function ClassicControls:matches(action, key)
    for _, loveKey in ipairs(loveKeys(assert(self.keys[action], "Unknown Classic control: " .. tostring(action)))) do
        if key == loveKey then return true end
    end
    return false
end

function ClassicControls:held(action)
    return love.keyboard.isDown(unpack(loveKeys(assert(self.keys[action],
        "Unknown Classic control: " .. tostring(action)))))
end

function ClassicControls:label(action)
    local code = assert(self.keys[action], "Unknown Classic control: " .. tostring(action))
    if code == 16 then return "SHIFT" end
    if code == 17 then return "CTRL" end
    if code == 18 then return "ALT" end
    if code == 32 then return "SPACE" end
    if code >= 65 and code <= 90 then return string.char(code) end
    if code >= 48 and code <= 57 then return string.char(code) end
    return string.upper(loveKeys(code)[1])
end

function ClassicControls:playerInput()
    return {
        left = self:held("left"), right = self:held("right"),
        up = self:held("up"), down = self:held("down"),
        jump = self:held("jump"), sprint = self:held("run"),
        attack = self:held("attack"), item = self:held("item"),
        pay = self:held("pay"),
        downToRun = self.settings.downToRun,
    }
end

return ClassicControls
