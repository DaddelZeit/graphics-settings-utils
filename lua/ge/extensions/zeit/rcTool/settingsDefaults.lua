-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local defaults = {
    ["zeit_graphics_auto_update_check"] = true,

    ["zeit_graphics_auto_apply"] = true,
    ["zeit_graphics_max_apply_loops"] = 10,
    ["zeit_graphics_apply_spinner"] = 3,
    ["zeit_graphics_send_warnings"] = true,

    ["zeit_graphics_history_cooldown"] = 1,
    ["zeit_graphics_max_history"] = 1000,

    ["zeit_graphics_collect_logs"] = true,
    ["zeit_graphics_collect_platform"] = true,

    ["zeit_graphics_selected_window"] = 1,

    ["zeit_graphics_export_option"] = 1,
    ["zeit_graphics_export_info"] = true,

    ["zeit_graphics_generaleffects_auto_apply"] = false,
}

local function validate()
    for k,v in pairs(defaults) do
        if settings.getValue(k, nil) == nil then
            settings.setValue(k, v)
        end
    end
end

local function remove()
    for k in pairs(defaults) do
        settings.setValue(k, nil)
    end
end

local function get()
    local tbl = {}
    for k in pairs(defaults) do
        tbl[k] = settings.getValue(k, defaults[k])
    end
    return tbl
end

M.get = get
M.remove = remove
M.validate = validate

return M