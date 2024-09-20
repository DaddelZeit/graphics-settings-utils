-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not ContrastSaturationPostFX then
        local pfx = require("client/postFx/contrastSaturationZeit")
    end

    return ContrastSaturationPostFX ~= nil
end

local function loadSettingsActual(data)
    if data and ContrastSaturationPostFX then
        ContrastSaturationPostFX.setShaderConsts(data.contrast, data.saturation)
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

local function getAndSaveSettings(contrast, saturation)
    local data = {
        contrast = contrast,
        saturation = saturation
    }

    zeit_rcMain.updateSettings("contrastsaturation", data)
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M