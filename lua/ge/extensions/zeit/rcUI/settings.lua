-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain", "ui_imgui"}

M.showUI = false

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")

local exportDebug = require("/lua/ge/extensions/zeit/rcTool/exportDebug")

local iconsTex = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/icons.png")
local previews = {
    spinner = {
        ["All"] = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/spinner_all.png"),
        ["Only Spinner"] = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/spinner_only.png"),
        ["Only Text"] = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/spinner_text.png"),
        ["None"] = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/spinner_none.png"),
    },
    warning = imguiUtils.texObj("/settings/zeit/rendercomponents/settings/warning_example.png"),
}

local loadingSpinner = {
    "None",
    "Only Spinner",
    "Only Text",
    "All"
}

local selectWindowDragging

local blockWindowMovement = false
local setBgAlpha = false
local minSize = im.ImVec2(256,256)
local maxSize = im.ImVec2(1024,1024)

local function toggleUI()
    widgets.blurRemove("zeitRenderSettingsSettings")
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)
end

local function renderTopBar()
    im.SetCursorPosY(-style.ItemSpacing.y+im.GetScrollY())
    im.PushFont3("cairo_bold")

    widgets.textCentered("Zeit's Graphics Utils: Settings")

    im.SetCursorPosX(im.GetWindowWidth()-im.CalcTextSize("X").x-style.FramePadding.x*2-style.WindowPadding.x)
    if widgets.button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)
    im.PopFont()

    im.Separator()
end

local scrollTo
local function setScrollTo(name)
    scrollTo = name
end

local function renderSelectorLayoutEntry(entrySetting, i, emptySpace)
    local queueRemove = false
    im.Image(iconsTex.texId, im.ImVec2(emptySpace, emptySpace), im.ImVec2(0,0), im.ImVec2(0.25,1))
    if im.IsItemHovered() then
        im.SetMouseCursor(im.MouseCursor_ResizeNS)
        blockWindowMovement = true
        if im.IsMouseDragging(0) and not selectWindowDragging then
            selectWindowDragging = i
        end
    end

    im.SameLine()
    im.Image(iconsTex.texId, im.ImVec2(emptySpace, emptySpace), im.ImVec2(0.75,0), im.ImVec2(1,1))
    if im.IsItemHovered() then
        if im.IsItemHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            im.SetTooltip("Remove")
        end
        if im.IsMouseClicked(0) then
            queueRemove = true
        end
    end

    local windowEntry = zeit_rcUI_select.windows[entrySetting[i]]
    if not windowEntry then
        im.SameLine()
        im.Image(iconsTex.texId, im.ImVec2(emptySpace, emptySpace), im.ImVec2(0.25,0), im.ImVec2(0.5,1), im.ImVec4(1,0.25,0.25,1))
        if im.IsItemHovered() then
            im.SetTooltip("This window no longer exists and won't appear.\nConsider removing this entry.")
        end
    end
    im.SameLine()
    im.Text(windowEntry and windowEntry.name or entrySetting[i])

    return queueRemove
end

-- https://stackoverflow.com/a/32232733
local  function drag(t, src, len, dest)
    local copy = table.move(t, src, src + len - 1, 1, {})

    if src >= dest then
        table.move(t, dest, src - 1, dest + len)
    else
        table.move(t, src + len, dest + len - 1, src)
    end

    table.move(copy, 1, len, dest, t)
end

local function render(dt)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.6)
    end

    im.SetNextWindowSizeConstraints(minSize, maxSize)
    im.Begin("Zeit's Graphics Utils: Settings", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + (blockWindowMovement and im.WindowFlags_NoMove or 0))

    widgets.blurUpdate("zeitRenderSettingsSettings")
    im.BeginMenuBar()
    renderTopBar()
    im.EndMenuBar()

    local scrollPos = {}
    if im.BeginTable("##zeitRenderSettingsSettingsQuickAccess", 6) then
        im.TableNextColumn()
        if widgets.button("Mod Thread", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            openWebBrowser("https://beamng.com/threads/85768/")
        end
        im.TableNextColumn()
        if widgets.button("Interface", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            scrollTo = "Interface"
        end
        im.TableNextColumn()
        if widgets.button("Auto-Apply", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            scrollTo = "Auto-Apply"
        end
        im.TableNextColumn()
        if widgets.button("Debug", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            scrollTo = "Debug"
        end
        im.TableNextColumn()
        if widgets.button("Updates", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            scrollTo = "Updates"
        end
        im.TableNextColumn()
        if widgets.button("About", im.ImVec2(im.GetContentRegionAvailWidth(), 40)) then
            scrollTo = "About"
        end
        im.EndTable()
        im.Separator()
    end

    scrollPos["Interface"] = im.GetCursorPosY()
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(2)
    im.Text("Interface")
    im.SetWindowFontScale(1)
    im.PopFont()

    blockWindowMovement = false
    if zeit_rcUI_select then
        local dirty = false
        widgets.tooltipButton({
            desc = "Rearrange the window selector.",
            default = "Profile Manager, Profile Editor, Photo Tool, Settings",
        })
        im.SameLine()
        im.Text("Window Selector Layout")
        im.Indent()
        im.Separator()
        local entrySetting = settingsManager.get("select_windows")

        local emptySpace = im.GetTextLineHeightWithSpacing()
        local cursorPosThresholds = {}
        local removeEntry
        for i=1, #entrySetting do
            if i ~= selectWindowDragging then
                local minPos = im.GetCursorScreenPos()
                local maxPos = im.ImVec2(minPos.x+im.GetContentRegionAvailWidth(), minPos.y+emptySpace)
                if im.IsMouseHoveringRect(minPos, maxPos) then
                    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), minPos, maxPos, im.GetColorU321(im.Col_TableRowBgAlt))
                end
                if renderSelectorLayoutEntry(entrySetting, i, emptySpace) then
                    removeEntry = i
                end
            else
                im.Dummy(im.ImVec2(1, emptySpace))
            end
            cursorPosThresholds[i] = im.GetCursorPosY() - emptySpace/2
            im.Separator()
        end


        if selectWindowDragging then
            local prevCursor = im.GetCursorPosY()
            local mouseY = im.GetMousePos().y-im.GetWindowPos().y+im.GetScrollY()-emptySpace/2
            if im.IsMouseDragging(0) then
                im.SetCursorPosY(mouseY)

                local minPos = im.GetCursorScreenPos()
                local maxPos = im.ImVec2(minPos.x+im.GetContentRegionAvailWidth(), minPos.y+emptySpace)
                if im.IsMouseHoveringRect(minPos, maxPos) then
                    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), minPos, maxPos, im.GetColorU321(im.Col_TableRowBgAlt, 5))
                end
                renderSelectorLayoutEntry(entrySetting, selectWindowDragging, emptySpace)
            else
                local moveTo = #entrySetting
                for i=1, #entrySetting do
                    if i ~= selectWindowDragging and mouseY<cursorPosThresholds[i]then
                        moveTo = i
                        break
                    end
                end

                drag(entrySetting, selectWindowDragging, 1, moveTo)
                dirty = true
                selectWindowDragging = nil
            end
            im.SetCursorPosY(prevCursor)
        end

        if removeEntry then
            table.remove(entrySetting, removeEntry)
            dirty = true
        end
        if im.BeginCombo("##WindowSelectAdd", "Add...") then
            for i=1, #zeit_rcUI_select.windowsKeys do
                local v = zeit_rcUI_select.windowsKeys[i]
                im.Image(iconsTex.texId, im.ImVec2(emptySpace, emptySpace), im.ImVec2(0.5,0), im.ImVec2(0.75,1))
                im.SameLine()
                if im.Selectable1(v, false) then
                    for k2,v2 in pairs(zeit_rcUI_select.windows) do
                        if v2.name == v then
                            table.insert(entrySetting, k2)
                            dirty = true
                        end
                    end
                end
            end
            im.EndCombo()
        end

        im.Unindent()
        widgets.tooltipButton({
            desc = "The amount of entries after which the next line begins.",
            default = "4",
            key = "zeit_graphics_selected_linemax"
        })
        im.SameLine()
        local temp = im.IntPtr(settingsManager.get("selected_linemax", 4))
        if im.SliderInt("Wrap Amount", temp, 1, 8) then
            dirty = true
        end
        if dirty then
            zeit_rcUI_select.loadEntries()
            settingsManager.set("selected_window", 1)
            settingsManager.set("select_windows", entrySetting, true)
            settingsManager.set("selected_linemax", temp[0])
        end

        im.NewLine()
    end

    local temp
    widgets.tooltipButton({
        desc = "Display mode of the loading indicator in the top left.",
        default = "All",
        key = "zeit_graphics_apply_spinner"
    })
    im.SameLine()
    temp = settingsManager.get("apply_spinner")+1
    if im.BeginCombo("##LoadingSpinnerFormatSelector", loadingSpinner[temp]) then
        for k,v in pairs(loadingSpinner) do
            if im.Selectable1(v, k == temp) then
                settingsManager.set("apply_spinner", k-1)
            end
        end
        im.EndCombo()
    end
    im.SameLine()
    im.Text("Loading Spinner Display")

    im.Indent()
    im.Indent()
    local tempPreview = previews.spinner[loadingSpinner[temp]]
    im.Image(tempPreview.texId, tempPreview.size, nil, nil, nil, im.ColorConvertU32ToFloat4(im.GetColorU321(im.Col_ChildBg, 0.5)))
    im.Unindent()
    im.Unindent()
    im.NewLine()

    widgets.tooltipButton({
        desc = "Allow top-right message pop-ups.",
        default = "true",
        key = "zeit_graphics_send_warnings"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("send_warnings"))
    if im.Checkbox("Send Warning Pop-Ups", temp) then
        settingsManager.set("send_warnings", temp[0])
    end


    im.Indent()
    im.Indent()
    tempPreview = previews.warning
    im.Image(tempPreview.texId, tempPreview.size, nil, nil, nil, im.ColorConvertU32ToFloat4(im.GetColorU321(im.Col_ChildBg, 0.5)))
    im.Unindent()
    im.Unindent()
    im.NewLine()

    widgets.tooltipButton({
        desc = "How long the mod will wait to submit a new history entry after a change.",
        default = "1",
        key = "zeit_graphics_history_cooldown"
    })
    im.SameLine()
    temp = im.FloatPtr(settingsManager.get("history_cooldown"))
    if im.SliderFloat("History Commit Cooldown", temp, 0.1, 8, "%.3f", 0) then
        settingsManager.set("history_cooldown", temp[0])
    end

    widgets.tooltipButton({
        desc = "How many entries back the history saves. High numbers can create stutters.",
        default = "500",
        key = "zeit_graphics_max_history"
    })
    im.SameLine()
    temp = im.IntPtr(settingsManager.get("max_history"))
    if im.SliderInt("History Limit", temp, 1, 5000, "%d", im.SliderFlags_Logarithmic) then
        settingsManager.set("max_history", temp[0])
    end

    im.Separator()
    scrollPos["Auto-Apply"] = im.GetCursorPosY()
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(2)
    im.Text("Auto-Apply")
    im.SetWindowFontScale(1)
    im.PopFont()

    widgets.tooltipButton({
        desc = "Re-apply the settings whenever they may be changed, e.g. in photo mode or map overview mode.",
        default = "true",
        key = "zeit_graphics_auto_apply"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("auto_apply"))
    if im.Checkbox("Automatically Re-Apply Profile", temp) then
        settingsManager.set("auto_apply", temp[0])
    end

    widgets.tooltipButton({
        desc = "How often the util will attempt to enable the settings.",
        default = "true",
        key = "zeit_graphics_max_apply_loops"
    })
    im.SameLine()
    temp = im.IntPtr(settingsManager.get("max_apply_loops"))
    if im.SliderInt("Maximum Re-Apply Attempts", temp, 1, 10, "%d", 0) then
        settingsManager.set("max_apply_loops", temp[0])
    end

    im.Separator()
    scrollPos["Debug"] = im.GetCursorPosY()
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(2)
    im.Text("Debug")
    im.SetWindowFontScale(1)
    im.PopFont()

    widgets.tooltipButton({
        desc = "Send debug log messages.",
        default = "true",
        key = "zeit_graphics_collect_logs"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("collect_logs"))
    if im.Checkbox("Log Mod Actions", temp) then
        settingsManager.set("collect_logs", temp[0])
    end

    widgets.tooltipButton({
        desc = "Collect information about the system. Note: This only happens when exporting a debug packet.",
        default = "true",
        key = "zeit_graphics_collect_platform"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("collect_platform"))
    if im.Checkbox("Collect Relevant Platform Data", temp) then
        settingsManager.set("collect_platform", temp[0])
    end
    if widgets.button("Export Debug Packet", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        if temp[0] then
            exportDebug.getPlatform()
        end
        exportDebug.export()
    end

    im.NewLine()
    widgets.tooltipButton({
        desc = "Clear all temporary mod files. That includes history, previous debug information and other non-important files stored for quick access.\nThis does not affect settings or profiles.",
    })
    im.SameLine()
    im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8,0.15,0.1,1))
    if widgets.button("Clear Mod Cache", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        zeit_rcMain.clearTemp(1)
    end
    im.PopStyleColor(im.Col_Button)

    widgets.tooltipButton({
        desc = "Clear all shader cache created by the game. That includes shaders not supplied by the mod.\nShaders will be fully reloaded when the game restarts.",
    })
    im.SameLine()
    im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8,0.15,0.1,1))
    if widgets.button("Clear Shader Cache", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        zeit_rcMain.clearTemp(2)
    end
    im.PopStyleColor(im.Col_Button)

    im.NewLine()
    widgets.tooltipButton({
        desc = "Clear ALL mod data including settings, cache and profiles.",
    })
    im.SameLine()
    im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8,0.15,0.1,1))
    if widgets.button("Remove All Data", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        zeit_rcMain.removeMod(false)
    end
    im.PopStyleColor(im.Col_Button)

    widgets.tooltipButton({
        desc = "Shows the dialog available above automatically when a mod removal is detected.",
        default = "true",
        key = "zeit_graphics_delete_dialog_show"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("delete_dialog_show"))
    if im.Checkbox("Automatically detect mod removal", temp) then
        settingsManager.set("delete_dialog_show", temp[0])
    end

    im.Separator()
    scrollPos["Updates"] = im.GetCursorPosY()
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(2)
    im.Text("Updates")
    im.SetWindowFontScale(1)
    im.PopFont()

    widgets.tooltipButton({
        desc = "Check for updates every time the game starts up.",
        default = "true",
        key = "zeit_graphics_auto_update_check"
    })
    im.SameLine()
    temp = im.BoolPtr(settingsManager.get("auto_update_check"))
    if im.Checkbox("Automatic Update Check", temp) then
        settingsManager.set("auto_update_check", temp[0])
    end

    im.Text("Changelog for the current version:")
    local intendedWindowHeight = 150
    im.BeginChild1("zeitRenderSettingsSettingsChangelog", im.ImVec2(im.GetContentRegionAvailWidth(), intendedWindowHeight))
    im.Indent()
    im.Text(zeit_rcMain.currentChangelog)
    im.Unindent()
    im.EndChild()
    if zeit_rcUI_updateCheck then
        local disabled = zeit_rcUI_updateCheck.running
        if disabled then
            im.BeginDisabled()
        end
        if widgets.button(disabled and "Checking for Updates..." or "Check for Updates", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            zeit_rcUI_updateCheck.getUpdateAvailable()
        end
        if disabled then
            im.EndDisabled()
        end
    end

    im.Separator()
    scrollPos["About"] = im.GetCursorPosY()
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(2)
    im.Text("About")
    im.SameLine()
    widgets.textCentered("Zeit's Graphics Settings Utils")
    im.SetWindowFontScale(1)
    im.PopFont()

    im.Text("Credits:")
    im.BeginChild1("zeitRenderSettingsSettingsCredits", im.ImVec2(im.GetContentRegionAvailWidth(), intendedWindowHeight))
    im.Indent()
    im.Bullet() im.Text("@DaddelZeit (Me) - Programming, Contrast/Saturation Shader, Letterbox Shader, Profile tuning")
    im.Bullet() im.Text("CeeJayDK on GitHub - SweetFX/Shaders/FilmGrain.fx")
    im.Bullet() im.Text("butterw on GitHub - bShaders/FilmGrain_Noise/SweetFx.FilmGrain.hlsl")
    im.Bullet() im.Text("GarageGames on GitHub (Torque 3D) - Sharpness PostFX, Vignette PostFX")
    im.Bullet() im.Text("Rochet2 on GitHub - lualzw/lualzw.lua")
    im.NewLine()
    im.Bullet() im.Text("@KlaidasHQ - Direct testing")
    im.Bullet() im.Text("sum1namedkris - Direct Testing")
    im.Bullet() im.Text("@Car_Killer - Testing Future-Compatibility")
    im.Bullet() im.Text("Theocord Members - Broad-scale testing")
    im.Unindent()
    im.EndChild()

    if im.BeginTable("##zeitRenderSettingsSettingsContact", 3) then
        im.TableNextColumn()
        if widgets.button("Open Thread", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            openWebBrowser("https://beamng.com/threads/85768/")
        end
        im.TableNextColumn()
        if widgets.button("Open GitHub", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            openWebBrowser("https://youtube.com/redirect?q=https://github.com/DaddelZeit/graphics-settings-utils/")
        end
        im.TableNextColumn()
        if widgets.button("Start Conversation (beamng.com)", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            openWebBrowser("https://www.beamng.com/conversations/add?to=DaddelZeit")
        end
        im.EndTable()
    end

    im.Separator()
    im.Text("© "..os.date("%Y").." - DaddelZeit")

    if scrollTo then
        im.SetScrollY(scrollPos[scrollTo])
        scrollTo = nil
    end

    widgets.guardViewportOverflow()

    im.End()
end

local function onUpdate(dtReal)
    if M.showUI == false then return end
    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()
end

local function onZeitGraphicsLoaded()
    if zeit_rcUI_select then
        zeit_rcUI_select.addEntry("settings", {
            id = "zeit_rcUI_settings",
            name = "Settings",
            texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/settings.png")
        })
    end
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
    if M.showUI then
        toggleUI()
    end
end

M.onUpdate = onUpdate
M.toggleUI = toggleUI
M.setScrollTo = setScrollTo
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onZeitGraphicsLoaded = onZeitGraphicsLoaded

return M