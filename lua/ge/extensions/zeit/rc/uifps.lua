-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local function loadSettings(settings)
    if settings and scenetree.maincef then
        scenetree.maincef:setMaxFPSLimit(tonumber(settings.fps))
    end
end

local function getAndSaveSettings(fps)
    local data = {
        fps = fps
    }

    zeit_rcMain.updateSettings("uifps", data)
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings

return M