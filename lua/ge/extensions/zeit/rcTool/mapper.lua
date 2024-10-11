-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings = {
    "autofocus",
    "contrastsaturation",
    "dof",
    "generaleffects",
    "rendercomponents",
    "shadowsettings",
    "ssao",
    "uifps",
    "vignette",
    "sharpen",
    "filmgrain",
    "letterbox",
    "chromaticAbberation"
}

local mapper = {
    {
        "isEnabled",
    },
    {
        "contrast",
        "saturation",
    },
    {
        "farBlurMax",
        "farSlope",
        "focalDist",
        "isEnabled",
        "lerpBias",
        "lerpScale",
        "maxRange",
        "nearBlurMax",
        "nearSlope",
        "minRange",
    },
    {
        "$pref::Shadows::disable",
        "$pref::Shadows::filterMode",
        "$pref::Shadows::textureScalar",
        "$pref::imposter::canShadow",

        "$pref::GroundCover::densityScale",
        "$pref::TS::maxDecalCount",
        "$pref::TS::detailAdjust",
        "$pref::Terrain::lodScale",
        "$pref::TS::smallestVisiblePixelSize",

        "$pref::Terrain::detailScale",
        "$pref::Reflect::refractTexScale",
        "$pref::Video::textureReductionLevel",

        "$pref::Water::disableTrueReflections",
        "$pref::Camera::distanceScale",

        "$pref::TS::skipLoadDLs",
        "$pref::TS::skipRenderDLs",

        "$pref::BeamNGVehicle::dynamicMirrors::detail",
        "$pref::BeamNGVehicle::dynamicMirrors::distance",
        "$pref::BeamNGVehicle::dynamicMirrors::enabled",
        "$pref::BeamNGVehicle::dynamicMirrors::textureSize",
        "$pref::BeamNGVehicle::dynamicReflection::detail",
        "$pref::BeamNGVehicle::dynamicReflection::distance",
        "$pref::BeamNGVehicle::dynamicReflection::enabled",
        "$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate",
        "$pref::BeamNGVehicle::dynamicReflection::textureSize",

        "$LightRayPostFX::brightScalar",
        "$LightRayPostFX::numSamples",
        "$LightRayPostFX::density",
        "$LightRayPostFX::weight",
        "$LightRayPostFX::decay",
        "$LightRayPostFX::exposure",
        "$LightRayPostFX::resolutionScale",
        "$pref::Reflect::frameLimitMS",
        "$pref::windEffectRadius",
        "$pref::Video::defaultAnisotropy",
        "$pref::Video::disableCubemapping",
        "$pref::Video::disableNormalmapping",
        "$pref::Video::disablePixSpecular"
    },
    {
        "HSL",
        "bloomScale",
        "blueShiftColor",
        "blueShiftLumVal",
        "colorCorrectionRampPath",
        "colorCorrectionStrength",
        "enableBlueShift",
        "enabled",
        "knee",
        "maxAdaptedLum",
        "middleGray",
        "oneOverGamma",
        "threshHold",
    },
    {
        "attenuationRatio",
        "cookie",
        "fadeStartDistance",
        "logWeight",
        "numSplits",
        "overDarkFactor",
        "shadowDistance",
        "shadowSoftness",
        "shadowType",
        "texSize",
    },
    {
        "contrast",
        "radius",
        "samples",
    },
    {
        "fps",
    },
    {
        "vmax",
        "vmin",
        "color",
    },
    {
        "sharpness",
    },
    {
        "intensity",
        "variance",
        "mean",
        "signalToNoiseRatio"
    },
    {
        "height",
        "color",
        "width",
        "heightOverride",
    },
    {
        "dist",
        "cube",
        "color",
    }
}

local function secondCompress(data, key)
    local newdata = {}
    for k,v in pairs(data) do
        local numkey = arrayFindValueIndex(mapper[key], k)
        if numkey then
            newdata[arrayFindValueIndex(mapper[key], k)] = deepcopy(v)
        else
            newdata[k] = v
        end
    end
    return newdata
end
local function compress(data)
    local newdata = {}
    for k,v in pairs(data) do
        local numkey = arrayFindValueIndex(settings, k)
        if numkey then
            newdata[numkey] = secondCompress(v, numkey)
        else
            newdata[k] = v
        end
    end
    return newdata
end


local function secondDecompress(data, key)
    local newdata = {}
    for k,v in pairs(data) do
        if mapper[key] then
            local newkey = mapper[key][k] or k
            newdata[newkey] = deepcopy(v)
        end
    end
    return newdata
end
local function decompress(data)
    local newdata = {}
    for k,v in pairs(data) do
        newdata[settings[k] and settings[k] or k] = secondDecompress(v, k)
    end
    return newdata
end

M.compress = compress
M.decompress = decompress

return M