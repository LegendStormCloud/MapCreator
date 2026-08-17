local Object = require "libraries.classic"

local Button = Object:extend()

function Button:new(params)
    self.x = params.x
    self.y = params.y
    self.width = params.w
    self.height = params.h

    self.background_color = params.bColor or (params.bPath == nil and {0.141, 0.125, 0.125, 1} or {1, 1, 1, 1})

    self.onclickfunction = params.onclick

    self.tooltip = params.tooltip

    self.background_sprite = params.bPath and love.graphics.newImage(params.bPath) or nil

    self.toggled = false
end

function Button:inside(x, y)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

function Button:mousepressed(mx, my)
    if self:inside(mx, my) then
        if self.onclickfunction then self:onclickfunction() end
    end
end

function Button:drawTooltip(mx, my)
    if not self:inside(mx, my) then return end
    if self.tooltip then
        local font = love.graphics.getFont()
        local lw = love.graphics.getLineWidth()
        
        local w = font:getWidth(self.tooltip) + 2*lw
        local h = font:getHeight(self.tooltip) + 2*lw

        local x, y = mx, my - h

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x, y, w, h)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", x, y, w, h)

        love.graphics.print(self.tooltip, x+lw, y+lw)

        love.graphics.setColor(1,1,1,1)
    end
end

function Button:draw()
    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    if self.background_sprite then
        love.graphics.setColor(self.toggled and {0.3, 0.3, 0.3, 1} or {1, 1, 1, 1})
        local sx, sy = self.width/self.background_sprite:getWidth(), self.height/self.background_sprite:getHeight()
        love.graphics.draw(self.background_sprite, self.x, self.y, 0, sx, sy)
    end

    love.graphics.setColor(1,1,1,1)
end

return Button