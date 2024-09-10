local M = {}

local im = ui_imgui

local function retrieveDefaults()
    local tbl = {}
    tableMerge(tbl, (require("core/settings/lightingQuality") or {qualityLevels={}}).qualityLevels[settings.getValue("GraphicLightingQuality", "Normal")] or {})
    tableMerge(tbl, (require("core/settings/meshQuality")     or {qualityLevels={}}).qualityLevels[settings.getValue("GraphicMeshQuality",     "Normal")] or {})
    tableMerge(tbl, (require("core/settings/textureQuality")  or {qualityLevels={}}).qualityLevels[settings.getValue("GraphicTextureQuality",  "Normal")] or {})
    tableMerge(tbl, (require("core/settings/shaderQuality")   or {qualityLevels={}}).qualityLevels[settings.getValue("GraphicShaderQuality",   "Normal")] or {})
    return tbl
end

local function getDefaults()
    local defaultSettings = retrieveDefaults()
    local tbl = {
        ["$pref::Shadows::disable"] = {
            name = "Disable Shadows",
            desc = "Disables all shadow rendering.",
            default = defaultSettings["$pref::Shadows::disable"]==2,
            ptr = im.BoolPtr(defaultSettings["$pref::Shadows::disable"]==2),
        },
        ["$pref::lightManager"] = {
            name = "Light Manager",
            desc = "The current running lighting manager.",
            default = defaultSettings["$pref::lightManager"] or "Advanced Lighting",
            ptr = defaultSettings["$pref::lightManager"] or "Advanced Lighting",
        },
        ["$pref::Shadows::filterMode"] = {
            name = "Filter Mode",
            desc = "Changes the way shadow edges are handled.",
            default = defaultSettings["$pref::Shadows::filterMode"] or "SoftShadowHighQuality",
            ptr = defaultSettings["$pref::Shadows::filterMode"] or "SoftShadowHighQuality",
        },
        ["$pref::Shadows::textureScalar"] = {
            name = "Texture Scalar",
            desc = "Used to scale the shadow texture sizes. This can increase the shadow quality and texture memory overhead or decrease them.",
            default = defaultSettings["$pref::Shadows::textureScalar"] or 1,
            ptr = im.FloatPtr(defaultSettings["$pref::Shadows::textureScalar"] or 1)
        },
        ["$pref::imposter::canShadow"] = {
            name = "Imposter Shadows",
            desc = "Toggles shadows from imposters (e.g. distant trees that rotate to the camera).",
            default = true,
            ptr = im.BoolPtr(true)
        },

        ["$pref::GroundCover::densityScale"] = {
            name = "Ground Cover Density",
            desc = "A global level of detail scalar which can reduce the overall density of placed GroundCover.",
            default = settings.getValue("GraphicGrassDensity") or 1000,
            ptr = im.FloatPtr(settings.getValue("GraphicGrassDensity") or 1000),
        },
        ["$pref::TS::maxDecalCount"] = {
            name = "Maximum Tire Marks",
            desc = "How many tire marks can exist in a scene.",
            default = settings.getValue("GraphicMaxDecalCount") or 1000,
            ptr = im.IntPtr(settings.getValue("GraphicMaxDecalCount") or 1000),
        },
        ["$pref::TS::detailAdjust"] = {
            name = "Mesh LOD Scale",
            desc = "The smaller the value the closer the camera must get to see the highest level of detail. This setting can have a huge impact on performance in mesh heavy scenes. (Higher is better)",
            default = defaultSettings["$pref::TS::detailAdjust"] or 1,
            ptr = im.FloatPtr(defaultSettings["$pref::TS::detailAdjust"] or 1)
        },
        ["$pref::Terrain::lodScale"] = {
            name = "Terrain LOD Scale",
            desc = "A global level of detail scale used to tweak the default terrain screen error value. (Lower is better)",
            default = defaultSettings["$pref::Terrain::lodScale"] or 1,
            ptr = im.FloatPtr(defaultSettings["$pref::Terrain::lodScale"] or 1),
        },
        ["$pref::TS::smallestVisiblePixelSize"] = {
            name = "Smallest Visible Pixel Size",
            desc = "User perference which sets the smallest pixel size at which TSShapes will skip rendering. This will force all shapes to stop rendering when they get smaller than this size. The default value is -1 which disables it.",
            default = -1,
            ptr = im.IntPtr(-1),
        },

        ["$pref::Terrain::detailScale"] = {
            name = "Terrain Material Detail Scale",
            desc = "A global detail scale used to tweak the material detail distances.",
            default = defaultSettings["$pref::Terrain::detailScale"] or 1,
            ptr = im.FloatPtr(defaultSettings["$pref::Terrain::detailScale"] or 1),
        },
        ["$pref::Reflect::refractTexScale"] = {
            name = "Refract Texture Scale",
            desc = "The refract texture (view behind e.g. water) has dimensions equal to the screen scaled in both x and y by this value.",
            default = defaultSettings["$pref::Terrain::refractTexScale"] or 1,
            ptr = im.FloatPtr(defaultSettings["$pref::Reflect::refractTexScale"] or 1)
        },
        ["$pref::Video::textureReductionLevel"] = {
            name = "Texture Reduction Level",
            desc = "Reduces texture resolution/quality.",
            default = defaultSettings["$pref::Video::textureReductionLevel"] or 0,
            ptr = im.IntPtr(defaultSettings["$pref::Video::textureReductionLevel"] or 0)
        },

        ["$pref::Water::disableTrueReflections"] = {
            name = "Prohibit True Water Reflections",
            desc = "Globally disables level reflections on water",
            default = defaultSettings["$pref::Water::disableTrueReflections"]==1,
            ptr =  im.BoolPtr(defaultSettings["$pref::Water::disableTrueReflections"]==1)
        },

        ["$pref::TS::skipLoadDLs"] = {
            name = "Skip Loading Detail Levels",
            desc = "User perference which causes TSShapes to skip loading higher lods. This potentialy reduces the GPU resources and materials generated as well as limits the LODs rendered.",
            default = false,
            ptr = im.BoolPtr(false),
        },
        ["$pref::TS::skipRenderDLs"] = {
            name = "Skip Rendering Detail Levels",
            desc = "User perference which causes TSShapes to skip rendering higher lods. This will reduce the number of draw calls and triangles rendered and improve rendering performance when proper LODs have been created for your models.",
            default = defaultSettings["$pref::TS::skipRenderDLs"]==1,
            ptr = im.BoolPtr(defaultSettings["$pref::TS::skipRenderDLs"]==1),
        },

        ["$pref::BeamNGVehicle::dynamicMirrors::detail"] = {
            name = "Mirrors Detail",
            desc = "Detail scale of the dynamic mirrors.",
            default = settings.getValue("GraphicDynMirrorsDetail") or 0,
            ptr = im.FloatPtr(settings.getValue("GraphicDynMirrorsDetail") or 0)
        },
        ["$pref::BeamNGVehicle::dynamicMirrors::distance"] = {
            name = "Mirrors Distance",
            desc = "Render distance of the dynamic mirrors.",
            default = settings.getValue("GraphicDynMirrorsDistance") or 0,
            ptr = im.IntPtr(settings.getValue("GraphicDynMirrorsDistance") or 0)
        },
        ["$pref::BeamNGVehicle::dynamicMirrors::enabled"] = {
            name = "Mirrors",
            desc = "If the dynamic mirrors are enabled.",
            default = settings.getValue("GraphicDynMirrorsEnabled") or false,
            ptr = im.BoolPtr(settings.getValue("GraphicDynMirrorsEnabled") or false)
        },
        ["$pref::BeamNGVehicle::dynamicMirrors::textureSize"] = {
            name = "Mirror Texture Size",
            desc = "Texture size of the dynamic mirrors.",
            default = math.pow(2, (settings.getValue("GraphicDynMirrorsTexsize") or 1) + 7),
            ptr = im.IntPtr(math.pow(2, (settings.getValue("GraphicDynMirrorsTexsize") or 1) + 7))
        },
        ["$pref::BeamNGVehicle::dynamicReflection::detail"] = {
            name = "Reflection Detail",
            desc = "Detail level of the reflection.",
            default = settings.getValue("GraphicDynReflectionDetail") or 0,
            ptr = im.FloatPtr(settings.getValue("GraphicDynReflectionDetail") or 0)
        },
        ["$pref::BeamNGVehicle::dynamicReflection::distance"] = {
            name = "Reflection Distance",
            desc = "Render distance of the reflection.",
            default = settings.getValue("GraphicDynReflectionDistance") or 0,
            ptr = im.IntPtr(settings.getValue("GraphicDynReflectionDistance") or 0)
        },
        ["$pref::BeamNGVehicle::dynamicReflection::enabled"] = {
            name = "Reflections",
            desc = "If reflections render.",
            default = settings.getValue("GraphicDynReflectionEnabled") or false,
            ptr = im.BoolPtr(settings.getValue("GraphicDynReflectionEnabled") or false)
        },
        ["$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate"] = {
            name = "Reflection Faces per Update",
            desc = "How many faces of the cubemap update at once.",
            default = settings.getValue("GraphicDynReflectionFacesPerupdate") or 0,
            ptr = im.IntPtr(settings.getValue("GraphicDynReflectionFacesPerupdate") or 0)
        },
        ["$pref::BeamNGVehicle::dynamicReflection::textureSize"] = {
            name = "Reflection Texture Size",
            desc = "Texture size of each side of the reflection cubemap.",
            default = math.pow(2, (settings.getValue("GraphicDynReflectionTexsize") or 0) + 7),
            ptr = im.IntPtr(math.pow(2, (settings.getValue("GraphicDynReflectionTexsize") or 0) + 7))
        },
    }

    return tbl
end

local function getOthers()
    local tbl = {
        ["$pref::windEffectRadius"] = {
            desc = "Radius to affect the wind.",
            type = "int",
            default = 25,
            max = 100,
            ptr = im.IntPtr(25)
        },
        ["$LightRayPostFX::numSamples"] = {
            desc = "The number of samples for the shader.",
            type = "int",
            default = 40,
            min = 5,
            max = 100,
            ptr = im.IntPtr(40)
        },
        ["$LightRayPostFX::brightScalar"] = {
            desc = "Controls how bright the rays and the objcet casting them are in the scene.",
            type = "float",
            default = 0.75,
            max = 1,
            ptr = im.FloatPtr(0.75)
        },
        ["$LightRayPostFX::resolutionScale"] = {
            desc = "Scales resolution of the lightrays.",
            type = "float",
            default = 0.2,
            min = 0.01,
            max = 6,
            ptr = im.FloatPtr(0.2)
        },
        ["$LightRayPostFX::density"] = {
            desc = "Controls how close together the rays spawn/how long sections are.",
            type = "float",
            default = 0.94,
            min = 0.1,
            max = 1,
            ptr = im.FloatPtr(0.94)
        },
        ["$LightRayPostFX::exposure"] = {
            desc = "How light exposed the lightrays are.",
            type = "float",
            format ="%.5f",
            default = 0.0005,
            min = 0.0001,
            max = 0.001,
            ptr = im.FloatPtr(0.0005)
        },
        ["$LightRayPostFX::decay"] = {
            desc = "Controls the illumination decay of the rays.",
            type = "float",
            default = 1,
            min = 0.1,
            max = 1.025,
            ptr = im.FloatPtr(1)
        },
        ["$LightRayPostFX::weight"] = {
            desc = "Intensity of the lightrays. Add or remove weight of the rays for a better effect.",
            type = "float",
            default = 10,
            min = 2.5,
            max = 25,
            ptr = im.FloatPtr(10)
        },
        ["$pref::Reflect::frameLimitMS"] = {
            desc = "ReflectionManager tries not to spend more than this amount of time updating reflections per frame.",
            type = "int",
            default = 10,
            max = 100,
            ptr = im.IntPtr(10)
        },
        ["$pref::Video::defaultAnisotropy"] = {
            desc = "Global variable defining the default anisotropy value. Controls the default anisotropic texture filtering level for all materials, including the terrain.",
            type = "int",
            default = 8,
            max = 32,
            ptr = im.IntPtr(8)
        },
        ["$pref::Camera::distanceScale"] = {
            name = "View Distance Scale",
            type = "float",
            desc = "A scale to apply to the normal visible distance, typically used for tuning performance. MAY CONFLICT WITH VOLUMETRIC CLOUDS MOD",
            default = 1,
            max = 2,
            min = 0.1,
            ptr = im.FloatPtr(1)
        },
    }

    setmetatable(tbl, {
        __index = function(self, index)
            for k,v in pairs(self) do
                if k == index then
                    return v
                end
            end

            local new = {
                desc = "Unknown",
                type = "str",
                ptr = im.ArrayChar(256)
            }
            -- default: string
            self[index] = new
            return new
        end,
        __metatable = false
    })

    return tbl
end

M.getOthers = getOthers
M.get = getDefaults

return M
