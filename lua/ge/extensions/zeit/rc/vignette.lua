-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings
local function createPFX()
    if not VignettePostFX or not scenetree.VignetteFx then
        rerequire("client/postFx/vignetteZeit")
    end

    return scenetree.VignetteFx ~= nil
end

local function loadSettingsActual()
    if VignettePostFX then
        if not settings then
            VignettePostFX.setEnabled(false)
        else
            VignettePostFX.setEnabled(true)
            VignettePostFX.setShaderConsts(settings.vmax or 0, settings.vmin or 0, settings.color or {0,0,0})
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
M.onUpdate = nil

return M