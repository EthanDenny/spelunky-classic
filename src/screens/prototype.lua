local Prototype = {}
Prototype.__index = Prototype

function Prototype.new(app, options)
    return setmetatable({
        app = app,
        title = assert(options.title),
        description = assert(options.description),
        accent = options.accent or { 0.72, 0.18, 0.10 },
        drawPreview = options.drawPreview,
        elapsed = 0,
    }, Prototype)
end

function Prototype:enter()
    self.elapsed = 0
end

function Prototype:update(dt)
    self.elapsed = self.elapsed + dt
end

function Prototype:draw()
    local width, height = love.graphics.getDimensions()
    local panelX = math.max(32, width * 0.10)
    local panelY = 150
    local panelWidth = width - panelX * 2
    local panelHeight = math.max(220, height - 245)

    love.graphics.clear(0.045, 0.04, 0.035)

    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(0.92, 0.86, 0.72)
    love.graphics.printf(self.title, 32, 45, width - 64, "center")

    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(0.56, 0.50, 0.40)
    love.graphics.printf(self.description, 48, 101, width - 96, "center")

    love.graphics.setColor(0.085, 0.075, 0.062)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)
    love.graphics.setColor(self.accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    if self.drawPreview then
        self:drawPreview(panelX, panelY, panelWidth, panelHeight)
    end

    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(0.56, 0.50, 0.40)
    love.graphics.printf("ESC  BACK TO PROTOTYPE MENU", 16, height - 35, width - 32, "center")
end

return Prototype
