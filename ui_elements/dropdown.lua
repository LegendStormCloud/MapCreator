local Object = require "libraries.classic"
local utils = require "utils"
local DropDown = Object:extend()

function DropDown:new(params)
    self.x = params.x
    self.y = params.y
    self.width = params.w
    self.height = params.h
    self.extended_width = params.extW
    self.extended_height = params.extH
    
    self.background_color = params.bColor or {1,1,1,1}
    
    self.horizontal_padding = params.hpad
    self.vertical_padding = params.vpad
    
    self.scrollOffsetY = 0

    self.content = params.content or {}

    self.onclickfunction = params.onclick
    
    self.tooltip = params.tooltip or ""
    self.background_sprite = params.bPath and love.graphics.newImage(params.bPath) or nil

    self.is_open = false

    --content passed needs to be like {{name1 = item1}, {name2 = item2}, ...} (if any is passed)

    if content then
        for i, item in ipairs(content) do
            self:addContent(item)
        end
    end
end

function DropDown:updateLayout()
    local ox = self.x + self.horizontal_padding
    local oy = self.y + self.height + self.vertical_padding + self.scrollOffsetY

    local itm_size = (self.extended_width - 3 * self.horizontal_padding) / 2
    if itm_size < 1 then return end

    for i, entry in ipairs(self.content) do
        local item = entry.name
        local idx = i - 1 
        
        local col = idx % 2 
        local row = math.floor(idx / 2) 

        item.x = ox + col * (itm_size + self.horizontal_padding)
        item.y = oy + row * (itm_size + self.vertical_padding)
        item.width = itm_size
        item.height = itm_size
    end
end

function DropDown:addContent(item)
    table.insert(self.content, item)
    self:updateLayout()
end

function DropDown:removeContent(cond) --current supported conditions: single number, name
    local indx = tonumber(cond)

    if indx then
        table.remove(self.content, indx)
    else
        for i = #self.content, 1, -1 do
            if self.content[i].name == cond then
                table.remove(self.content, i)
                break
            end
        end
    end

    self:updateLayout()
end

function DropDown:inside(mx, my)
    local totalH = self.height + (self.is_open and self.extended_height or 0)
    local totalW = self.width + (self.is_open and self.extended_width or 0)
    return mx >= self.x and mx <= self.x + totalW and my >= self.y and my <= self.y + totalH
end

function DropDown:mousepressed(mx, my)
    local onHeader = mx >= self.x and mx <= self.x + self.width and my >= self.y and my <= self.y + self.height

    if onHeader then
        self.is_open = not self.is_open
        if self.onclickfunction then self:onclickfunction() end
    end

    if self.is_open then
        if self:inside(mx, my) then
            for _, entry in ipairs(self.content) do
                entry.name:mousepressed(mx, my)
            end
        end
    end
end

function DropDown:wheelmoved(y, speed)
    if not self.is_open then return end

    local rows = math.ceil(#self.content/2)
    print(rows)
    local itm_size = (self.extended_width - 3 * self.horizontal_padding) / 2
    local MSOY = rows*itm_size + (rows+1)*self.vertical_padding - self.extended_height
    print(MSOY)
    self.scrollOffsetY = math.clamp(-MSOY, 0, self.scrollOffsetY + y*speed)
    print(self.scrollOffsetY)
    self:updateLayout()
end

function DropDown:drawTooltip(mx, my)
    local onHeader = mx >= self.x and mx <= self.x + self.width and my >= self.y and my <= self.y + self.height

    if not onHeader then return end
    if self.tooltip == "" then return end

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

function DropDown:draw()
    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    if self.background_sprite then
        love.graphics.setColor(1, 1, 1, 1)
        local sx, sy = self.width/self.background_sprite:getWidth(), self.height/self.background_sprite:getHeight()
        love.graphics.draw(self.background_sprite, self.x, self.y, 0, sx, sy)
    end

    if self.is_open then
        love.graphics.setColor(self.background_color)
        local x, y = self.x, self.y + self.height
        local w, h = self.extended_width, self.extended_height
        love.graphics.rectangle("fill", x, y, w, h)

        love.graphics.stencil(
            function()
                love.graphics.rectangle("fill", x, y, w, h)
            end,
            "replace", 1
        )

        love.graphics.setStencilTest("greater", 0)

        for _, entry in ipairs(self.content) do
            entry.name:draw()
        end

        love.graphics.setStencilTest()
    end

    love.graphics.setColor(1,1,1,1)
end

return DropDown