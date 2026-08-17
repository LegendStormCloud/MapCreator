local utils = require "utils"

local Object = require "libraries.classic"

local Slider = Object:extend()

function Slider:new(params)
    self.x = params.x
    self.y = params.y
    self.foreground_offsetX = params.fOffsetX or 5
    self.foreground_offsetY = params.fOffsetY or 5

    self.background_width = params.bWidth or 100
    self.background_height = params.bHeight or 50
    self.background_color = params.bCol or {0, 0, 0, 1}

    self.foreground_width = params.fWidth or 90
    self.foreground_height = params.fHeight or 45
    self.foreground_color = params.fCol or {1,1,1,1}

    self.direction = params.dir or "lTr"

    self.wholeNumbers = params.wholeN or false
    self.minValue = params.minVal or 0
    self.maxValue = params.maxVal or 1
    self.value = math.clamp(params.minVal, params.maxVal, params.v or 0)
    self.onvaluechanged_action = params.onvalchanged

    self.interactive = params.interactive or false

    self.handle_centerX = 0
    self.handle_centerY = 0
    self.handle_radius = params.hRadius or self.foreground_height/2

    self.dragging = false
end

local function getDirOffset(self)
    local perc = math.ilerp(self.minValue, self.maxValue, self.value)

    if self.direction == "lTr" then return 0, 0, "x"
    elseif self.direction == "rTl" then return self.foreground_width * (1-perc), 0, "x"
    elseif self.direction == "tTb" then return 0, 0, "y"
    elseif self.direction == "bTt" then return 0, self.foreground_height * (1-perc), "y" end
end

local function getHandleCenter(self, fx, fy, fillX, fillY, perc)

    local cx, cy = fx + self.foreground_width * perc, fy + self.foreground_height/2

    if self.direction == "rTl" then
        cx = fx + self.foreground_width * (1 - perc)

    elseif self.direction == "tTb" then
        cx = fx + self.foreground_width/2
        cy = fy + self.foreground_height * perc

    elseif self.direction == "bTt" then
        cx = fx + self.foreground_width/2
        cy = fy + self.foreground_height * (1 - perc)
    end

    return cx, cy
end

function Slider:updateValue(newV)
    local v = math.clamp(self.minValue, self.maxValue, newV)
    self.value = self.wholeNumbers == true and math.round(v) or v
    if self.onvaluechanged_action then self:onvaluechanged_action() end
end

function Slider:mousepressed(x, y)
    if self.interactive == false then return end

    local dSq = (x-self.handle_centerX)*(x-self.handle_centerX) + (y-self.handle_centerY)*(y-self.handle_centerY)
    if dSq <= self.handle_radius*self.handle_radius then 
        self.dragging = true
    end
end

function Slider:mouseInside(mx, my)
    local rect = mx >= self.x and mx <= self.x + self.background_width and my >= self.y and my <= self.y + self.background_height
    local circ = (mx-self.handle_centerX)*(mx-self.handle_centerX) + (my-self.handle_centerY)*(my-self.handle_centerY) <= self.handle_radius * self.handle_radius
    return rect or circ
end

function Slider:mousereleased()
    self.dragging = false

    if self.interactive == false then return end
end

function Slider:update(dt)
    if self.dragging == false then return end

    local dirOffX, dirOffY, fillDir = getDirOffset(self)
    local fx = self.x + self.foreground_offsetX
    local fy = self.y + self.foreground_offsetY

    if fillDir == "x" then
        --cx va dove c'è il mouse
        self.handle_centerX = love.mouse.getX()
        self.handle_centerX = math.clamp(fx, fx + self.foreground_width, love.mouse.getX())
        
        local pos = math.ilerp(fx, fx + self.foreground_width, self.handle_centerX)
        local v = math.lerp(self.minValue, self.maxValue, pos)
        self:updateValue(v)
    end
end

function Slider:draw()
    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", self.x, self.y, self.background_width, self.background_height)

    love.graphics.setColor(self.foreground_color)

    local dirOffX, dirOffY, fillDir = getDirOffset(self)

    local fx = self.x + self.foreground_offsetX + dirOffX
    local fy = self.y + self.foreground_offsetY + dirOffY

    local perc = math.ilerp(self.minValue, self.maxValue, self.value)
    local fillX, fillY = self.foreground_width * (fillDir == "x" and perc or 1), self.foreground_height * (fillDir == "y" and perc or 1)
    love.graphics.rectangle("fill", fx, fy, fillX, fillY)

    love.graphics.setColor(1,1,1,1)

    self.handle_centerX, self.handle_centerY = getHandleCenter(self, fx, fy, fillX, fillY, perc)
    love.graphics.circle("fill", self.handle_centerX, self.handle_centerY, self.handle_radius)
end

return Slider