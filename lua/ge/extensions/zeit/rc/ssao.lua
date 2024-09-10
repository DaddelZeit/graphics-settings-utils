-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local lastInside

M.data = {}

local function loadSettings(settings)
    settings = settings or {}
    if scenetree.SSAOPostFx then
        scenetree.SSAOPostFx:setContrast(settings.contrast or 2)
        scenetree.SSAOPostFx:setRadius(settings.radius or 1.5)
        scenetree.SSAOPostFx:setSamples(settings.samples or 16)
    end
    M.data = settings
end

local function getAndSaveSettings(contrast, radius, samples)
    M.data = {
        contrast = contrast ~= 2 and contrast or nil,
        radius = radius ~= 1.5 and radius or nil,
        samples = samples ~= 16 and samples or nil
    }

    zeit_rcMain.updateSettings("ssao", next(M.data) and M.data or nil)
end

local function onPreRender()
    if M.data.radius and getPlayerVehicle(0) then
        local oobb = getPlayerVehicle(0):getSpawnWorldOOBB()
        local inside = oobb:isContained(core_camera.getPosition())

        if not inside and lastInside then
            scenetree.SSAOPostFx:setRadiusTarget(M.data.radius)
        end

        lastInside = inside
    end
end

local function isNil(k)
    return M.data[k] == nil
end

local function setContrast(contrast)
    getAndSaveSettings(contrast, M.data.radius, M.data.samples)
end

local function setRadius(radius)
    getAndSaveSettings(M.data.contrast, radius, M.data.samples)
end

local function setQuality(highQuality)
    getAndSaveSettings(M.data.contrast, M.data.radius, highQuality == nil and nil or highQuality and 32 or 16)
end

-- public interface (IMPORTANT)
M.getAndSaveSettings = getAndSaveSettings
M.loadSettings = loadSettings
M.onPreRender = onPreRender
M.setContrast = setContrast
M.setRadius = setRadius
M.setQuality = setQuality
M.isNil = isNil

return M