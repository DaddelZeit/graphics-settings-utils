-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local im = ui_imgui

local function getInterpolation(point0, point1, x)
    local res = {}
    local col0 = point0.rgb
    local col1 = point1.rgb

    local xRatio = linearScale(x, point0.x, point1.x, 0, 1)
    for channel = 1, 3 do
        res[channel] = (col0[channel] * (1 - xRatio) + col1[channel] * xRatio)%256
    end
    return res
end

local function export(filepath, points)
    -- x value matched to rgb values
    -- round() each index before use
    points = points or {
        {
            x = 0,
            rgb = {0,0,0}
        },
        {
            x = 256,
            rgb = {255,255,255}
        }
    }

    local resBitmap = GBitmap()
    resBitmap:init(256, 1)

    if points[1].x ~= 0 then
        local tempPoint0 = deepcopy(points[1])
        tempPoint0.x = 0
        table.insert(points, 1, tempPoint0)
    end

    if points[#points].x ~= 256 then
        local tempPoint1 = deepcopy(points[#points])
        tempPoint1.x = 256
        table.insert(points, #points, tempPoint1)
    end

    for i = 1, #points-1 do
        local point0 = points[i]
        local point1 = points[i+1]

        for x = point0.x, point1.x do
            local res = getInterpolation(point0, point1, guardZero(x))
            resBitmap:setColor(x-1, 0, ColorI(res[1], res[2], res[3], 1))
        end
    end

    resBitmap:saveFile(filepath)
end

local function createPoint(x, rgb)
    -- This color thing will probably need a lot of cleanup
    rgb = rgb or {0, 0, 0}
    return {
        x = clamp(round(x or 0), 0, 256),
        rgb = {rgb[1]*255, rgb[2]*255, rgb[3]*255},
        color = ffi.new("float[3]", rgb),
        u32 = im.GetColorU322(im.ImVec4(rgb[1], rgb[2], rgb[3], 1))
    }
end

local function save(filepath, points)
    local saveTbl = {}
    for i = 1, #points do
        local point = points[i]

        local newPoint = {
            x = point.x,
            rgb = {point.color[0], point.color[1], point.color[2]}
        }

        saveTbl[i] = newPoint
    end
    jsonWriteFile(filepath, saveTbl, true)
end

local function load(filepath)
    local filename = filepath:match("^.+/(.-)%.")
    local saveTbl = jsonReadFile(filepath)
    local ret = {
        createPoint(0, {0, 0, 0}),
        createPoint(256, {1, 1, 1}),
    }

    if saveTbl then
        for k,v in ipairs(saveTbl) do
            ret[k] = createPoint(v.x, v.rgb)
        end
    end

    return ret, filename
end

M.createPoint = createPoint
M.getInterpolation = getInterpolation
M.export = export
M.save = save
M.load = load

return M