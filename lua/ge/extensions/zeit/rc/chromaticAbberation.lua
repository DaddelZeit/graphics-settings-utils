-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings
local function createPFX()
    if not ChromaticAbberationPostFX or not scenetree.ChromaticAbberationFX then
        rerequire("client/postFx/chromaticAbberation")
    end

    return scenetree.ChromaticAbberationFX ~= nil
end

local function loadSettingsActual()
    if ChromaticAbberationPostFX then
        if not settings then
            ChromaticAbberationPostFX.setEnabled(false)
        else
            ChromaticAbberationPostFX.setEnabled(true)
            ChromaticAbberationPostFX.setShaderConsts(settings.dist or 0, settings.cube or 0, settings.color or {0,0,0})
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

local function getAndSaveSettings(dist, cube, color)
    local data = {
        dist = dist ~= 0 and dist or nil,
        cube = cube ~= 0 and cube or nil,
        color = (color[1] ~= 0 or color[2] ~= 0 or color[3] ~= 0) and color or nil,
    }

    zeit_rcMain.updateSettings("chromaticAbberation", data)
end

local function setEnabled(bool)
    zeit_rcMain.updateSettings("chromaticAbberation", bool and {} or nil)
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = nil

return M