-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

M.ratios = {
    {4/3, "4/3"},
    {3/2, "3/2"},
    {16/9, "16/9"},
    {16/10, "16/10"},
    {1.85/1, "1.85/1"},
    {2.35/1, "2.35/1"},
    {2.39/1, "2.39/1"},
    {2.76/1, "2.76/1"},
    {21/9, "21/9"},
}

local settings
local function createPFX()
    if not LetterboxPostFX or not scenetree.LetterboxFx then
        rerequire("client/postFx/letterboxZeit")
    end

    return scenetree.LetterboxFx ~= nil
end

local function loadSettingsActual()
    if LetterboxPostFX then
        if not settings then
            LetterboxPostFX.setEnabled(false)
        else
            LetterboxPostFX.setEnabled(true)

            if settings.heightOverride and M.ratios[settings.heightOverride] then
                local videoMode = GFXDevice.getVideoMode()
                local wantedRatio = M.ratios[settings.heightOverride][1]

                local wantedWidth, wantedHeight
                if wantedRatio < 1 then
                    wantedWidth = math.min(videoMode.height * wantedRatio, videoMode.width)
                    wantedHeight = wantedWidth / wantedRatio
                else
                    wantedHeight = math.min(videoMode.width / wantedRatio, videoMode.height)
                    wantedWidth = wantedHeight * wantedRatio
                end

                if wantedHeight < videoMode.height then
                    settings.height = (1-(wantedHeight/videoMode.height))*0.5
                    settings.width = 0
                else
                    settings.height = 0
                    settings.width = (1-(wantedWidth/videoMode.width))*0.5
                end
            end
            LetterboxPostFX.setShaderConsts(settings.height or 0, 1-(settings.height or 0), settings.width or 0, 1-(settings.width or 0), settings.color or {0,0,0})
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

local function getAndSaveSettings(height, width, color, heightOverride)
    local data = {
        height = height ~= 0 and height or nil,
        width = width ~= 0 and width or nil,
        color = (color[1] ~= 0 or color[2] ~= 0 or color[3] ~= 0) and color or nil,
        heightOverride = heightOverride ~= 0 and heightOverride or nil
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
M.onUpdate = nil

return M