-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

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

    data.threshHold = bloomobj.threshHold
    data.knee = bloomobj.knee

    zeit_rcMain.updateSettings("rendercomponents", data)
end

local function loadSettings(settings)
    if settings then
        local obj = scenetree.findObject("PostEffectCombinePassObject")
        if not obj then return end

        for k, v in pairs(fields) do
            if settings[k] then
                v = settings[k]
                obj:setField(k, 0, v)
            end
        end

        local bloomobj = scenetree.PostEffectBloomObject
        if bloomobj and settings.threshHold then
            bloomobj.threshHold = settings.threshHold
        elseif bloomobj and settings.knee then
            bloomobj.knee = settings.knee
        end
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings

return M