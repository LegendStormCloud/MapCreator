local button = require "ui_elements.button"
local dropdown = require "ui_elements.dropdown"
local slider = require "ui_elements.slider"
local inputfield = require "ui_elements.inputfield"

local UIM = {}

local buttons = {}
local dropdowns = {}
local sliders = {}
local fields = {}

--NOT SURE BUT PROBABLY IN THE FUTURE THE LOOPS WILL GO AWAY

-- UI functions // love functions

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

        for name, ifild in pairs(fields) do
            ifild:mousepressed(mx, my)
        end
    end
end

function UIM.textinput(t)
    for name, ifild in pairs(fields) do
        ifild:textinput(t)
    end
end

function UIM.keypressed(key)
    for name, ifild in pairs(fields) do
        ifild:keypressed(key)
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

    for name, ifild in pairs(fields) do
        ifild:draw()
    end

    for name, button in pairs(buttons) do
        button:drawTooltip(mx, my)
    end

    for name, dropdown in pairs(dropdowns) do
        dropdown:drawTooltip(mx, my)
    end
end

-- adding UI elements

function UIM.addButton(name, params)
    buttons[name] = button(params)
end

function UIM.addDropDown(name, params)
    dropdowns[name] = dropdown(params)
end

function UIM.addDropDownButton(dropdownName, buttonName, params)
    local dd = dropdowns[dropdownName]
    if dd then
        local btn = button(params)
        dd:addContent(buttonName, btn)
    end
end

function UIM.addSlider(name, params)
    sliders[name] = slider(params)
end

function UIM.addInputField(name, params)
    fields[name] = inputfield(params)
end

-- getting UI elements by name

function UIM.getButton(name)
    return buttons[name]
end

function UIM.getDropDown(name)
    return dropdowns[name]
end

function UIM.getSlider(name)
    return sliders[name]
end

-- Check for modifing the map

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
        if slid:mouseInside(mx, my) then return true end
    end

    for name, ifild in pairs(fields) do
        if ifild:inside(mx, my) then return true end
    end

    return false
end

return UIM