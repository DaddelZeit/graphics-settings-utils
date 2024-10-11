-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local imguiUtils = require("ui/imguiUtils")

local function onZeitGraphicsLoaded()
    if zeit_rcUI_select then
        zeit_rcUI_select.addEntry("perfgraph", {
            id = "perfgraph",
            name = "Perf. Graph",
            texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/perfgraph.png"),
            enter = function()
                togglePerformanceGraph()
            end
        })

        zeit_rcUI_select.addEntry("perfmetrics", {
            id = "perfmetrics",
            name = "Perf. Metrics",
            texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/perfmetrics.png"),
            enter = function()
                extensions.core_metrics.toggle()
            end
        })
    end
end

M.onZeitGraphicsLoaded = onZeitGraphicsLoaded

return M