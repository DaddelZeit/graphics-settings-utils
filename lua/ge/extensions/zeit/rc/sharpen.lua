-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not SharpenPostFX or not scenetree.SharpenFx then
        rerequire("client/postFx/sharpenZeit")
    end

    return SharpenPostFX ~= nil
end

local function loadSettingsActual(data)
    if SharpenPostFX then
        if not data then
            SharpenPostFX.setEnabled(false)
        else
            SharpenPostFX.setEnabled(true)
            SharpenPostFX.setShaderConsts(data.sharpness or 0)
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
M.onUpdate = onUpdate

return M