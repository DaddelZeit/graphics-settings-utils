-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local dof
local isEnabled = false

--[[
local focalDistSmoother = newExponentialSmoothing(20)
local function boxInFrustum(frustum, obb)
    for i = 0, 7 do
        if frustum:isPointContained(obb:getPoint(i)) then
            return true
        end
    end
    return false
end

local function triangleRayCast(origin, dir, veh, tri)
    local cast = intersectsRay_Triangle(
        origin,
        dir,
        veh:getNodeAbsPosition(tri.id1),
        veh:getNodeAbsPosition(tri.id2),
        veh:getNodeAbsPosition(tri.id3)
    )

    return cast > 0 and cast or  math.huge
end

local function autoFocus()
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
        return
    end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist"))
    local camPos = core_camera.getPosition()
    local camForwardVec = core_camera.getForward()
    local rayCast = castRayStatic(camPos, camForwardVec, farDist) or farDist

    local frustum = Engine.sceneGetCameraFrustum()
    local dist = farDist
    for i=0, be:getObjectCount()-1 do
        local veh = be:getObject(i)
        if boxInFrustum(frustum, veh:getSpawnWorldOOBB()) then
            local vdata = core_vehicle_manager.getVehicleData(veh:getId())
            if vdata then
                vdata = vdata.vdata
                for j=0, #vdata.triangles do
                    local tri = vdata.triangles[j]
                    if frustum:isPointContained(veh:getNodeAbsPosition(tri.id1)) then
                        dist = math.min(dist, triangleRayCast(camPos, camForwardVec, veh, tri))
                    end
                end
            end
        end
    end

    dof.focalDist = focalDistSmoother:get(math.min(dist, rayCast))
end
]]

local focalDistSmoother = newTemporalSigmoidSmoothing(500, 500, 900, 400)
local function autoFocus(dtReal)
    if not isEnabled then return end
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
        return
    end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist"))
    local camPos = core_camera.getPosition()
    local camForwardVec = core_camera.getForward()
    local rayCast = castRayStatic(camPos, camForwardVec, farDist) or farDist

    local dist = rayCast
    for i=0, be:getObjectCount()-1 do
        local obb = be:getObject(i):getSpawnWorldOOBB()
        --local rayMin, rayMax = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * obb:getHalfExtents().x, obb:getAxis(1) * obb:getHalfExtents().y, obb:getAxis(2) * obb:getHalfExtents().z)
        --local res = math.max(rayMin, rayMax)
        local res = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * obb:getHalfExtents().x, obb:getAxis(1) * obb:getHalfExtents().y, obb:getAxis(2) * obb:getHalfExtents().z)
        dist = math.min(dist, res<0 and math.huge or res)
    end

    dof.focalDist = focalDistSmoother:get(dist, dtReal)
end

local function onExtensionLoaded()
    focalDistSmoother:set(tonumber(TorqueScriptLua.getVar("$Param::FarDist")))
end

local function loadSettings(settings)
    settings = settings or {}
    isEnabled = settings.isEnabled

    --local dof = scenetree.findObject("DOFPostEffect")
    --if dof then
    --    dof.autoFocusEnabled = (settings.isEnabled or false)
    --end
end

local function toggle(bool)
    local data = {isEnabled = bool}
    if data then
        zeit_rcMain.updateSettings("autofocus", data)
    else
        zeit_rcMain.updateSettings("autofocus", nil)
    end
end

M.onUpdate = autoFocus
M.onExtensionLoaded = onExtensionLoaded
M.toggle = toggle
M.loadSettings = loadSettings

return M