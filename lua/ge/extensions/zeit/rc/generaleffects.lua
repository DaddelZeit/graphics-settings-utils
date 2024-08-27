-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local defaults = rerequire("zeit/rcTool/defaultVars").get()
local originalData = rerequire("zeit/rcTool/defaultVars").getOthers()
local data = {}
local function saveSettings()
  zeit_rcMain.updateSettings("generaleffects", data)
end

local function addSetting(k,v,save)
  if tostring(k) then
    data[tostring(k)] = v
    if save == nil then saveSettings() end
  end
end

local function loadSettings(settings)
  if settings and TorqueScriptLua then
    -- make sure we always have the listed defaults
    local prevLightManager = TorqueScriptLua.getVar("$pref::lightManager")
    local prevTextureReduction = TorqueScriptLua.getVar("$pref::Video::textureReductionLevel")
    TorqueScriptLua.setVar("$pref::lightManager", defaults["$pref::lightManager"].default)
    TorqueScriptLua.setVar("$pref::Video::textureReductionLevel", defaults["$pref::Video::textureReductionLevel"].default)

    for k,v in pairs(defaults) do
      TorqueScriptLua.setVar(k,v.default)
    end
    for k,v in pairs(originalData) do
      TorqueScriptLua.setVar(k,v.default)
    end

    data = {}
    for k,v in pairs(settings) do
      data[k] = v
      TorqueScriptLua.setVar(k, v)
    end

    local lightManager = TorqueScriptLua.getVar("$pref::lightManager")
    if lightManager ~= prevLightManager then
      log("I", "", "resetting light manager: "..lightManager)
      setLightManager(lightManager)
    end

    local textureReduction = TorqueScriptLua.getVar("$pref::Video::textureReductionLevel")
    if textureReduction ~= prevTextureReduction then
      log("I", "", "setting texture reduction: "..textureReduction)
      reloadTextures()
    end
  end
end

-- public interface (IMPORTANT)
M.saveSettings = saveSettings
M.addSetting = addSetting
M.loadSettings = loadSettings

return M