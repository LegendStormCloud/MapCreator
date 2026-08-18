local utf8 = require "utf8"
local Object = require "libraries.classic"

local Field = Object:extend()

function Field:new(params)
    self.x = params.x
    self.y = params.y
    self.width = params.w
    self.height = params.h

    self.background_color = params.bColor or {0,0,0,1}

    self.border = params.border or false
    self.border_color = params.borColor or {0.4, 0.4, 0.4, 1}
    self.border_thickness = params.borThickness or 1

    self.text_padding = params.pad

    self.base_text = params.basetxt
    self.text = params.text or ""
    self.is_active = false
    self.is_numeric = params.isNumeric or false

    self.ontextentered = params.ontxtfunc

    if self.is_numeric and self.text == "" then
        self.text = "0"
    end

    self.font = love.graphics.getFont()
end

function Field:inside(x, y)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

function Field:mousepressed(x, y)
    local prev = self.is_active
    self.is_active = self:inside(x, y)
    if not self.is_active and prev and self.ontextentered then self:ontextentered() end 
end

function Field:setText(new_text)
    if self.text == new_text then return end

    self.text = new_text

    if self.ontextentered then self:ontextentered() end
end

function Field:textinput(t)
    if not self.is_active then return end

    if self.is_numeric then
        if t:match("%d") or (t == "." and not self.text:find("%. ")) then
            self:setText(self.text .. t)
        end
    else
        self:setText(self.text .. t)
    end
end

function Field:keypressed(key)
    if not self.is_active then return end

    if key == "backspace" then
        local byteoffset = utf8.offset(self.text, -1)
        if byteoffset then
            self:setText(string.sub(self.text, 1, byteoffset - 1))
        end

    elseif key == "return" or key == "kpenter" then
        self.is_active = false
        if self.ontextentered then self:ontextentered() end
    end
end

function Field:getText()
    local num = tonumber(self.text) or 0
    return self.is_numeric and num or self.text
end

function Field:getDisplayText()
    return self.base_text .. self.text
end

function Field:draw()
    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    if self.border or self.is_active then
        love.graphics.setLineWidth(self.border_thickness)
        if self.is_active then
            love.graphics.setColor(0.2, 0.6, 1, 1)
        else
            love.graphics.setColor(self.border_color)
        end
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    end

    love.graphics.setColor(1, 1, 1, 1)
    
    local display_text = self:getDisplayText()
    local textY = self.y + (self.height - self.font:getHeight()) / 2
    love.graphics.print(display_text, self.x + self.text_padding, textY)

    love.graphics.setLineWidth(1)
end

return Field