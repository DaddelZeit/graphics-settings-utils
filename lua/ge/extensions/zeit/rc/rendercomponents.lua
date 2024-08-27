-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local origValues = {}
local fields = {
    ["enabled"] = 0,
    ["maxAdaptedLum"] = 0,
    ["colorCorrectionStrength"] = 0,
    ["middleGray"] = 0,
    ["blueShiftLumVal"] = 0,
    ["blueShiftColor"] = 0,
    ["enableBlueShift"] = 0,
    ["HSL"] = 0,
    ["bloomScale"] = 0,
    ["colorCorrectionRampPath"] = 0,
    ["oneOverGamma"] = 0,
}

local function getAndSaveSettings()
    local obj = scenetree.findObject("PostEffectCombinePassObject")
    local data = {}

    if obj and fields then
        for k, v in pairs(fields) do
            v = obj:getField(k, 0)
            data[k] = v
        end
    end

    local bloomobj = scenetree.PostEffectBloomObject
    if bloomobj then
        data.threshHold = bloomobj.threshHold
        data.knee = bloomobj.knee
    end

    zeit_rcMain.updateSettings("rendercomponents", data)
end

local function loadSettings(settings)
    local obj = scenetree.findObject("PostEffectCombinePassObject")
    local bloomobj = scenetree.PostEffectBloomObject
    if settings and obj then
        --origValues = lpack.decode(readFile("/temp/zeit/rchdrcache")) or {}
        --for k in pairs(fields) do
        --    if origValues[k] then
        --        obj:setField(k, 0, origValues[k])
        --    end
        --end

        for k in pairs(fields) do
            if settings[k] then
                obj:setField(k, 0, settings[k])
            end
        end

        if bloomobj and settings.threshHold then
            bloomobj.threshHold = settings.threshHold
        end
        if bloomobj and settings.knee then
            bloomobj.knee = settings.knee
        end
    end
end

--[[
local function onExtensionLoaded()
    local obj = scenetree.findObject("PostEffectCombinePassObject")
    local bloomobj = scenetree.PostEffectBloomObject
    if not FS:fileExists("/temp/zeit/rchdrcache") then
        if obj then
            for k in pairs(fields) do
                origValues[k] = obj:getField(k, 0)
            end

            if bloomobj then
                origValues.threshHold = bloomobj.threshHold
                origValues.knee = bloomobj.knee
            end
            dump("hdr save", origValues)

            writeFile("/temp/zeit/rchdrcache", lpack.encode(origValues))
        end
    end
end

local function onExit()
    log("I", "", "clearing hdr cache...")
    FS:removeFile("/temp/zeit/rchdrcache")
end
]]

-- public interface (IMPORTANT)
--M.onExtensionLoaded = onExtensionLoaded
--M.onExit = onExit
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings

return M