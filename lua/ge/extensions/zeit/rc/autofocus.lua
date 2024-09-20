-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local focalDistSmoother = newExponentialSmoothing(20)
local wantedFocusDist = 0

local dof
local isEnabled = false

local function autoFocus()
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
    end
    if not isEnabled then return end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist"))

    -- use mouse cast in photo mode
    if photoModeOpen then
        local rayCastFlags = bit.bor(SOTTerrain, SOTWater, SOTStaticShape, SOTPlayer, SOTItem, SOTVehicle, SOTForest)
        local rayCast = cameraMouseRayCast(true, rayCastFlags) or {}
        wantedFocusDist = math.min(rayCast.distance or 0, farDist)
    else
        local camForwardVec = core_camera.getForward()
        camForwardVec.z = camForwardVec.z/10
        local rayCast = castRayStatic(core_camera.getPosition(), camForwardVec, 200) or 200
        wantedFocusDist = math.min(rayCast, farDist)
    end

    dof.focalDist = focalDistSmoother:get(wantedFocusDist)
end

local function loadSettings(settings)
    if settings then
        isEnabled = settings.isEnabled
    end
end

local function toggle(bool)
    local data = {isEnabled = bool}
    zeit_rcMain.updateSettings("autofocus", data)
end

local function onExtensionLoaded()
    focalDistSmoother:set(tonumber(TorqueScriptLua.getVar("$Param::FarDist")))
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = autoFocus
M.toggle = toggle
M.loadSettings = loadSettings

return M