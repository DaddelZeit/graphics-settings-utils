-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local lastInside

local data = {}

local function loadSettings(settings)
    settings = settings or {}
    if scenetree.SSAOPostFx then
        scenetree.SSAOPostFx:setContrast(settings.contrast or 2)
        scenetree.SSAOPostFx:setRadius(settings.radius or 1.5)
        scenetree.SSAOPostFx:setSamples(settings.samples or 16)
    end
    data = settings
end

local function getAndSaveSettings(contrast, radius, samples)
    data = {
        contrast = contrast ~= 2 and contrast or nil,
        radius = radius ~= 1.5 and radius or nil,
        samples = samples ~= 16 and samples or nil
    }

    zeit_rcMain.updateSettings("ssao", next(data) and data or nil)
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