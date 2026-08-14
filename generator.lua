local gen = {}
local utils = require "utils"

local map = {}

local sqrt3 = math.sqrt(3)
local CANVAS_SIZE

gen.radius = 0

gen.debugFlags = {
    pointy_top = true,
    show_centers = false,
    show_edges = true,
    show_fill = true,
    show_vertices = false,
    show_terrain = false,
    use_textures = false
}

local hexDirections = {
    { q =  1, r =  0 }, { q =  1, r = -1 }, { q =  0, r = -1 },
    { q = -1, r =  0 }, { q = -1, r =  1 }, { q =  0, r =  1 }
}

local terrain_colors = {
    land = {0.247, 0.569, 0.263},
    water = {0.118, 0.412, 0.725},
    shore = {0.98 , 0.91 , 0.549}
}

local terrain_textures = {
    land = love.graphics.newImage("sprites/temp_land.png"),
    water = love.graphics.newImage("sprites/temp_water.png"),
    shore = love.graphics.newImage("sprites/temp_shore.png")
}

function gen.load(cs, seed, targetNx, amp, sc)
    gen.generate(cs, seed, targetNx, amp, sc)
end

function gen.generate(cs, seed, targetNx, amp, sc)
    if targetNx == 0 then return end
    
    CANVAS_SIZE = cs
    local offX, offY = love.math.random(0, 10000), love.math.random(0, 10000)

    map = {} -- Resettiamo la mappa

    targetNx = targetNx or 25

    gen.radius = cs / (sqrt3 * targetNx)

    local hexWidth = gen.radius * sqrt3

    local totRows = math.ceil(cs/(1.5*gen.radius))

    local pad = 1

    local ox, oy = 0, 0

    for row = -pad, totRows + pad do
        for col = -pad, targetNx + pad do
            local rowOffset = (math.abs(row) % 2 == 1) and (hexWidth / 2) or 0
            
            local cx = col * hexWidth + rowOffset + ox
            local cy = row * 1.5 * gen.radius + oy

            local q, r = gen.worldToHex(cx, cy)

            local hexVertices = {}
            for i = 1, 6 do
                local angle = math.rad(60 * (i - 1) + (gen.debugFlags["pointy_top"] and 30 or 0))
                local vx = cx + gen.radius * math.cos(angle)
                local vy = cy - gen.radius * math.sin(angle)

                table.insert(hexVertices, vx)
                table.insert(hexVertices, vy)
            end

            if not map[q] then map[q] = {} end
            map[q][r] = {
                q = q,
                r = r,
                center = { x = cx, y = cy },
                vertices = hexVertices,
                landmark = nil,
                terrain = "water",
                mouseover = false
            }
        end
    end

    for q, rowData in pairs(map) do
        for r, hex in pairs(rowData) do
            for i = 1, #hex.vertices, 2 do
                local vx = hex.vertices[i]
                local vy = hex.vertices[i + 1]

                local noX = love.math.noise(vx * sc + offX, vy * sc + offY)
                local noY = love.math.noise(vx * sc + 1000*offX, vy * sc + 1000*offY)

                local dx = (noX * 2 - 1) * amp
                local dy = (noY * 2 - 1) * amp

                hex.vertices[i] = vx + dx
                hex.vertices[i + 1] = vy + dy
            end
        end
    end
end

function gen.getHex(q, r)
    if map[q] then
        return map[q][r]
    end
    return nil
end

function gen.worldToHex(x, y)
    local q = (sqrt3 / 3 * x - 1 / 3 * y) / gen.radius
    local r = (2 / 3 * y) / gen.radius

    return utils.hexRound(q, r)
end

function gen.getMap()
    return map
end

local function hasWaterWithinDistance(q, r, dist)
    for dq = -dist, dist do
        for dr = -dist, dist do
            if utils.hexDistance(0, 0, dq, dr) == dist then
                local hex = gen.getHex(q + dq, r + dr)
                if hex and hex.terrain == "water" then return true end
            end
        end
    end
    return false
end

function gen.updateShoreline()
    local toShore = {}
    
    for q, row in pairs(map) do
        for r, hex in pairs(row) do
            if hex.terrain == "land" or hex.terrain == "shore" then
                local waterRing1 = hasWaterWithinDistance(q, r, 1)
                local waterRing2 = hasWaterWithinDistance(q, r, 2)

                if waterRing1 and waterRing2 then
                    table.insert(toShore, {hex = hex, terrain = "shore"})
                else
                    table.insert(toShore, {hex = hex, terrain = "land"})
                end
            end
        end
    end

    for _, change in ipairs(toShore) do
        change.hex.terrain = change.terrain
    end
end

function gen.getWaterFacingEdges(hex)
    local waterEdges = {}
    local numVertices = #hex.vertices / 2 -- Solitamente 6 vertici (12 coordinate X,Y)

    for i = 1, numVertices do
        -- Vertice A (x1, y1)
        local idx1 = (i - 1) * 2 + 1
        local x1, y1 = hex.vertices[idx1], hex.vertices[idx1 + 1]

        -- Vertice B (x2, y2) -> il vertice successivo (con giro a 1 per l'ultimo lato)
        local nextIdx = (i % numVertices) * 2 + 1
        local x2, y2 = hex.vertices[nextIdx], hex.vertices[nextIdx + 1]

        -- 1. Punto medio del lato attuale
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2

        -- 2. Vettore normale dal centro dell'esagono verso l'esterno di questo lato
        local nx, ny = mx - hex.center.x, my - hex.center.y
        local len = math.sqrt(nx * nx + ny * ny)
        if len > 0 then
            nx, ny = nx / len, ny / len
        end

        -- 3. Campioniamo un punto leggermente fuori dal lato (es. a circa il 40% del raggio)
        local testDist = gen.radius * 0.4
        local testX = mx + nx * testDist
        local testY = my + ny * testDist

        -- 4. Convertiamo il punto in coordinate della mappa
        local tq, tr = gen.worldToHex(testX, testY)
        local neighbor = gen.getHex(tq, tr)

        -- 5. Se il punto esterno cade in acqua (o fuori dai confini), il lato guarda l'acqua!
        if not neighbor or neighbor.terrain == "water" then
            table.insert(waterEdges, {
                x1 = x1, y1 = y1,
                x2 = x2, y2 = y2,
                nx = nx, ny = ny
            })
        end
    end

    return waterEdges
end

function gen.drawMap()
    local show_edges = gen.debugFlags["show_edges"]
    local show_fill = gen.debugFlags["show_fill"]
    local show_vertices = gen.debugFlags["show_vertices"]
    local show_centers = gen.debugFlags["show_centers"]
    local show_terrain = gen.debugFlags["show_terrain"]
    local use_textures = gen.debugFlags["use_textures"]

    for key, img in pairs(terrain_textures) do
        img:setWrap("repeat", "repeat")
    end

    --disegno e colore/texture
    if show_fill then
        for q, row in pairs(map) do
            for r, hex in pairs(row) do
                local col = terrain_colors[hex.terrain] or {1, 0, 1}
                love.graphics.setColor(col)
                love.graphics.polygon("fill", hex.vertices)
            end
        end

        if use_textures then 
            for terrainType, img in pairs(terrain_textures) do
                love.graphics.stencil(function()
                    for q, row in pairs(map) do
                        for r, hex in pairs(row) do
                            if hex.terrain == terrainType then
                                love.graphics.polygon("fill", hex.vertices)
                            end
                        end
                    end
                end, "replace", 1)

                love.graphics.setStencilTest("greater", 0)
                love.graphics.setColor(1, 1, 1, 1)

                local mapQuad = love.graphics.newQuad(0, 0, CANVAS_SIZE, CANVAS_SIZE, img:getDimensions())

                love.graphics.draw(img, mapQuad, 0, 0)
                love.graphics.setStencilTest() -- Disattiva lo stencil
            end
        end
    end

    if show_fill then
        love.graphics.setColor(1, 1, 1, 0.3)
        for q, row in pairs(map) do
            for r, hex in pairs(row) do
                if hex.mouseover then
                    love.graphics.polygon("fill", hex.vertices)
                    hex.mouseover = false
                end
            end
        end
    end

    love.graphics.setLineWidth(3)

    for q, row in pairs(map) do
        for r, hex in pairs(row) do
            if show_edges then
                love.graphics.setColor(1, 0, 0)
                love.graphics.polygon("line", hex.vertices)
            end

            if show_centers then
                love.graphics.setColor(0, 0, 1)
                love.graphics.circle("line", hex.center.x, hex.center.y, gen.radius / 20)
            end

            if show_vertices then
                love.graphics.setColor(0, 0, 1)
                for i = 1, #hex.vertices, 2 do
                    love.graphics.circle("line", hex.vertices[i], hex.vertices[i + 1], gen.radius / 30)
                end
            end

            if show_terrain then
                love.graphics.setColor(1, 0, 0)
                love.graphics.print(hex.terrain:sub(1, 1), hex.center.x - gen.radius/2, hex.center.y - gen.radius/2, 0, 3, 3)
            end
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

return gen