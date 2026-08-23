local button = require "ui_elements.button"
local dropdown = require "ui_elements.dropdown"
local slider = require "ui_elements.slider"
local inputfield = require "ui_elements.inputfield"

local UIM = {}

local buttons = {}
local dropdowns = {}
local sliders = {}
local fields = {}

--this groups have two values name and elements, elements is another dictionary of ui_element_type = element_name
local groups = {}

--NOT SURE BUT PROBABLY IN THE FUTURE THE LOOPS WILL GO AWAY

-- HELPER LOCAL FUNCTIONS

local function isElementActive(uielement)
    if not uielement.group then return true end
    local grp = groups[uielement.group]
    return grp and grp.active or false
end

local function registerToGroup(elementName, elementType, groupName)
    if not groupName then return end
    if not groups[groupName] then
        UIM.createGroup(groupName, false)
    end
    table.insert(groups[groupName].elements, { type = elementType, name = elementName })
end

-- UI functions // love functions

function UIM.mousepressed(mx, my, mbutton)
    if mbutton == 1 then
        for name, dd in pairs(dropdowns) do
            if isElementActive(dd) then dd:mousepressed(mx, my) end
        end

        for name, btn in pairs(buttons) do
            if isElementActive(btn) then btn:mousepressed(mx, my) end 
        end

        for name, slid in pairs(sliders) do
            if isElementActive(slid) then slid:mousepressed(mx, my) end
        end

        for name, ifild in pairs(fields) do
            if isElementActive(ifild) then ifild:mousepressed(mx, my) end
        end
    end
end

function UIM.textinput(t)
    for name, ifild in pairs(fields) do
        if isElementActive(ifild) then ifild:textinput(t) end
    end
end

function UIM.keypressed(key)
    for name, ifild in pairs(fields) do
        if isElementActive(ifild) then ifild:keypressed(key) end
    end
end

function UIM.wheelmoved(y, speed)
    for name, dd in pairs(dropdowns) do
        if isElementActive(dd) then dd:wheelmoved(y, speed) end
    end
end

function UIM.mousereleased(mbutton)
    if mbutton == 1 then
        for name, slid in pairs(sliders) do
            if isElementActive(slid) then slid:mousereleased() end
        end
    end
end

function UIM.update(dt)
    for name, slid in pairs(sliders) do
        if isElementActive(slid) then slid:update(dt) end
    end
end

function UIM.draw(mx, my)
    for name, btn in pairs(buttons) do
        if isElementActive(btn) then btn:draw() end
    end

    for name, dd in pairs(dropdowns) do
        if isElementActive(dd) then dd:draw() end
    end

    for name, slid in pairs(sliders) do
        if isElementActive(slid) then slid:draw() end
    end

    for name, ifild in pairs(fields) do
        if isElementActive(ifild) then ifild:draw() end
    end

    for name, btn in pairs(buttons) do
        if isElementActive(btn) then btn:drawTooltip(mx, my) end
    end

    for name, dd in pairs(dropdowns) do
        if isElementActive(dd) then dd:drawTooltip(mx, my) end
    end
end

-- adding UI elements

-- GROUP FUNCTIONS

function UIM.createGroup(name, active)
    groups[name] = {active = false, elements = {}}
end

function UIM.toggleGroup(name)
    if groups[name] then
        groups[name].active = not groups[name].active
    end
end

-- NORMAL UI ELEMENTS

function UIM.addButton(name, params)
    local btn = button(params)
    btn.group = params.group
    buttons[name] = btn
    registerToGroup(name, "button", params.group)
end

function UIM.addDropDown(name, params)
    local dd = dropdown(params)
    dd.group = params.group
    dropdowns[name] = dd
    registerToGroup(name, "dropdown", params.group)
end

--this doesn't need the group thing bc it's already managed by the dd script
function UIM.addDropDownButton(dropdownName, params)
    local dd = dropdowns[dropdownName]
    if dd then
        local btn = button(params)
        dd:addContent({name = btn})
    end
end

function UIM.addSlider(name, params)
    local slid = slider(params)
    slid.group = params.group
    sliders[name] = slid
    registerToGroup(name, "slider", params.group)
end

function UIM.addInputField(name, params)
    local ifild = inputfield(params)
    ifild.group = params.group
    fields[name] = ifild
    registerToGroup(name, "field", params.group)
end

-- getting UI elements by name

function UIM.getButton(name) return buttons[name] end
function UIM.getDropDown(name) return dropdowns[name] end
function UIM.getSlider(name) return sliders[name] end
function UIM.getField(name) return fields[name] end

function UIM.getGroupItems(gname)
    local group = groups[gname]
    local items = {}
    for i, elmt in ipairs(group.elements) do
        if elmt.type == "button" then
            items[elmt.name] = buttons[elmt.name]
        elseif elmt.type == "dropdown" then
            items[elmt.name] = dropdowns[elmt.name]
        elseif elmt.type == "slider" then
            items[elmt.name] = sliders[elmt.name]
        elseif elm.type == "field" then
            items[elmt.name] = fields[elmt.name]
        end
    end

    return items
end

-- Check for modifing the map

function UIM.checkOnUI(mx, my, lmb)
    for name, dd in pairs(dropdowns) do
        if isElementActive(dd) and dd:inside(mx, my) then
            if lmb then dd:mousepressed(mx, my) end
            return true
        end
    end

    for name, btn in pairs(buttons) do
        if isElementActive(btn) and btn:inside(mx, my) then
            if lmb then btn:mousepressed(mx, my) end
            return true 
        end
    end

    for name, slid in pairs(sliders) do
        if isElementActive(slid) and slid:mouseInside(mx, my) then
            return true
        end
    end

    for name, ifild in pairs(fields) do
        if isElementActive(ifild) and ifild:inside(mx, my) then
            return true
        end
    end

    return false
end

return UIM