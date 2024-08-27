-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not FilmGrainPostFX or not scenetree.FilmGrainFx then
        rerequire("client/postFx/filmGrain")
    end

    return FilmGrainPostFX ~= nil
end

local function loadSettingsActual(data)
    if FilmGrainPostFX then
        if not data then
            FilmGrainPostFX.setEnabled(false)
        else
            FilmGrainPostFX.setEnabled(true)
            FilmGrainPostFX.setShaderConsts(data.intensity or 0.5, data.variance or 0.4, --[[data.mean or]] 0.5, data.signalToNoiseRatio or 6)
        end
    end
end

local function loadSettings(settings)
    if worldReadyState < 1 then return end
    settings2 = settings
    delayLoad = createPFX()
end

local function onUpdate()
    if delayLoad then
        delayLoad = false
        loadSettingsActual(settings2)
    end
end

local function getAndSaveSettings(intensity, variance, mean, signalToNoiseRatio)
    local data = {
        intensity = intensity ~= 0.5 and intensity or nil,
        variance = variance ~= 0.4 and variance or nil,
        --mean = mean ~= 0.5 and mean or nil,
        signalToNoiseRatio = signalToNoiseRatio ~= 6 and signalToNoiseRatio or nil,
    }

    zeit_rcMain.updateSettings("filmgrain", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("filmgrain", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M