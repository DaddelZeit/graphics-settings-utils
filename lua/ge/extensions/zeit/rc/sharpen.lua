-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings
local function createPFX()
    if not SharpenPostFX or not scenetree.SharpenFx then
        rerequire("client/postFx/sharpenZeit")
    end

    return scenetree.SharpenFx ~= nil
end

local function loadSettingsActual()
    if SharpenPostFX then
        if not settings then
            SharpenPostFX.setEnabled(false)
        else
            SharpenPostFX.setEnabled(true)
            SharpenPostFX.setShaderConsts(settings.sharpness or 0)
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

local function getAndSaveSettings(sharpness)
    local data = {
        sharpness = sharpness ~= 0 and sharpness or nil,
    }

    zeit_rcMain.updateSettings("sharpen", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("sharpen", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = nil

return M