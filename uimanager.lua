local button = require "button"
local dropdown = require "dropdown"
local slider = require "slider"

local UIM = {}

local buttons = {}
local dropdowns = {}
local sliders = {}

function UIM.addButton(name, x, y, w, h, bColor, onclickfunction, tooltip, bPath)
    buttons[name] = button(x, y, w, h, bColor, onclickfunction, tooltip, bPath)
end

function UIM.getButton(name)
    return buttons[name]
end

function UIM.getDropDown(name)
    return dropdowns[name]
end

function UIM.getSlider(name)
    return sliders[name]
end

function UIM.addDropDown(name, x, y, w, h, bColor, hpad, vpad, extW, extH, content, onclick, tooltip, bPath)
    dropdowns[name] = dropdown(x, y, w, h, bColor, hpad, vpad, extW, extH, content, onclick, tooltip, bPath)
end

function UIM.addDropDownButton(dropdownName, buttonName, x, y, w, h, bColor, onclickfunction, tooltip, bPath)
    local dd = dropdowns[dropdownName]
    if dd then
        local btn = button(x, y, w, h, bColor, onclickfunction, tooltip, bPath)
        dd:addContent(buttonName, btn)
    end
end

function UIM.addSlider(name, x, y, fOffsetX, fOffsetY, bWidth, bHeight, bCol, fWidth, fHeight, fCol, dir, wholeN, minVal, maxVal, v, onvalchanged, interactive, hRadius)
    sliders[name] = slider(x, y, fOffsetX, fOffsetY, bWidth, bHeight, bCol, fWidth, fHeight, fCol, dir, wholeN, minVal, maxVal, v, onvalchanged, interactive, hRadius)
end

function UIM.checkOnUI(mx, my, lmb)
    for name, dd in pairs(dropdowns) do --probabilmente ci sarà un altro ciclo innestato per il contenuto del dropdown
        if dd:inside(mx, my) then
            if lmb then dd:mousepressed(mx, my) end
            return true
        end
    end

    for name, button in pairs(buttons) do
        if button:inside(mx, my) then
            if lmb then button:mousepressed(mx, my) end
            return true 
        end
    end

    for name, slid in pairs(sliders) do
        return slid:mouseInside(mx, my)
    end

    return false
end

function UIM.mousepressed(mx, my, mbutton)
    if mbutton == 1 then
        for name, dd in pairs(dropdowns) do
            dd:mousepressed(mx, my)
        end

        for name, button in pairs(buttons) do
            button:mousepressed(mx, my) 
        end

        for name, slid in pairs(sliders) do
            slid:mousepressed(mx, my)
        end
    end
end

function UIM.wheelmoved(y, speed)
    for name, dd in pairs(dropdowns) do
        dd:wheelmoved(y, speed)
    end
end

function UIM.mousereleased(mbutton)
    if mbutton == 1 then
        for name, slid in pairs(sliders) do
            slid:mousereleased()
        end
    end
end

function UIM.update(dt)
    for name, slid in pairs(sliders) do
        slid:update(dt)
    end
end

--potrebbe esserci da usare del priority sorting per il tooltip
function UIM.draw(mx, my)
    for name, button in pairs(buttons) do
        button:draw()
    end

    for name, dropdown in pairs(dropdowns) do
        dropdown:draw()
    end

    for name, slid in pairs(sliders) do
        slid:draw()
    end

    for name, button in pairs(buttons) do
        button:drawTooltip(mx, my)
    end

    for name, dropdown in pairs(dropdowns) do
        dropdown:drawTooltip(mx, my)
    end
end

return UIM