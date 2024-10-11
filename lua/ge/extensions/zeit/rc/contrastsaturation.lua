-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings
local function createPFX()
    if not ContrastSaturationPostFX or not scenetree.ContrastSaturationFx then
        rerequire("client/postFx/contrastSaturationZeit")
    end

    return scenetree.ContrastSaturationFx ~= nil
end

local function loadSettingsActual()
    if ContrastSaturationPostFX then
        if not settings then
            ContrastSaturationPostFX.setEnabled(false)
        else
            ContrastSaturationPostFX.setEnabled(true)
            ContrastSaturationPostFX.setShaderConsts(settings.contrast or 1, settings.saturation or 1, settings.vibrance or 0, settings.vibrancebal or {1,1,1})
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

local function getAndSaveSettings(contrast, saturation, vibrance, vibrancebal)
    local data = {
        contrast = contrast ~= 1 and contrast or nil,
        saturation = saturation ~= 1 and saturation or nil,
        vibrance = vibrance ~= 0 and vibrance or nil,
        vibrancebal = (vibrancebal[1] ~= 1 or vibrancebal[2] ~= 1 or vibrancebal[3] ~= 1) and vibrancebal or nil,
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
M.onUpdate = nil

return M