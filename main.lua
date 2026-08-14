local utf8 = require("utf8")

local gen = require "generator"
local UIM = require "uimanager"
local utils = require "utils"

local SAVEDIR = love.filesystem.getSaveDirectory()

local MIN_WINDOW_WIDTH = 800
local MIN_WINDOW_HEIGHT = 600
local CANVAS_SIZE = 1500

local UI_LEFT_SAFEZONE = 175
local UI_RIGHT_SAFEZONE = 0
local UI_TOP_SAFEZONE = 60
local UI_BOTTOM_SAFEZONE = 0

local UL = {0, UI_TOP_SAFEZONE}
local UR = {love.graphics.getWidth()-UI_RIGHT_SAFEZONE, UI_TOP_SAFEZONE}
local UT = {0, 0}
local UB = {0, love.graphics:getHeight()-UI_BOTTOM_SAFEZONE}

local scaleFactor = 1
local offsetX = 0
local offsetX = 0

local paintingHexagons = true
local placingLandmarks = false
local removingLandmark = false

local currentLandmark = nil
local landmark_sprites = {
    mountain = {
        img = love.graphics.newImage("sprites/landmarks/mountain.png"),
        scale = 1
    },

    skull = {
        img = love.graphics.newImage("sprites/landmarks/skull.png"),
        scale = 0.5
    },

    tower = {
        img = love.graphics.newImage("sprites/landmarks/tower.png"),
        scale = 0.75
    }
}

local landmarks = {}

local lmCooldown = 0.275
local lmTimer = 0
local lmScale = 1

local lmbDown = false
local rmbDown = false

local rowHexesInput = false
local noiseScaleInput = false
local noiseAmplitudeInput = false

local rowHexes = 10
local noiseScale = 0.05
local amplitude = 17

local rowHexesIText = tostring(rowHexes)
local noiseScaleIText = tostring(noiseScale)
local noiseAmplitudeIText = tostring(amplitude)

local shoreSmoothness = 0.5
local waveColor = {0.7, 0.9, 1.0, 0.85}
local waveBaseOffset = 12
local waveAmplitude = 8
local waveFrequency = 0.08
local waveSpeed = 3.0
local waveSegments = 12

local seed

--love functions

function love.load()
    love.window.setMode(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, {resizable = true})

    mapCanvas = love.graphics.newCanvas(CANVAS_SIZE, CANVAS_SIZE)

    updateViewport()

    love.math.setRandomSeed(os.time())
    seed = love.math.getRandomSeed()

    gen.load(CANVAS_SIZE, seed, rowHexes, amplitude, noiseScale) --canvas size, targetNx, scala, ampiezza noise

    addUIElements()
end

function love.keypressed(key)
    if key == "f1" then gen.debugFlags["show_centers"] = not gen.debugFlags["show_centers"] end
    if key == "f2" then gen.debugFlags["show_edges"] = not gen.debugFlags["show_edges"] end
    if key == "f3" then gen.debugFlags["show_fill"] = not gen.debugFlags["show_fill"] end
    if key == "f4" then gen.debugFlags["show_vertices"] = not gen.debugFlags["show_vertices"] end
    if key == "f5" then gen.debugFlags["show_terrain"] = not gen.debugFlags["show_terrain"] end
    if key == "f6" then gen.debugFlags["use_textures"] = not gen.debugFlags["use_textures"] end

    if key == "r" then rowHexesInput = not rowHexesInput end
    if key == "s" then noiseScaleInput = not noiseScaleInput end
    if key == "a" then noiseAmplitudeInput = not noiseAmplitudeInput end

    --if key == "l" then importAndLoadSettingsFile() end
    if key == "e" then exportSettingsFile() end

    if key == "backspace" then
        local currentText = (rowHexesInput and rowHexesIText) or (noiseScaleInput and noiseScaleIText) or (noiseAmplitudeInput and noiseAmplitudeIText) or ""
        
        local byteoffset = utf8.offset(currentText, -1)
        if byteoffset then
            local newText = string.sub(currentText, 1, byteoffset - 1)
            updateActiveInput(newText)
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        lmbDown = true
    elseif button == 2 then
        rmbDown = true
    end

    UIM.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 then
        lmbDown = false
    elseif button == 2 then
        rmbDown = false
    end

    UIM.mousereleased(button)
end

function love.wheelmoved(x, y)
    UIM.wheelmoved(y, speed)
end

function love.resize(w, h)
    if w < MIN_WINDOW_WIDTH or h < MIN_WINDOW_HEIGHT then
        love.window.setMode(math.max(MIN_WINDOW_WIDTH, w), math.max(MIN_WINDOW_HEIGHT, h), {resizable = true})
    end

    updateViewport()
end

function love.update(dt)
    tryPaintingHexagon()
    tryPlacingLandmark()
    tryRemovingLandmark()
    if placingLandmarks then lmTimer = lmTimer - dt end

    UIM.update(dt)
end

function love.textinput(t)
    if not t:match("[%d.,]") then return end

    local currentText = (rowHexesInput and rowHexesIText) or (noiseScaleInput and noiseScaleIText) or (noiseAmplitudeInput and noiseAmplitudeIText) or ""

    if (t == "." or t == ",") and (currentText:find("%.") or currentText:find(",")) then
        return
    end

    updateActiveInput(currentText .. t)
end

function love.draw()
    love.graphics.setCanvas({mapCanvas, stencil = true})
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    drawWorldElements()

    love.graphics.setCanvas()

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mapCanvas, offsetX, offsetY, 0, scaleFactor, scaleFactor)

    drawUI()
end

-- mouse coordinates

function getCanvasMousePosition()
    local mx, my = love.mouse.getPosition()
    return (mx - offsetX)/scaleFactor, (my - offsetY)/scaleFactor
end

function getUIMouseFromCanvas(mx, my)
    return mx*scaleFactor + offsetX, my*scaleFactor + offsetY
end

-- miscellaneus

function addUIElements()
    UIM.addButton(
        "paint", UL[1] + 10, UL[2], 50, 50, {0.25, 0.25, 0.25, 1},
        function(btn)
            paintingHexagons = not paintingHexagons
            placingLandmarks = false
            removingLandmark = false

            btn.toggled = not btn.toggled

            UIM.getDropDown("landmarks").is_open = false
            UIM.getSlider("scale_lm").interactive = false
            lmTimer = lmCooldown
            currentLandmark = nil
        end,
        "paint (lmb: land / rmb: water)", "sprites/paint_brush_icon.png"
    )

    UIM.addButton(
        "remove_landmark", UL[1] + 65, UL[2] + 55, 50, 50, {0.25, 0.25, 0.25, 1},
        function(btn)
            removingLandmark = true
            paintingHexagons = false
            placingLandmarks = false

            UIM.getButton("paint").toggled = not paintingHexagons
            UIM.getDropDown("landmarks").is_open = false
            UIM.getSlider("scale_lm").interactive = false

            currentLandmark = nil
        end,
        "remove landmark (lmb: single / rmb: all)", "sprites/remove_landmark_icon.png"
    )

    UIM.addButton(
        "export", UR[1] - 60, UT[2] + 5, 50, 50, {0.25, 0.25, 0.25, 1},
        function()
            exportMap()
        end,
        "export map", "sprites/export_icon.png"
    )

    UIM.addDropDown(
        "landmarks", UL[1] + 10, UL[2] + 55, 50, 50, {0.25, 0.25, 0.25, 1}, 5, 5, 155, 350, {},
        function(dd)
            placingLandmarks = dd.is_open
            paintingHexagons = not dd.is_open

            UIM.getButton("paint").toggled = not paintingHexagons
            UIM.getSlider("scale_lm").interactive = placingLandmarks

            removingLandmark = false
            currentLandmark = nil
        end,
        "open landmark menu", "sprites/add_landmark_icon.png"
    )

    UIM.addDropDownButton(
        "landmarks",
        "add_skull", 0, 0, 45, 45, {0.8, 0.8, 0.8, 1},
        function()
            currentLandmark = "skull"
        end,
        "", "sprites/landmarks/skull.png"
    )

    UIM.addDropDownButton(
        "landmarks",
        "add_tower", 0, 0, 45, 45, {0.8, 0.8, 0.8, 1},
        function()
            currentLandmark = "tower"
        end,
        "", "sprites/landmarks/tower.png"
    )

    UIM.addDropDownButton(
        "landmarks",
        "add_mountain", 0, 0, 45, 45, {0.8, 0.8, 0.8, 1},
        function()
            currentLandmark = "mountain"
        end,
        "", "sprites/landmarks/mountain.png"
    )

    UIM.addSlider(
        "scale_lm", UL[1] + 10, UL[2] + 485, 5, 5, 155, 40, {0.25, 0.25, 0.25}, 145, 30, {0.7, 0.7, 0.7}, "lTr", false, 0.5, 2, 1,
        function(sli)
            lmScale = sli.value
        end,
        false, 15
    )
end

function updateViewport()
    local winW, winH = love.graphics.getDimensions()

    local availableW = winW - UI_RIGHT_SAFEZONE - UI_LEFT_SAFEZONE
    local availableH = winH - UI_TOP_SAFEZONE - UI_BOTTOM_SAFEZONE

    availableW = math.max(availableW, 1)
    availableH = math.max(availableH, 1)

    local minSide = math.min(availableW, availableH)
    scaleFactor = minSide / CANVAS_SIZE

    offsetX = UI_LEFT_SAFEZONE + (availableW - minSide) / 2
    offsetY = UI_TOP_SAFEZONE + (availableH - minSide) / 2
end

function updateActiveInput(newText)
    local changed = false
    
    local formatted = newText:gsub(",", ".")
    local num = tonumber(formatted) or 0

    if rowHexesInput then
        rowHexesIText = newText
        rowHexes = num
        changed = true
    elseif noiseScaleInput then
        noiseScaleIText = newText
        noiseScale = num
        changed = true
    elseif noiseAmplitudeInput then
        noiseAmplitudeIText = newText
        amplitude = num
        changed = true
    end

    if changed then
        gen.generate(CANVAS_SIZE, rowHexes, amplitude, noiseScale)
    end
end

-- drawing stuff

function drawWorldElements(preview)
    preview = preview or true
    gen.drawMap()
    drawShorelineWaves()
    drawLandMarks()
    if preview then drawLandMarkPreview() end
end

function drawLandMarks()
    for i, lm in ipairs(landmarks) do
        love.graphics.draw(lm[1], lm[2], lm[3], 0, lm[4], lm[4], lm[5], lm[6])
    end
end

function drawLandMarkPreview()
    if not placingLandmarks then return end
    if currentLandmark == nil or landmark_sprites[currentLandmark] == nil then return end

    local lms = landmark_sprites[currentLandmark]
    local img = lms.img
    local mx, my = getCanvasMousePosition()
    local ox, oy = img:getWidth()/2, img:getHeight()/2
    love.graphics.draw(img, mx, my, 0, lms.scale * lmScale, lms.scale * lmScale, ox, oy)
end

function drawShorelineWaves()
    local function getWaveValue(x, y, time, smoothParam)
        local phase = (x + y) * waveFrequency + time * waveSpeed
        local angular = math.abs((phase % 2) - 1)
        local smoothW = (math.sin(phase) + 1) * 0.5
        return math.lerp(angular, smoothW, smoothParam)
    end

    local time = love.timer.getTime()
    
    love.graphics.setLineWidth(3)
    love.graphics.setColor(waveColor) -- Colore schiuma/onda

    local map = gen.getMap()
    for q, row in pairs(map) do
        for r, hex in pairs(row) do
            if hex.terrain == "shore" then
                local edges = gen.getWaterFacingEdges(hex)
                
                for _, edge in ipairs(edges) do
                    local points = {}
                    
                    -- Suddividiamo il lato in N segmenti per applicare l'onda curva
                    for i = 0, waveSegments do
                        local t = i / waveSegments
                        
                        -- Punto base lungo il lato dell'esagono
                        local px = math.lerp(edge.x1, edge.x2, t)
                        local py = math.lerp(edge.y1, edge.y2, t)
                        
                        -- Calcolo dell'offset dell'onda in quel punto
                        local waveFactor = getWaveValue(px, py, time, shoreSmoothness)
                        local totalOffset = waveBaseOffset + (waveFactor * waveAmplitude)
                        
                        -- Spostiamo il punto verso l'esterno lungo la normale dell'acqua
                        local finalX = px + edge.nx * totalOffset
                        local finalY = py + edge.ny * totalOffset
                        
                        table.insert(points, finalX)
                        table.insert(points, finalY)
                    end
                    
                    -- Disegna la linea dell'onda curva e distanziata
                    if #points >= 4 then
                        love.graphics.line(points)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function drawUI()
    --SAFE AREA
    UL = {0, UI_TOP_SAFEZONE}
    UR = {love.graphics.getWidth()-UI_RIGHT_SAFEZONE, UI_TOP_SAFEZONE}
    UT = {0, 0}
    UB = {0, love.graphics:getHeight()-UI_BOTTOM_SAFEZONE}

    love.graphics.setColor(0.1, 0.1, 0.1)

    love.graphics.rectangle("fill", UL[1], UL[2], UI_LEFT_SAFEZONE, love.graphics.getHeight()-UI_BOTTOM_SAFEZONE)
    love.graphics.rectangle("fill", UR[1], UR[2], UI_TOP_SAFEZONE, UI_RIGHT_SAFEZONE, love.graphics.getHeight()-UI_BOTTOM_SAFEZONE)
    love.graphics.rectangle("fill", UT[1], UT[2], love.graphics.getWidth(), UI_TOP_SAFEZONE)
    love.graphics.rectangle("fill", UB[1], UB[2], love.graphics.getWidth(), UI_BOTTOM_SAFEZONE)

    --real UI (mostly still debug)

    love.graphics.setColor(1, 1, 1)
    local input_debug = "RHI: " .. tostring(rowHexesInput) .. "\nNSI: " .. tostring(noiseScaleInput) .. "\nNAI: " .. tostring(noiseAmplitudeInput)
    love.graphics.print(input_debug, UL[1] + 70, UL[2] + 5)

    local hexPerRow_TXT = "row hexes: " .. rowHexes
    local noiseScale_TXT = ", noise scale: " .. noiseScale
    local noiseAmplitude_TXT = ", noise amplitude: " .. amplitude
    local paintingHexagon_TXT = ", painting: " .. tostring(paintingHexagons)
    local placingLandmarks_TXT = ", placing LM: " .. tostring(placingLandmarks)
    local removingLandmark_TXT = ", removing LM: " .. tostring(removingLandmark)

    local totalTXT = hexPerRow_TXT .. noiseScale_TXT .. noiseAmplitude_TXT .. paintingHexagon_TXT .. placingLandmarks_TXT .. removingLandmark_TXT

    love.graphics.print(totalTXT, UT[1] + 10, UT[2] + 10)
    love.graphics.print("tot lm: " .. #landmarks, UT[1] + 20 + love.graphics.getFont():getWidth(totalTXT), UT[2] + 10)

    local mx, my =  getCanvasMousePosition()
    local mouseCoordinates_TXT = "mx, my: " .. math.round(mx) .. ", " .. math.round(my)

    love.graphics.print(mouseCoordinates_TXT, UL[1] + UI_LEFT_SAFEZONE + 10, UI_TOP_SAFEZONE + 10)
    love.graphics.print("f1: toggle center vis, f2: toggle edge vis, f3: toggle fill vis, f4: toggle vertices, f5: toggle terrain, f6: toggle textures", UT[1] + 10, UT[2] + 30)

    local lmscaleTXT = math.round(10000*lmScale)/100 .. "%"
    love.graphics.print("landmark scale: " .. lmscaleTXT, UL[1] + 10, UL[2] + 465)

    local mx, my = love.mouse.getPosition(x, y)

    local expBtn = UIM.getButton("export")
    if expBtn then
        expBtn.x = UR[1] - 60
    end

    UIM.draw(mx, my)
end

-- modifing map

function ModifyMap()
    tryPaintingHexagon()
    tryPlacingLandmark()
    tryRemovingLandmark()
end

function tryPaintingHexagon()
    if not paintingHexagons then return end

    local wx, wy = getCanvasMousePosition()

    if wx < -gen.radius or wx > CANVAS_SIZE + gen.radius or wy < -gen.radius or wy > CANVAS_SIZE + gen.radius then return end 

    local q, r = gen.worldToHex(wx, wy)
    local hex = gen.getHex(q, r)

    if hex == nil then return end

    hex.mouseover = true

    if not lmbDown and not rmbDown then return end

    local umx, umy = love.mouse.getPosition()
    if UIM.checkOnUI(umx, umy, lmbDown) then return end

    if lmbDown then hex.terrain = "land" end
    if rmbDown then hex.terrain = "water" end

    if lmbDown or rmbDown then gen.updateShoreline() end
end

function tryPlacingLandmark()
    if not placingLandmarks then return end
    if not lmbDown then return end
    if currentLandmark == nil or landmark_sprites[currentLandmark] == nil then return end
    if lmTimer > 0 then return end

    local umx, umy = love.mouse.getPosition()
    if UIM.checkOnUI(umx, umy, lmbDown) then return end

    local mx, my = getCanvasMousePosition()

    if mx < 0 or mx > CANVAS_SIZE or my < 0 or my > CANVAS_SIZE then return end 

    local lm = landmark_sprites[currentLandmark]
    local img = lm.img
    local ox, oy = img:getWidth()/2, img:getHeight()/2
    table.insert(landmarks, {img, mx, my, lm.scale * lmScale, ox, oy})
    lmTimer = lmCooldown
end

function tryRemovingLandmark()
    if not removingLandmark then return end
    if not lmbDown and not rmbDown then return end

    local umx, umy = love.mouse.getPosition()
    if UIM.checkOnUI(umx, umy, lmbDown) then return end

    if lmbDown then
        local mx, my = getCanvasMousePosition()

        for i = #landmarks, 1, -1 do
            local lm = landmarks[i]
            local x = lm[2] - lm[5] * lm[4] --x - ox*scale
            local y = lm[3] - lm[6] * lm[4]
            local w, h = lm[1]:getWidth() * lm[4], lm[1]:getHeight() * lm[4] --img_w * scale

            if mx >= x and mx <= x + w and my >= y and my <= y + h then
                table.remove(landmarks, i)
                return
            end
        end
    elseif rmbDown then
        landmarks = {}
    end
end

-- file managment

function exportSettingsFile()

end

function importAndLoadSettingsFile()

end

function exportMap()
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = "map_" .. timestamp .. ".png" 

    local canvas = love.graphics.newCanvas(CANVAS_SIZE, CANVAS_SIZE)

    local oldDebugFlags = {}
    for k, v in pairs(gen.debugFlags) do
        oldDebugFlags[k] = v
        
        -- Manteniamo attivi show_fill, pointy_top e USE_TEXTURES per l'esportazione
        if k ~= "pointy_top" and k ~= "show_fill" and k ~= "use_textures" then
            gen.debugFlags[k] = false
        end
    end

    love.graphics.setCanvas({canvas, stencil = true})
    
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)

    drawWorldElements(false)

    love.graphics.pop()
    love.graphics.setCanvas()

    for k, v in pairs(oldDebugFlags) do
        gen.debugFlags[k] = v
    end

    local imageData = canvas:newImageData()
    imageData:encode("png", filename)
end