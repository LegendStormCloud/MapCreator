local utils = require "utils"

local sqrt3 = math.sqrt(3)

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

local gen = {}

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

local CANVAS_SIZE

local map = {}

-- gen function // love function

function gen.load(cs, rowHexes, amp, sc, seed)
    gen.generate(cs, rowHexes, amp, sc, seed)
end

function gen.generate(cs, rowHexes, amp, sc, seed, resetMap)
    if rowHexes == 0 then return end
    if seed then love.math.setRandomSeed(seed) end

    resetMap = resetMap or true
    local offX, offY = love.math.random(0, 10000), love.math.random(0, 10000)

    --map reset
    if resetMap then
        map = {}

        CANVAS_SIZE = cs

        rowHexes = rowHexes or 25
        gen.radius = cs / (sqrt3 * rowHexes)
        local hexWidth = gen.radius * sqrt3
        local totRows = math.ceil(cs/(1.5*gen.radius))

        --optional but 1 or 2 should decrese the probability of having black corners
        local pad = 1
        local ox, oy = 0, 0

        --map creation, no noise
        for row = -pad, totRows + pad do
            for col = -pad, rowHexes + pad do
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
    end

    --noise application, noise based on position so that coincident vertices are warped the same way
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

-- callable gen functions

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

-- shore calculations

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
                --local waterRing2 = hasWaterWithinDistance(q, r, 2)

                if waterRing1 then --and waterRing2 then
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
    local numVertices = 6

    for i = 1, numVertices do
        local initialIdx = (i - 1) * 2 + 1 
        local x1, y1 = hex.vertices[initialIdx], hex.vertices[initialIdx + 1]

        --next index respecting initialIdx from 2, 2 to 1, 1
        local nextIdx = (i % numVertices) * 2 + 1 
        local x2, y2 = hex.vertices[nextIdx], hex.vertices[nextIdx + 1]

        --middle point of the two vertices
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2

        --normal vector (from center to middle and normialized)
        local nx, ny = mx - hex.center.x, my - hex.center.y
        local len = math.sqrt(nx * nx + ny * ny)
        if len > 0 then
            nx, ny = nx / len, ny / len
        end

        --since di hexes are warped we test a point a little less disntant than half a radius 
                    --(it's a positive distance because the vector is positive going outside of the center)
        local testDist = gen.radius * 0.35
        local testX = mx + nx * testDist
        local testY = my + ny * testDist

        local tq, tr = gen.worldToHex(testX, testY)
        local neighbor = gen.getHex(tq, tr)

        -- if it is water or if it is outside of the map we call it a "water edge"
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

return gen