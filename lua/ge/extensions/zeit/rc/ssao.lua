-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local lastInside

local data = {}

local function loadSettings(settings)
    if settings and scenetree.SSAOPostFx then
        scenetree.SSAOPostFx:setContrast(settings.contrast)
        scenetree.SSAOPostFx:setRadius(settings.radius)
        scenetree.SSAOPostFx:setSamples(settings.samples)
    end
end

local function getAndSaveSettings(contrast, radius, samples)
    data = {
        contrast = contrast,
        radius = radius,
        samples = samples
    }

    zeit_rcMain.updateSettings("ssao", data)
end

local function onPreRender()
    if be:getPlayerVehicle(0) and data and data.radius then
        local oobb = be:getPlayerVehicle(0):getSpawnWorldOOBB()
        local inside = oobb:isContained(core_camera.getPosition())

        if not inside and lastInside then
            scenetree.SSAOPostFx:setRadiusTarget(data.radius)
        end

        lastInside = inside
    end
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onPreRender = onPreRender

return M