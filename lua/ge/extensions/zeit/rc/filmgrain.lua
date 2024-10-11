-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings
local function createPFX()
    if not FilmGrainPostFX or not scenetree.FilmGrainFx then
        rerequire("client/postFx/filmGrain")
    end

    return scenetree.FilmGrainFx ~= nil
end

local function loadSettingsActual()
    if FilmGrainPostFX then
        if not settings then
            FilmGrainPostFX.setEnabled(false)
        else
            FilmGrainPostFX.setEnabled(true)
            FilmGrainPostFX.setShaderConsts(settings.intensity or 0.5, settings.variance or 0.4, --[[settings.mean or]] 0.5, settings.signalToNoiseRatio or 6)
        end
    end
end

local function onUpdate()
    if createPFX() then
        loadSettingsActual()
        M.onUpdate = nil
    end
end

local function loadSettings(settings2)
    if worldReadyState < 1 then return end
    settings = settings2
    if createPFX() then
        loadSettingsActual()
    else
        M.onUpdate = onUpdate
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
M.onUpdate = nil

return M