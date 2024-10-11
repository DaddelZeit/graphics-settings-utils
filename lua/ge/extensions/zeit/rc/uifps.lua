-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local function loadSettings(settings)
    settings = settings or {}
    if scenetree.maincef then
        scenetree.maincef:setMaxFPSLimit(tonumber(settings.fps or 30))
    end
end

local function getAndSaveSettings(fps)
    local data = {
        fps = fps
    }

    if data ~= 30 then
        zeit_rcMain.updateSettings("uifps", data)
    else
        zeit_rcMain.updateSettings("uifps", nil)
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings

return M