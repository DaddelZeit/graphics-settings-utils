-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local fields = {
    isEnabled = "$DOFPostEffect::Enable",
    nearBlurMax = "$DOFPostFx::BlurMin",
    lerpScale = 0,
    farSlope = "$DOFPostFx::BlurCurveFar",
    maxRange = "$DOFPostFx::FocusRangeMax",
    farBlurMax = "$DOFPostFx::BlurMax",
    lerpBias = 0,
    focalDist = 0,
    nearSlope = "$DOFPostFx::BlurCurveNear",
    minRange = "$DOFPostFx::FocusRangeMin",
}

local function getAndSaveSettings()
    local obj = scenetree.findObject("DOFPostEffect")
    local data = {}

    obj = Sim.upcast(obj)

    if obj and fields then
        for k, v in pairs(fields) do
            v = obj[k]
            data[k] = v
        end
        data.isEnabled = tostring(obj:isEnabled() and 1 or 0)
    end

    zeit_rcMain.updateSettings("dof", data)
end

local function loadSettings(settings)
    if settings then
        local obj = scenetree.findObject("DOFPostEffect")
        if not obj then return end
        obj = Sim.upcast(obj)

        for k, v in pairs(fields) do
            if settings[k] then
                --if type(v) == "string" then
                --    TorqueScriptLua.setVar(v, settings[k])
                --    dump(v, settings[k])
                --end
                obj[k] = settings[k]
            end
        end
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings

return M