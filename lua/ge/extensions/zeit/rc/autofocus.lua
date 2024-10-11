-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local dof
local isEnabled = false
local doVehicle = false

--[[
-- stupidly detailed auto focus; does jbeam casts
-- this is terrible for performance (for obvious reasons)
-- not like the implementation is any good, anyways

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

    return cast > 0 and cast or math.huge
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

local function drawBox(box)
    local col = ColorF(1,0,0,1)
    local facecol = color(255, 0, 0, 64)
    local center = box:getCenter()
    local halfExt = box:getHalfExtents()
    local cornerA = center+halfExt.x*box:getAxis(0)+halfExt.y*box:getAxis(1)+halfExt.z*box:getAxis(2)
    local cornerB = center+(-halfExt.x)*box:getAxis(0)+halfExt.y*box:getAxis(1)+halfExt.z*box:getAxis(2)
    local cornerC = center+halfExt.x*box:getAxis(0)+(-halfExt.y)*box:getAxis(1)+halfExt.z*box:getAxis(2)
    local cornerD = center+(-halfExt.x)*box:getAxis(0)+(-halfExt.y)*box:getAxis(1)+halfExt.z*box:getAxis(2)
    debugDrawer:drawLine(cornerA, cornerB, col)
    debugDrawer:drawLine(cornerA, cornerC, col)
    debugDrawer:drawLine(cornerC, cornerD, col)
    debugDrawer:drawLine(cornerD, cornerB, col)

    local cornerE = center+halfExt.x*box:getAxis(0)+halfExt.y*box:getAxis(1)+(-halfExt.z)*box:getAxis(2)
    local cornerF = center+(-halfExt.x)*box:getAxis(0)+halfExt.y*box:getAxis(1)+(-halfExt.z)*box:getAxis(2)
    local cornerG = center+halfExt.x*box:getAxis(0)+(-halfExt.y)*box:getAxis(1)+(-halfExt.z)*box:getAxis(2)
    local cornerH = center+(-halfExt.x)*box:getAxis(0)+(-halfExt.y)*box:getAxis(1)+(-halfExt.z)*box:getAxis(2)
    debugDrawer:drawLine(cornerE, cornerF, col)
    debugDrawer:drawLine(cornerE, cornerG, col)
    debugDrawer:drawLine(cornerG, cornerH, col)
    debugDrawer:drawLine(cornerH, cornerF, col)

    debugDrawer:drawLine(cornerA, cornerE, col)
    debugDrawer:drawLine(cornerB, cornerF, col)
    debugDrawer:drawLine(cornerC, cornerG, col)
    debugDrawer:drawLine(cornerD, cornerH, col)

    -- back
    debugDrawer:drawTriSolid(cornerA, cornerF, cornerE, facecol)
    debugDrawer:drawTriSolid(cornerF, cornerA, cornerB, facecol)
    -- front
    debugDrawer:drawTriSolid(cornerH, cornerC, cornerG, facecol)
    debugDrawer:drawTriSolid(cornerC, cornerH, cornerD, facecol)

    -- top
    debugDrawer:drawTriSolid(cornerA, cornerC, cornerB, facecol)
    debugDrawer:drawTriSolid(cornerD, cornerB, cornerC, facecol)
    -- bottom
    debugDrawer:drawTriSolid(cornerE, cornerF, cornerG, facecol)
    debugDrawer:drawTriSolid(cornerH, cornerG, cornerF, facecol)

    -- left
    debugDrawer:drawTriSolid(cornerC, cornerA, cornerE, facecol)
    debugDrawer:drawTriSolid(cornerC, cornerE, cornerG, facecol)
    -- right
    debugDrawer:drawTriSolid(cornerD, cornerF, cornerB, facecol)
    debugDrawer:drawTriSolid(cornerD, cornerH, cornerF, facecol)
end

local focalDistSmoother = newTemporalSigmoidSmoothing(500, 500, 900, 400)
local function autoFocus(dtReal)
    if not isEnabled then return end
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
        return
    end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist")) or 0
    local camPos = core_camera.getPosition()
    local camForwardVec = core_camera.getForward()
    local dist = castRayStatic(camPos, camForwardVec, farDist) or farDist

    local obb
    for _, veh in activeVehiclesIterator() do
        obb = veh:getSpawnWorldOOBB()

        --local rayMin, rayMax = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * obb:getHalfExtents().x, obb:getAxis(1) * obb:getHalfExtents().y, obb:getAxis(2) * obb:getHalfExtents().z)
        --local res = math.max(rayMin, rayMax)

        local halfExt = obb:getHalfExtents()
        local res = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * halfExt.x, obb:getAxis(1) * halfExt.y, obb:getAxis(2) * halfExt.z)
        dist = math.min(dist, res<0 and farDist or res)
    end

    dof.focalDist = focalDistSmoother:get(dist, dtReal)
end

local function autoFocusNoVehicle(dtReal)
    if not isEnabled then return end
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
        return
    end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist")) or 0
    local camPos = core_camera.getPosition()
    local camForwardVec = core_camera.getForward()
    local dist = castRayStatic(camPos, camForwardVec, farDist) or farDist

    dof.focalDist = focalDistSmoother:get(dist, dtReal)
end

local function autoFocusDebug(dtReal)
    if not isEnabled then return end
    if not dof then
        dof = scenetree.findObject("DOFPostEffect")
        return
    end

    local farDist = tonumber(TorqueScriptLua.getVar("$Param::FarDist")) or 1000
    local camPos = core_camera.getPosition()
    local camForwardVec = core_camera.getForward()
    local dist = castRayStatic(camPos, camForwardVec, farDist) or farDist

    local obb
    for _, veh in activeVehiclesIterator() do
        obb = veh:getSpawnWorldOOBB()

        --local rayMin, rayMax = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * obb:getHalfExtents().x, obb:getAxis(1) * obb:getHalfExtents().y, obb:getAxis(2) * obb:getHalfExtents().z)
        --local res = math.max(rayMin, rayMax)

        local halfExt = obb:getHalfExtents()
        local res = intersectsRay_OBB(camPos, camForwardVec, obb:getCenter(), obb:getAxis(0) * halfExt.x, obb:getAxis(1) * halfExt.y, obb:getAxis(2) * halfExt.z)
        dist = math.min(dist, res<0 and farDist or res)

        drawBox(obb)
    end

    dof.focalDist = focalDistSmoother:get(dist, dtReal)
end

local function onExtensionLoaded()
    focalDistSmoother:set(0)
end

local function toggleDebug(bool)
    if bool then
        M.onPreRender = isEnabled and (doVehicle and autoFocusDebug or autoFocusNoVehicle) or nop
    else
        M.onPreRender = isEnabled and (doVehicle and autoFocus or autoFocusNoVehicle) or nop
    end
end

local function loadSettings(settings)
    settings = settings or {}
    isEnabled = settings.isEnabled or false
    doVehicle = settings.doVehicle or true

    M.onPreRender = isEnabled and (doVehicle and autoFocus or autoFocusNoVehicle) or nop
end

local function toggle(enabled, vehicle)
    local data = {
        isEnabled = enabled,
        doVehicle = vehicle
    }
    if data then
        zeit_rcMain.updateSettings("autofocus", data)
    else
        zeit_rcMain.updateSettings("autofocus", nil)
    end
end

M.onPreRender = nop
M.onExtensionLoaded = onExtensionLoaded
M.toggle = toggle
M.toggleDebug = toggleDebug
M.loadSettings = loadSettings

return M