-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local defaults = require("zeit/rcTool/defaultVars").get()
local originalData = require("zeit/rcTool/defaultVars").getOthers()

local data = {}
local tempSave = {}
local function saveSettings()
  zeit_rcMain.updateSettings("generaleffects", data)
end

local function addSetting(k,v)
  if tostring(k) then
    data[tostring(k)] = v
    saveSettings()
  end
end

local function addSettingTemp(k,v)
  if tostring(k) then
    if not tempSave[k] then
      tempSave[k] = TorqueScriptLua.getVar(tostring(k))
    end
    TorqueScriptLua.setVar(tostring(k), v or tempSave[k])
  end
end

local function isNil(k)
  return data[k] == nil
end

local function loadSettings(settings)
  settings = settings or {}
  if TorqueScriptLua then
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
     zeit_rcMain.log("I", "", "resetting light manager: "..lightManager)
      setLightManager(lightManager)
    end

    local textureReduction = TorqueScriptLua.getVar("$pref::Video::textureReductionLevel")
    if textureReduction ~= prevTextureReduction then
     zeit_rcMain.log("I", "", "setting texture reduction: "..textureReduction)
      reloadTextures()
    end
  end
end

-- public interface (IMPORTANT)
M.saveSettings = saveSettings
M.addSetting = addSetting
M.addSettingTemp = addSettingTemp
M.loadSettings = loadSettings
M.isNil = isNil

return M