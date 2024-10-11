-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local origValues
M.origValues = {}

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
local settings = {}
M.settings = {}

local function getAndSaveSettings()
    local obj = scenetree.PostEffectCombinePassObject
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

local function saveSetting(key, value)
    local obj = scenetree.PostEffectCombinePassObject

    if obj and settings then
        settings[key] = value

        zeit_rcMain.updateSettings("rendercomponents", settings)
    end
end

local function loadSettings(_settings)
    local obj = scenetree.PostEffectCombinePassObject
    local bloomobj = scenetree.PostEffectBloomObject

    settings = _settings or {}
    M.settings = settings
    if settings.colorCorrectionRampPath and not FS:fileExists(settings.colorCorrectionRampPath) then
        settings.colorCorrectionRampPath = ""
    end
    if obj and bloomobj then
        if not origValues then
            origValues = {}
            for k in pairs(fields) do
                origValues[k] = obj:getField(k, 0)
            end
            origValues.threshHold = bloomobj.threshHold
            origValues.knee = bloomobj.knee

            M.origValues = origValues
        end

        for k in pairs(fields) do
            if settings[k] then
                obj:setField(k, 0, settings[k])
            elseif origValues[k] then
                obj:setField(k, 0, origValues[k])
            end
        end

        bloomobj.threshHold = settings.threshHold or origValues.threshHold or bloomobj.threshHold
        bloomobj.knee = settings.knee or origValues.knee or bloomobj.knee
    end
end

local function onExtensionUnloaded()
    local obj = scenetree.PostEffectCombinePassObject
    local bloomobj = scenetree.PostEffectBloomObject

    if obj and bloomobj and origValues then
        for k, v in pairs(origValues) do
            obj:setField(k, 0, v)
        end

        bloomobj.threshHold = origValues.threshHold or bloomobj.threshHold
        bloomobj.knee = origValues.knee or bloomobj.knee
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.saveSetting = saveSetting
M.loadSettings = loadSettings
M.onExtensionUnloaded = onExtensionUnloaded

return M