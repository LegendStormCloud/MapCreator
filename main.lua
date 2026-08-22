local utf8 = require "utf8"
local json = require "libraries.json"

local gen = require "generator"
local UIM = require "uimanager"
local utils = require "utils"

local LOVE_DIR = love.filesystem.getSaveDirectory()
local SETTINGS_DIR = LOVE_DIR ..  "/Settings"
local MAPSAVES_DIR = LOVE_DIR .. "/MapSaves"
local LANDMARKS_DIR = LOVE_DIR .. "/Landmarks"

local MIN_WINDOW_WIDTH = 1280
local MIN_WINDOW_HEIGHT = 720
local CANVAS_SIZE = 2000

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

--STANDARD SIZE: 512X512
--DRAWINGS SHOULD BE ALREADY SCALED -> NO INNER SCALE 
--MAYBE ADD BOUNDING BOX FOR REMOVAL DETECTION

local landmark_sprites = {}

local landmarks = {}

local landmarkPlacingCooldown = 0.275
local lmTimer = 0
local landmarkScale = 1

local lmbDown = false
local rmbDown = false
local wheelDown = false

local rowHexes = 10
local noiseScale = 0.05
local noiseAmplitude = 17

local shoreSmoothness = 0.5
local waveColor = {0.7, 0.9, 1.0, 0.85}
local waveBaseOffset = 12
local waveAmplitude = 8
local waveFrequency = 0.08
local waveSpeed = 3.0
local waveSegments = 12

local scrollspeed = 50
local seed = 0

local screenMouseX, screenMouseY = love.mouse.getPosition()
local deltaX, deltaY = 0, 0
local moveCursor = love.mouse.newCursor("sprites/cursors/move.png", 16, 16)

local zoomSpeed = 1
local zoomLevel = 1
local zoomingCamera = false

local wasFocused = true

--FOR THE FUTURE: ADD CUSTOM CURSOR FOR DIFFERENT EDITING MODES (THIS WILL REMOVE THE DEBUG FOR PAINTING, PLACING, REMOVING)

-- HELPER FUNCTIONS, THIS ARE LOCAL SO THEY SATAY AT THE TOP

local function getClampingCanvasPositionLimits()
    local mapDrawSize = CANVAS_SIZE * scaleFactor * zoomLevel
    local margin = mapDrawSize * 0.05

    local minX = UL[1] + UI_LEFT_SAFEZONE + margin - mapDrawSize
    local minY = UL[2] + margin - mapDrawSize
    
    local maxX = (love.graphics.getWidth() - UI_RIGHT_SAFEZONE) - margin
    local maxY = (love.graphics.getHeight() - UI_BOTTOM_SAFEZONE) - margin

    return minX, minY, maxX, maxY
end

--love functions

function love.load()
    love.window.setMode(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, {resizable = true, minwidth = MIN_WINDOW_WIDTH, minheight = MIN_WINDOW_HEIGHT})

    mapCanvas = love.graphics.newCanvas(CANVAS_SIZE, CANVAS_SIZE)

    updateViewport()

    addUIElements()
    uploadLandmarks()

    loadSettings("latest_settings")
end

function love.keypressed(key)
    if key == "f1" then gen.debugFlags["show_centers"] = not gen.debugFlags["show_centers"] end
    if key == "f2" then gen.debugFlags["show_edges"] = not gen.debugFlags["show_edges"] end
    if key == "f3" then gen.debugFlags["show_fill"] = not gen.debugFlags["show_fill"] end
    if key == "f4" then gen.debugFlags["show_vertices"] = not gen.debugFlags["show_vertices"] end
    if key == "f5" then gen.debugFlags["show_terrain"] = not gen.debugFlags["show_terrain"] end
    if key == "f6" then gen.debugFlags["use_textures"] = not gen.debugFlags["use_textures"] end

    local ctrlDown = love.keyboard.isDown("lctrl", "lgui")
    local shiftDown = love.keyboard.isDown("lshift")

    if ctrlDown then
        if key == "s" then
            -- save map
        elseif key == "e" then
            exportMap()
        elseif key == "l" then
            uploadLandmarks(true)
        end
    end

    UIM.keypressed(key)
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        lmbDown = true
    elseif button == 2 then
        rmbDown = true
    elseif button == 3 then
        wheelDown = true
        love.mouse.setCursor(moveCursor)
    end

    UIM.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 then
        lmbDown = false
    elseif button == 2 then
        rmbDown = false
    elseif button == 3 then
        wheelDown = false
        love.mouse.setCursor()
    end

    UIM.mousereleased(button)
end

function love.wheelmoved(x, y)
    if not UIM.checkOnUI(screenMouseX, screenMouseY) then 
        local dir = y/math.abs(y)
        local oldZoom = zoomLevel
        local newZoom = math.clamp(0.5, 2, zoomLevel + 0.05 * dir)

        if newZoom ~= oldZoom then
            local cmx, cmy = getCanvasMousePosition()

            zoomLevel = newZoom

            offsetX = screenMouseX - (cmx * scaleFactor * zoomLevel)
            offsetY = screenMouseY - (cmy * scaleFactor * zoomLevel)

            local minX, minY, maxX, maxY = getClampingCanvasPositionLimits()

            offsetX = math.clamp(minX, maxX, offsetX)
            offsetY = math.clamp(minY, maxY, offsetY)
        end
    end

    UIM.wheelmoved(y, scrollspeed)
end

function love.resize(w, h)
    updateViewport()
end

function love.update(dt)
    local px, py = screenMouseX, screenMouseY
    screenMouseX, screenMouseY = love.mouse.getPosition()
    deltaX, deltaY = screenMouseX - px, screenMouseY - py
    if wheelDown then
        local minX, minY, maxX, maxY = getClampingCanvasPositionLimits()

        offsetX = math.clamp(minX, maxX, offsetX + deltaX)
        offsetY = math.clamp(minY, maxY, offsetY + deltaY)
    end

    tryPaintingHexagon()
    tryPlacingLandmark()
    tryRemovingLandmark()
    if placingLandmarks then lmTimer = lmTimer - dt end

    UIM.update(dt)
end

function love.textinput(t)
    UIM.textinput(t)
end

function love.focus(f)
    --logica dell'uload
    if f == true and wasFocused == false then
        uploadLandmarks()
    end
    wasFocused = f
end

function love.draw()
    --camera implementation
    love.graphics.setCanvas({mapCanvas, stencil = true})
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    drawWorldElements()

    love.graphics.setCanvas()

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mapCanvas, offsetX, offsetY, 0, scaleFactor*zoomLevel, scaleFactor*zoomLevel)

    drawUI()
end

function love.quit()
    saveSettings("latest_settings")
    --saveMap("latest_map")
end

-- mouse coordinates

function getCanvasMousePosition()
    return (screenMouseX - offsetX)/(scaleFactor*zoomLevel), (screenMouseY - offsetY)/(scaleFactor*zoomLevel)
end

function getUIMouseFromCanvas(cmx, cmy)
    return cmx*scaleFactor*zoomLevel + offsetX, cmy*scaleFactor*zoomLevel + offsetY
end

-- miscellaneus

function addUIElements()
    --Buttons: x, y, w, h, bColor, onclick, tooltip, bPath

    UIM.addButton(
        "paint", 
        {
            x = UL[1] + 10, y = UL[2], w = 50, h = 50, bColor = {0.25, 0.25, 0.25, 1},
            onclick = function(btn)
                paintingHexagons = not paintingHexagons
                placingLandmarks = false
                removingLandmark = false

                btn.toggled = not btn.toggled

                UIM.getDropDown("landmarks").is_open = false
                UIM.getSlider("scale_lm").interactive = false
                lmTimer = landmarkPlacingCooldown
                currentLandmark = nil
            end,
            tooltip = "paint (lmb: land / rmb: water)", bPath = "sprites/paint_brush_icon.png"
        }
    )

    UIM.addButton(
        "settings",
        {
            x = UL[1] + 65, y = UL[2], w = 50, h = 50, bColor = {0.25, 0.25, 0.25, 1},
            onclick = function()
                UIM.toggleGroup("settings")
            end,
            tooltip = "settings panel", bPath = "sprites/settings_icon.png"
        }
    )

    UIM.addButton(
        "remove_landmark",
        {
            x = UL[1] + 65, y = UL[2] + 55, w = 50, h = 50, bColor = {0.25, 0.25, 0.25, 1},
            onclick = function(btn)
                removingLandmark = true
                paintingHexagons = false
                placingLandmarks = false

                UIM.getButton("paint").toggled = not paintingHexagons
                UIM.getDropDown("landmarks").is_open = false
                UIM.getSlider("scale_lm").interactive = false

                currentLandmark = nil
            end,
            tooltip = "remove landmark (lmb: single / rmb: all)", bPath = "sprites/remove_landmark_icon.png"
        }
    )

    UIM.addButton(
        "export",
        {
            x = UR[1] - 60, y = UT[2] + 5, w = 50, h = 50, bColor = {0.25, 0.25, 0.25, 1},
            onclick = function()
                exportMap()
            end,
            tooltip = "export", bPath = "sprites/export_icon.png"
        }
    )

    -- DD: x, y, w, h, bColor, hpad, vpad, extW, extH, content, onclick, tooltip, bPath

    UIM.addDropDown(
        "landmarks",
        { 
            x = UL[1] + 10, y = UL[2] + 55, w = 50, h = 50, bColor = {0.25, 0.25, 0.25, 1}, hpad = 5, vpad = 5, extW = 155, extH = 350,
            onclick = function(dd)
                placingLandmarks = dd.is_open
                paintingHexagons = not dd.is_open

                UIM.getButton("paint").toggled = not paintingHexagons
                UIM.getSlider("scale_lm").interactive = placingLandmarks

                removingLandmark = false
                currentLandmark = nil
            end,
            tooltip = "open landmark menu", bPath = "sprites/add_landmark_icon.png"
        }
    )

    -- Slider: x, y, fOffsetX, fOffsetY, bWidth, bHeight, bCol, fWidth, fHeight, fCol, dir, wholeN, minVal, maxVal, v, onvalchanged, interactive, hRadius
    UIM.addSlider(
        "scale_lm",
        {
            x = UL[1] + 10, y = UL[2] + 485, fOffsetX = 5, fOffsetY = 5, bWidth = 155, bHeight = 40, bCol = {0.25, 0.25, 0.25},
            fWidth = 145, fHeight = 30, fCol = {0.7, 0.7, 0.7},
            minVal = 0.5, maxVal = 2, v = 1,
            onvalchanged = function(sli)
                landmarkScale = sli.value
            end
        }
    )

    --Input Field: x, y, w, h, bColor, border, borColor, borThickness, pad, text, isNumeric, decimals,
    UIM.addInputField(
        "rowHexes",
        {
            group = "settings",
            x = UL[1] + UI_LEFT_SAFEZONE + 10, y = UL[2] + 80, w = 150, h = 50, bColor = {0.25, 0.25, 0.25}, border = true,
            borColor = {1,1,1}, borThickness = 1, pad = 4, isNumeric = true,
            ontxtfunc = function(inpf)
                local val = inpf:getText()
                rowHexes = val
                gen.generate(CANVAS_SIZE, rowHexes, noiseAmplitude, noiseScale, seed, true)
            end,
            basetxt = "hexes per row: ", text = tostring(rowHexes)
        }
    )

    UIM.addInputField(
        "noiseAmplitude",
        {
            group = "settings",
            x = UL[1] + UI_LEFT_SAFEZONE + 10, y = UL[2] + 140, w = 150, h = 50, bColor = {0.25, 0.25, 0.25}, border = true,
            borColor = {1,1,1}, borThickness = 1, pad = 4, isNumeric = true,
            ontxtfunc = function(inpf)
                local val = inpf:getText()
                noiseAmplitude = val
                gen.generate(CANVAS_SIZE, rowHexes, noiseAmplitude, noiseScale, seed)
            end,
            basetxt = "noise amplitude: ", text = tostring(noiseAmplitude)
        }
    )

    UIM.addInputField(
        "noiseScale",
        {
            group = "settings",
            x = UL[1] + UI_LEFT_SAFEZONE + 10, y = UL[2] + 200, w = 150, h = 50, bColor = {0.25, 0.25, 0.25}, border = true,
            borColor = {1,1,1}, borThickness = 1, pad = 4, isNumeric = true,
            ontxtfunc = function(inpf)
                local val = inpf:getText()
                noiseScale = val
                gen.generate(CANVAS_SIZE, rowHexes, noiseAmplitude, noiseScale, seed)
            end,
            basetxt = "noise scale: ", text = tostring(noiseScale)
        }
    )
end

function updateLandmarkButtons()
    local options = {}
    for name, _ in pairs(landmark_sprites) do
        table.insert(options, name)
    end
    
    --maybe in future if there will be more drawings i coudl add more sorting options
    table.sort(options)
    
    --Buttons: x, y, w, h, bColor, onclick, tooltip, bPath
    for i, name in ipairs(options) do
        UIM.addDropDownButton(
            "landmarks",
            {
                x = 0, y = 0, w = 45, h = 45, bColor = {0.8, 0.8, 0.8, 1},
                onclick = function()
                    currentLandmark = name
                end,
                bPath = landmark_sprites[name].path
            }
        )
    end
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

    local img = landmark_sprites[currentLandmark].img
    local cmx, cmy = getCanvasMousePosition()
    local ox, oy = img:getWidth()/2, img:getHeight()/2
    love.graphics.draw(img, cmx, cmy, 0, landmarkScale, landmarkScale, ox, oy)
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

    local paintingHexagon_TXT = "painting: " .. tostring(paintingHexagons)
    local placingLandmarks_TXT = ", placing LM: " .. tostring(placingLandmarks)
    local removingLandmark_TXT = ", removing LM: " .. tostring(removingLandmark)

    local totalTXT = paintingHexagon_TXT .. placingLandmarks_TXT .. removingLandmark_TXT

    love.graphics.print(totalTXT, UT[1] + 10, UT[2] + 10)
    love.graphics.print("tot lm: " .. #landmarks, UT[1] + 20 + love.graphics.getFont():getWidth(totalTXT), UT[2] + 10)
    love.graphics.print("f1: toggle center vis, f2: toggle edge vis, f3: toggle fill vis, f4: toggle vertices, f5: toggle terrain, f6: toggle textures", UT[1] + 10, UT[2] + 30)
    
    love.graphics.print("zoom: " .. zoomLevel * 100 .. "%", UL[1] + UI_LEFT_SAFEZONE + 10, UI_TOP_SAFEZONE + 10)

    local lmscaleTXT = math.round(10000*landmarkScale)/100 .. "%"
    love.graphics.print("landmark scale: " .. lmscaleTXT, UL[1] + 10, UL[2] + 465)

    local expBtn = UIM.getButton("export")
    if expBtn then
        expBtn.x = UR[1] - 60
    end

    UIM.draw(screenMouseX, screenMouseY)
end

-- modifing map

function modifyMap()
    tryPaintingHexagon()
    tryPlacingLandmark()
    tryRemovingLandmark()
end

function tryPaintingHexagon()
    if not paintingHexagons then return end

    local cmx, cmy = getCanvasMousePosition()

    if cmx < -gen.radius or cmx > CANVAS_SIZE + gen.radius or cmy < -gen.radius or cmy > CANVAS_SIZE + gen.radius then return end 

    local q, r = gen.worldToHex(cmx, cmy)
    local hex = gen.getHex(q, r)

    if hex == nil then return end

    hex.mouseover = true

    if not lmbDown and not rmbDown then return end

    if UIM.checkOnUI(screenMouseX, screenMouseY, lmbDown) then return end

    if lmbDown then hex.terrain = "land" end
    if rmbDown then hex.terrain = "water" end

    if lmbDown or rmbDown then gen.updateShoreline() end
end

function tryPlacingLandmark()
    if not placingLandmarks then return end
    if not lmbDown then return end
    if currentLandmark == nil or landmark_sprites[currentLandmark] == nil then return end
    if lmTimer > 0 then return end

    if UIM.checkOnUI(screenMouseX, screenMouseY, lmbDown) then return end

    local cmx, cmy = getCanvasMousePosition()

    if cmx < 0 or cmx > CANVAS_SIZE or cmy < 0 or cmy > CANVAS_SIZE then return end 

    local img = landmark_sprites[currentLandmark].img
    local ox, oy = img:getWidth()/2, img:getHeight()/2
    table.insert(landmarks, {img, cmx, cmy, landmarkScale, ox, oy})
    lmTimer = landmarkPlacingCooldown
end

function tryRemovingLandmark()
    if not removingLandmark then return end
    if not lmbDown and not rmbDown then return end

    if UIM.checkOnUI(screenMouseX, screenMouseY, lmbDown) then return end

    if lmbDown then
        local cmx, cmy = getCanvasMousePosition()

        for i = #landmarks, 1, -1 do
            local lm = landmarks[i]
            local x = lm[2] - lm[5] * lm[4] --x - ox*scale
            local y = lm[3] - lm[6] * lm[4]
            local w, h = lm[1]:getWidth() * lm[4], lm[1]:getHeight() * lm[4] --img_w * scale

            if cmx >= x and cmx <= x + w and cmy >= y and cmy <= y + h then
                table.remove(landmarks, i)
                return
            end
        end
    elseif rmbDown then
        landmarks = {}
    end
end

-- file managment

local function createSaveFile(filepath, data)
    local dir = filepath:match("(.+)/[^/]+$")
    if dir then
        love.filesystem.createDirectory(dir)
    end
    
    local jsonString = json.encode(data)

    local success, message = love.filesystem.write(filepath, jsonString)
    
    if success then
        print("file save to: " .. filepath)
    else
        print("ERROR: " .. tostring(message))
    end
end

local function loadSaveFile(filepath)
    if not love.filesystem.getInfo(filepath) then
        print("ERROR: File non trovato -> " .. filepath)
        return nil
    end

    local contents, size = love.filesystem.read(filepath)
    if not contents then
        print("ERROR: Impossibile leggere il file -> " .. filepath)
        return nil
    end

    local success, data = pcall(json.decode, contents)
    if success then
        return data
    else
        print("ERROR: Parsing JSON fallito per -> " .. filepath)
        return nil
    end
end

local function openFileExplorer(fullURL, dirName)
    success = love.system.openURL(fullURL)
    if not success then
        local dir = love.filesystem.getInfo(dirName)
        if dir == nil then
            print("DIR NOT FOUND, creating new one")
            love.filesystem.createDirectory(dirName)
        elseif dir.type ~= "directory" then
            print("ERROR " .. fullURL .. " IS NOT A DIRECTORY")
        end
    end
end

-- all settings: seed, rowHexes, amplitude, scale

function saveSettings(forcedName)
    local settingsData = 
    {
        seed = seed,
        rowHexes = rowHexes,
        noiseAmplitude = noiseAmplitude,
        noiseScale = noiseScale
    }

    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = forcedName or "setting_" .. timestamp

    createSaveFile("Settings/" .. filename  .. ".json", settingsData)
end

-- all data: debug_flags, settings, all landmarks (image + scale)

function saveMap(forcedName)
    local mapData =
    {
        map = gen.getMap(),
        debugFlags = gen.debugFlags,
        landmarks = landmarks
    }

    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = forcedName or "save_" .. timestamp

    createSaveFile("MapSaves/" .. filename  .. ".json", mapData)
end

function loadSettings(filename)
    local latest = filename:sub(6) == "latest"

    local filepath = "Settings/" .. filename
    if not filepath:match("%.json$") then
        filepath = filepath .. ".json"
    end

    local settingsData = loadSaveFile(filepath)
    if latest and settingsData == nil then
        gen.generate(CANVAS_SIZE, rowHexes, noiseAmplitude, noiseScale, seed)
        return
    end

    if settingsData then
        local function newSeed() love.math.setRandomSeed(os.time()) return love.math.getRandomSeed() end
        seed = settingsData.seed or newSeed()

        rowHexes = settingsData.rowHexes or rowHexes
        noiseAmplitude = settingsData.noiseAmplitude or noiseAmplitude
        noiseScale = settingsData.noiseScale or noiseScale

        local rowHexesField = UIM.getField("rowHexes")
        if rowHexesField then rowHexesField:setText(tostring(rowHexes)) end

        local noiseAmpField = UIM.getField("noiseAmplitude")
        if noiseAmpField then noiseAmpField:setText(tostring(noiseAmplitude)) end

        local noiseScaleField = UIM.getField("noiseScale")
        if noiseScaleField then noiseScaleField:setText(tostring(noiseScale)) end

        gen.generate(CANVAS_SIZE, rowHexes, noiseAmplitude, noiseScale, seed)
        print("Settings caricati con successo da: " .. filepath)
    end
end

function uploadLandmarks(openOnly)
    openOnly = openOnly or false
    if openOnly == true then
        openFileExplorer(LANDMARKS_DIR, "Landmarks")
        return
    else
        landmark_sprites = 
        {
            test_mountain = {img = love.graphics.newImage("sprites/landmarks/mountain.png"), path = "sprites/landmarks/mountain.png"},
            test_skull = {img = love.graphics.newImage("sprites/landmarks/skull.png"), path = "sprites/landmarks/skull.png"},
            test_tower = {img = love.graphics.newImage("sprites/landmarks/tower.png"), path = "sprites/landmarks/tower.png"}
        }

        local allFiles = love.filesystem.getDirectoryItems("Landmarks")
        for i, file in ipairs(allFiles) do
            local extension = file:match("^.+(%..+)$")
            if extension and extension:lower() == ".png" then
                local name = file:match("(.+)%..+$")
                local _path = "Landmarks/" .. file
                landmark_sprites[name] = {img = love.graphics.newImage(_path), path = _path}
            end
        end
    end

    updateLandmarkButtons()
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