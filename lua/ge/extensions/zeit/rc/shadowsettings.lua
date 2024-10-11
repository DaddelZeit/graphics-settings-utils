-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local sunsky
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

local function onUpdate()
    if zeit_rcMain.uiActive or editor.active then return end
    if values.logWeight and sunsky.logWeight ~= values.logWeight then
        sunsky:setField("logWeight", 0, values.logWeight)
    end
end

local function getAndSaveSettings()
    local data = {}
    sunsky = scenetree.sunsky

    if sunsky and fields then
        for k in pairs(fields) do
            data[k] = sunsky:getField(k, 0)
        end
        values = data
    end

    zeit_rcMain.updateSettings("shadowsettings", data)
end

local function loadSettings(settings)
    sunsky = scenetree.sunsky
    if not sunsky then
        M.onUpdate = nil
        return
    end
    settings = settings or {}
    M.onUpdate = settings.logWeight and onUpdate or nil

    if not origValues then
        origValues = {}
        for k in pairs(fields) do
            origValues[k] = sunsky:getField(k, 0)
        end
        M.origValues = origValues
    end

    for k in pairs(fields) do
        if settings[k] then
            sunsky:setField(k, 0, settings[k])
        elseif origValues[k] then
            sunsky:setField(k, 0, origValues[k])
        end
    end

    values = settings
end

local function setEnabled(bool)
    if bool then
        zeit_rcMain.updateSettings("shadowsettings", {})
    else
        sunsky = scenetree.sunsky
        if sunsky then
            for k in pairs(fields) do
                if origValues[k] then
                    sunsky:setField(k, 0, origValues[k])
                end
            end
        end
        zeit_rcMain.updateSettings("shadowsettings", nil)
    end
end

local function onExtensionUnloaded()
    sunsky = scenetree.sunsky
    if sunsky and origValues then
        for k, v in pairs(origValues) do
            sunsky:setField(k, 0, v)
        end
    end
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onUpdate = nil
M.onExtensionUnloaded = onExtensionUnloaded

return M