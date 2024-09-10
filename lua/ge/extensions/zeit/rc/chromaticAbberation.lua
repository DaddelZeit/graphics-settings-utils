-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local delayLoad = false
local settings2 = {}

local function createPFX()
    if not ChromaticAbberationPostFX or not scenetree.ChromaticAbberationFX then
        rerequire("client/postFx/chromaticAbberation")
    end

    return ChromaticAbberationPostFX ~= nil
end

local function loadSettingsActual(data)
    if ChromaticAbberationPostFX then
        if not data then
            ChromaticAbberationPostFX.setEnabled(false)
        else
            ChromaticAbberationPostFX.setEnabled(true)
            ChromaticAbberationPostFX.setShaderConsts(data.dist or 0, data.cube or 0, data.color or {0,0,0})
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
M.onUpdate = onUpdate

return M