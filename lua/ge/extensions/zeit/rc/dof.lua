-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local origValues
M.origValues = {}

local data = {}

local fields = {
    ["isEnabled"] = "$DOFPostEffect::Enable",
    ["nearBlurMax"] = "$DOFPostFx::BlurMin",
    ["farSlope"] = "$DOFPostFx::BlurCurveFar",
    ["maxRange"] = "$DOFPostFx::FocusRangeMax",
    ["farBlurMax"] = "$DOFPostFx::BlurMax",
    ["nearSlope"] = "$DOFPostFx::BlurCurveNear",
    ["minRange"] = "$DOFPostFx::FocusRangeMin",
}

local function getAndSaveSettings()
    local _data = {}
    local obj = scenetree.DOFPostEffect
    obj = Sim.upcast(obj)

    if obj and fields then
        for k, v in pairs(fields) do
            v = obj[k]
            _data[k] = v
        end
        _data.isEnabled = obj:isEnabled() and "1" or "0"
    end

    data = _data
    zeit_rcMain.updateSettings("dof", _data)
end

local function saveSetting(key, value)
    data[key] = value
    zeit_rcMain.updateSettings("dof", data)
end

local function loadSettings(_settings)
    local obj = scenetree.DOFPostEffect
    if not obj then return end
    obj = Sim.upcast(obj)

    _settings = _settings and deepcopy(_settings) or {}
    if not _settings.isEnabled or _settings.isEnabled == "2" then
        _settings.isEnabled = settings.getValue("PostFXDOFGeneralEnabled") and "1" or "0"
    end

    if not origValues then
        origValues = {}
        for k in pairs(fields) do
            origValues[k] = obj[k]
        end
        M.origValues = origValues
    end

    for k in pairs(fields) do
        if _settings[k] then
            obj[k] = _settings[k]
        elseif origValues[k] then
            obj[k] = origValues[k]
        end
    end

    if _settings.isEnabled == "1" then
        obj:enable()
    else
        obj:disable()
    end

    data = _settings
end

local function setEnabled(state)
    if state == 0 then
        local obj = scenetree.DOFPostEffect
        if obj then
            obj = Sim.upcast(obj)
            for k in pairs(fields) do
                obj[k] = origValues[k] or obj[k]
            end
        end
        data.isEnabled = "0"
        zeit_rcMain.updateSettings("dof", data)
    elseif state == 1 then
        data.isEnabled = "1"
        zeit_rcMain.updateSettings("dof", data)
    else
        data.isEnabled = "2"
        zeit_rcMain.updateSettings("dof", data)
    end
end

local function onExtensionUnloaded()
    local obj = scenetree.DOFPostEffect
    if obj and origValues then
        obj = Sim.upcast(obj)
        for k, v in pairs(origValues) do
            obj[k] = v
        end
    end
    data = {}
end

-- public interface (IMPORTANT)
M.setEnabled = setEnabled
M.saveSetting = saveSetting
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onExtensionUnloaded = onExtensionUnloaded

return M