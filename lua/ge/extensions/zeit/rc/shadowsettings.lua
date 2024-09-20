-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local origValues = {}
local fields = {
    ["attenuationRatio"] = 0,
    ["shadowType"] = 0,
    ["cookie"] = 0,
    ["texSize"] = 0,
    ["overDarkFactor"] = 0,
    ["shadowDistance"] = 0,
    ["shadowSoftness"] = 0,
    ["numSplits"] = 0,
    ["logWeight"] = 0,
    ["fadeStartDistance"] = 0,
}

local function getAndSaveSettings()
    local data = {}

    if scenetree.sunsky and fields then
        for k, v in pairs(fields) do
            v = scenetree.sunsky:getField(k, 0)
            data[k] = v
        end
        origValues = data
    end

    zeit_rcMain.updateSettings("shadowsettings", data)
end

local function loadSettings(settings)
    if settings and scenetree.sunsky then
        for k, v in pairs(fields) do
            if settings[k] then
                v = settings[k]
                scenetree.sunsky:setField(k, 0, v)
            end
        end

        origValues = settings
    end
end

local function onUpdate()
    if not scenetree.sunsky or not origValues.logWeight then return end
    if scenetree.sunsky:getField("logWeight", 0) ~= origValues.logWeight and not editor.isEditorActive() and not zeit_rcMain.uiActive then
        scenetree.sunsky:setField("logWeight", 0, origValues.logWeight)
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate

return M