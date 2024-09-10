-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not LetterboxPostFX or not scenetree.LetterboxFx then
        rerequire("client/postFx/letterboxZeit")
    end

    return LetterboxPostFX ~= nil
end

local function loadSettingsActual(data)
    if LetterboxPostFX then
        if not data then
            LetterboxPostFX.setEnabled(false)
        else
            LetterboxPostFX.setEnabled(true)
            LetterboxPostFX.setShaderConsts(data.height or 0, 1-(data.height or 0), data.color or {0,0,0})
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

local function getAndSaveSettings(height, color)
    local data = {
        height = height ~= 0 and height or nil,
        color = (color[1] ~= 0 or color[2] ~= 0 or color[3] ~= 0) and color or nil
    }

    zeit_rcMain.updateSettings("letterbox", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("letterbox", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M