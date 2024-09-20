-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local originalData = {}
local data = {}
local function saveSettings()
  if data == {} then log("I", "", "table is empty, cannot save!") return end -- do not save if empty
  zeit_rcMain.updateSettings("generaleffects", data)
end

local function addSetting(k,v)
  if tostring(k) then
    data[tostring(k)] = v
    saveSettings()
  end
end

local function loadSettings(settings)
  if settings and TorqueScriptLua then
    -- get the previous settings so we can return later on
    for k,v in pairs(originalData) do
      TorqueScriptLua.setVar(k,v)
    end

    for k,v in pairs(settings) do
      if not originalData[k] then
        originalData[k] = TorqueScriptLua.getVar(k)
      end

      data[k] = v
      TorqueScriptLua.setVar(k, v)
    end
  end
end

-- public interface (IMPORTANT)
M.saveSettings = saveSettings
M.addSetting = addSetting
M.loadSettings = loadSettings

return M