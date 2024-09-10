-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not VignettePostFX or not scenetree.VignetteFx then
        rerequire("client/postFx/vignetteZeit")
    end

    return VignettePostFX ~= nil
end

local function loadSettingsActual(data)
    if VignettePostFX then
        if not data then
            VignettePostFX.setEnabled(false)
        else
            VignettePostFX.setEnabled(true)
            VignettePostFX.setShaderConsts(data.vmax or 0, data.vmin or 0, data.color or {0,0,0})
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

local function getAndSaveSettings(vmax, vmin, color)
    local data = {
        vmax = vmax ~= 0 and vmax or nil,
        vmin = vmin ~= 0 and vmin or nil,
        color = (color[1] ~= 0 or color[2] ~= 0 or color[3] ~= 0) and color or nil
    }

    zeit_rcMain.updateSettings("vignette", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("vignette", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M