-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not ContrastSaturationPostFX or not scenetree.ContrastSaturationFx then
        rerequire("client/postFx/contrastSaturationZeit")
    end

    return ContrastSaturationPostFX ~= nil
end

local function loadSettingsActual(data)
    if ContrastSaturationPostFX then
        if not data then
            ContrastSaturationPostFX.setEnabled(false)
        else
            ContrastSaturationPostFX.setEnabled(true)
            ContrastSaturationPostFX.setShaderConsts(data.contrast or 1, data.saturation or 1)
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

local function getAndSaveSettings(contrast, saturation)
    local data = {
        contrast = contrast ~= 1 and contrast or nil,
        saturation = saturation ~= 1 and saturation or nil
    }

    zeit_rcMain.updateSettings("contrastsaturation", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("contrastsaturation", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M