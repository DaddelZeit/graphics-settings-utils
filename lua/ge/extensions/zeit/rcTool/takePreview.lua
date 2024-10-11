-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

-- Could be better optimised, but none of this runs in a loop
-- Doesn't really matter

local timer = -1
local set = false
local taken = false
local targetPath = ""

local function setPreview()
    scenetree.tod.time = 0.19
    commands.setFreeCamera()
    core_camera.setFOV(0, 40)
    core_camera.setPosRot(0, 326.2678019,-924.433397,138.2394728, -0.01397477147,-0.01590517798,-0.7510551953,0.6598998596)
    be:getPlayerVehicle(0):setPosRot(317.9197998,-923.456604,137.1888123, 0.0198171,0.0229504,0.634115,0.772644)
end

local function onUpdate(dt)
    if not core_vehicleBridge then return end
    if timer == -1 then return end
    timer = timer + dt

    if timer > 8 then
        ui_visibility.set(true)
        be:getPlayerVehicle(0):delete()
        extensions.unload("zeit_rcTool_takePreview")
    end
    if timer > 6 and not taken then
        createScreenshot(targetPath, "png")
        taken = true
    elseif timer > 3 and not set then
        core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setIgnitionLevel', 1)
        core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setFreeze', true)
        setPreview()
        ui_visibility.set(false)
        set = true
    end
end

local function onClientPostStartMission()
    local veh = spawn.spawnVehicle("bastion", "/settings/zeit/rendercomponents/default.pc", vec3(), quat())
    if veh then
        be:enterVehicle(0, veh)
        timer = 0
    end
end

local function start(str)
    targetPath = str
    set = false
    taken = false
    if getCurrentLevelIdentifier() ~= "utah" then
        core_levels.startLevel("/levels/utah/main.level.json")
    else
        onClientPostStartMission()
    end
end

M.onUpdate = onUpdate
M.start = start
M.onClientPostStartMission = onClientPostStartMission
M.setPreview = setPreview

return M