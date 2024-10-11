-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local prefix = "zeit_graphics_"
local defaults = {
    ["auto_update_check"] = true,

    ["auto_apply"] = true,
    ["max_apply_loops"] = 10,
    ["apply_spinner"] = 3,
    ["send_warnings"] = true,

    ["history_cooldown"] = 1,
    ["max_history"] = 500,

    ["collect_logs"] = true,
    ["collect_platform"] = true,

    ["select_windows"] = {"profileManager", "edit", "screenshot", "settings"},
    ["selected_linemax"] = 4,
    ["selected_window"] = 1,

    ["profilemanager_full"] = false,

    ["export_option"] = 1,
    ["export_info"] = true,

    ["generaleffects_auto_apply"] = true,
    ["delete_dialog_show"] = true,
}

local function set(id, val)
    if val == defaults[id] then
        val = nil
    end
    settings.setValue(prefix..id, val)
end

local function get(id)
    return settings.getValue(prefix..id, defaults[id])
end

local function validate()
    for k,v in pairs(defaults) do
        if settings.getValue(prefix..k) == v then
            settings.setValue(prefix..k, nil)
        end
    end
end

local function remove()
    for k in pairs(defaults) do
        settings.setValue(prefix..k, nil)
    end
end

M.set = set
M.get = get
M.remove = remove
M.validate = validate

return M