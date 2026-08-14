local utils = {}

function math.round(x)
    return x >= 0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function math.lerp(a, b, t)
    return a + (b - a)*t
end

function math.ilerp(a, b, t)
    return (t - a)/(b - a)
end

function math.clamp(a, b, t)
    if a > b then return nil end
    return t > b and b or t < a and a or t
end

function math.clamp01(t)
    return math.clamp(0, 1, t)
end

--hexagonal things

function utils.hexDistance(q1, r1, q2, r2)
    local dq = q1 - q2
    local dr = r1 - r2
    return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

function utils.hexRound(q, r)
    local s = -q - r
    local rx = math.floor(math.round(q))
    local ry = math.floor(math.round(r))
    local rz = math.floor(math.round(s))

    local q_diff = math.abs(rx - q)
    local r_diff = math.abs(ry - r)
    local s_diff = math.abs(rz - s)

    if q_diff > r_diff and q_diff > s_diff then
        rx = -ry - rz
    elseif r_diff > s_diff then
        ry = -rx - rz
    end

    return rx, ry
end

utils.round = math.round
utils.lerp = math.lerp
utils.ilerp = math.ilerp
utils.clamp = math.clamp
utils.clamp01 = math.clamp01

return utils