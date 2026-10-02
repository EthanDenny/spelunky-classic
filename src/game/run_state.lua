local RunState = {}
RunState.__index = RunState

local DEFAULT_EQUIPMENT = {
    spectacles = false,
    compass = false,
    parachute = false,
    paste = false,
    gloves = false,
    mitt = false,
    cape = false,
    jetpack = false,
    spike_shoes = false,
    spring_shoes = false,
    udjat_eye = false,
    kapala = false,
}

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function RunState.new(seed)
    seed = math.floor(seed or 1)
    return setmetatable({
        seed = seed,
        health = 4,
        maxHealth = 4,
        bombs = 4,
        ropes = 4,
        arrows = 0,
        money = 0,
        time = 0,
        kills = 0,
        damsels = 0,
        equipment = copy(DEFAULT_EQUIPMENT),
        shopkeeperAnger = 0,
        thief = false,
        murderer = false,
        favor = 0,
        blood = 0,
        hadDarkLevel = false,
        messages = {},
        heldItem = nil,
        heldDamsel = false,
    }, RunState)
end

function RunState:applyToPlayer(player)
    player.maxHealth = self.maxHealth
    player.health = math.min(self.health, self.maxHealth)
    player.equipment = copy(self.equipment)
end

function RunState:capturePlayer(player)
    self.maxHealth = player.maxHealth
    self.health = math.max(0, player.health)
    self.equipment = copy(player.equipment or self.equipment)
end

function RunState:addMessage(text, duration)
    self.messages[#self.messages + 1] = { text = text, timer = duration or 90 }
end

function RunState:currentMessage()
    return self.messages[1]
end

function RunState:update()
    local message = self.messages[1]
    if not message then return end
    message.timer = message.timer - 1
    if message.timer <= 0 then table.remove(self.messages, 1) end
end

function RunState:angerShopkeepers(reason)
    self.thief = true
    self.shopkeeperAnger = self.shopkeeperAnger + (self.shopkeeperAnger > 0 and 3 or 2)
    self:addMessage(reason or "STOP, THIEF!", 120)
end

function RunState:finishLevel()
    self.shopkeeperAnger = math.max(0, self.shopkeeperAnger - 1)
end

return RunState
