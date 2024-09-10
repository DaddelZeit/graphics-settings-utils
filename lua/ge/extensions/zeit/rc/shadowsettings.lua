-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local origValues
M.origValues = {}

local values = {}
local fields = {
    ["texSize"] = 0,
    ["overDarkFactor"] = 0,
    ["shadowDistance"] = 0,
    ["shadowSoftness"] = 0,
    ["numSplits"] = 0,
    ["logWeight"] = 0,
    ["fadeStartDistance"] = 0,
    ["lastSplitTerrainOnly"] = 0,
}

local function getAndSaveSettings()
    local data = {}

    if scenetree.sunsky and fields then
        for k, v in pairs(fields) do
            v = scenetree.sunsky:getField(k, 0)
            data[k] = v
        end
        values = data
    end

    zeit_rcMain.updateSettings("shadowsettings", data)
end

local function loadSettings(settings)
    if not scenetree.sunsky then return end
    settings = settings or {}

    if not origValues then
        origValues = {}
        for k in pairs(fields) do
            origValues[k] = scenetree.sunsky:getField(k, 0)
        end
        M.origValues = origValues
    end

    for k in pairs(fields) do
        if settings[k] then
            scenetree.sunsky:setField(k, 0, settings[k])
        elseif origValues[k] then
            scenetree.sunsky:setField(k, 0, origValues[k])
        end
    end

    values = settings
end

local function setEnabled(bool)
    if bool then
        zeit_rcMain.updateSettings("shadowsettings", {})
    else
        if scenetree.sunsky then
            for k in pairs(fields) do
                if origValues[k] then
                    scenetree.sunsky:setField(k, 0, origValues[k])
                end
            end
        end
        zeit_rcMain.updateSettings("shadowsettings", nil)
    end
end

local function onUpdate()
    local sunsky = scenetree.sunsky
    if not sunsky or not values.logWeight then return end
    if not zeit_rcMain.uiActive and not editor.isEditorActive() and sunsky:getField("logWeight", 0) ~= values.logWeight then
        sunsky:setField("logWeight", 0, values.logWeight)
    end
end

local function onExtensionUnloaded()
    if scenetree.sunsky and origValues then
        for k, v in pairs(origValues) do
            scenetree.sunsky:setField(k, 0, v)
        end
    end
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = onUpdate
M.onExtensionUnloaded = onExtensionUnloaded

return M