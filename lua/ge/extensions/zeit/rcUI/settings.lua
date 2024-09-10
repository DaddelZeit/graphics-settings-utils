-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

M.showUI = false

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")

local exportDebug = require("/lua/ge/extensions/zeit/rcTool/exportDebug")

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

--[[
local selectWindowPositionSmoother = {}
local selectWindowEntrySize = im.ImVec2(128,128)
]]

local currentScroll = 0
local noScrollInputTicks = 0
local preventScrollUp = false
local preventScrollDown = false
local totalScroll = 0
local scrollSmoother = newTemporalSigmoidSmoothing(10, 20, 20, 10, 0)

local blockWindowMovement = false
local setBgAlpha = false
local size = im.ImVec2(1024,512)

local function resizeFont(scale)
    local scaledFont = im.GetFont()
    local prevSize = scaledFont.Scale
    scaledFont.Scale = scale
    im.PushFont(scaledFont)
    scaledFont.Scale = prevSize
end

local function toggleUI()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsSettings", nil) end
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)
end

local function renderTopBar()
    im.SetCursorPosY(-style.ItemSpacing.y+im.GetScrollY())
    im.PushFont3("cairo_bold")

    widgets.textCentered("Zeit's Graphics Utils: Settings")

    im.SetCursorPosX(im.GetWindowSize().x-style.ScrollbarSize-im.CalcTextSize("X").x-style.ItemInnerSpacing.x*2-style.ItemSpacing.x)
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

local function render(dt)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.6)
    end

    im.SetNextWindowSize(size)
    im.Begin("Zeit's Graphics Utils: Settings", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse + (blockWindowMovement and im.WindowFlags_NoMove or 0))

    local pos1 = im.GetWindowPos()
    local pos2 = im.GetMainViewport().Pos
    local size1 = im.GetWindowSize()
    local deskRes = GFXDevice.getVideoMode()
    local data = {(pos1.x-pos2.x)/deskRes.width, (pos1.y-pos2.y)/deskRes.height, size1.x/deskRes.width, size1.y/deskRes.height, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsSettings", {["1"] = data})

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

    im.PushFont3("cairo_bold")
    resizeFont(2)
    scrollPos["Interface"] = im.GetCursorPosY()
    im.Text("Interface")
    im.PopFont()
    im.PopFont()

    --[[
    blockWindowMovement = false
    if zeit_rcUI_select then
        im.Text("Window Selector Layout")
        local windowSize = im.GetContentRegionAvailWidth()/4
        for i=1, zeit_rcUI_select.entries do
            local fullWindowPos = windowSize*(i-1)+selectWindowEntrySize.x/2
            if not selectWindowPositionSmoother[i] then
                selectWindowPositionSmoother[i] = newTemporalSigmoidSmoothing(250, 400, 400, 250, fullWindowPos)
            end

            if setBgAlpha then
                im.SetNextWindowBgAlpha(0.6)
            end

            im.SetCursorPosX(selectWindowPositionSmoother[i]:get(fullWindowPos, dt))
            im.BeginChild1("##zeitRenderSettingsSettingsWindowSelector"..i, selectWindowEntrySize, true)
            zeit_rcUI_select.renderEntry(i)
            if im.IsWindowHovered() then
                im.SetMouseCursor(im.MouseCursor_ResizeEW)
                blockWindowMovement = true
                if im.IsMouseDragging(0) then
                    selectWindowPositionSmoother[i]:set(fullWindowPos+im.GetMouseDragDelta().x)
                end
            end
            im.EndChild()
            im.SameLine()
        end
        im.NewLine()
        im.NewLine()
    end
    ]]

    local temp
    widgets.tooltipButton({
        desc = "Display mode of the loading indicator in the top left.",
        default = "All",
        key = "zeit_graphics_apply_spinner"
    })
    im.SameLine()
    temp = settings.getValue("zeit_graphics_apply_spinner")+1
    if im.BeginCombo("##LoadingSpinnerFormatSelector", loadingSpinner[temp]) then
        for k,v in pairs(loadingSpinner) do
            if im.Selectable1(v, k == temp) then
                settings.setValue("zeit_graphics_apply_spinner", k-1)
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
    temp = im.BoolPtr(settings.getValue("zeit_graphics_send_warnings"))
    if im.Checkbox("Send Warning Pop-Ups", temp) then
        settings.setValue("zeit_graphics_send_warnings", temp[0])
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
    temp = im.FloatPtr(settings.getValue("zeit_graphics_history_cooldown"))
    if im.SliderFloat("History Commit Cooldown", temp, 0.1, 8, "%.3f", 0) then
        settings.setValue("zeit_graphics_history_cooldown", temp[0])
    end

    widgets.tooltipButton({
        desc = "How many entries back the history saves.",
        default = "1000",
        key = "zeit_graphics_max_history"
    })
    im.SameLine()
    temp = im.IntPtr(settings.getValue("zeit_graphics_max_history"))
    if im.SliderInt("History Limit", temp, 1, 10000, "%d", im.SliderFlags_Logarithmic) then
        settings.setValue("zeit_graphics_max_history", temp[0])
    end

    im.Separator()
    im.PushFont3("cairo_bold")
    resizeFont(2)
    im.Text("Auto-Apply")
    im.PopFont()
    im.PopFont()

    widgets.tooltipButton({
        desc = "Re-apply the settings whenever they may be changed, e.g. in photo mode or map overview mode.",
        default = "true",
        key = "zeit_graphics_auto_apply"
    })
    im.SameLine()
    temp = im.BoolPtr(settings.getValue("zeit_graphics_auto_apply"))
    if im.Checkbox("Automatically Re-Apply Profile", temp) then
        settings.setValue("zeit_graphics_auto_apply", temp[0])
    end

    widgets.tooltipButton({
        desc = "How often the util will attempt to enable the settings.",
        default = "true",
        key = "zeit_graphics_max_apply_loops"
    })
    im.SameLine()
    temp = im.IntPtr(settings.getValue("zeit_graphics_max_apply_loops"))
    if im.SliderInt("Maximum Re-Apply Attempts", temp, 1, 10, "%d", 0) then
        settings.setValue("zeit_graphics_max_apply_loops", temp[0])
    end

    scrollPos["Auto-Apply"] = im.GetCursorPosY()
    im.Separator()
    im.PushFont3("cairo_bold")
    resizeFont(2)
    im.Text("Debug")
    im.PopFont()
    im.PopFont()

    widgets.tooltipButton({
        desc = "Send debug log messages.",
        default = "true",
        key = "zeit_graphics_collect_logs"
    })
    im.SameLine()
    temp = im.BoolPtr(settings.getValue("zeit_graphics_collect_logs"))
    if im.Checkbox("Log Mod Actions", temp) then
        settings.setValue("zeit_graphics_collect_logs", temp[0])
    end

    widgets.tooltipButton({
        desc = "Collect information about the system. Note: This only happens when exporting a debug packet.",
        default = "true",
        key = "zeit_graphics_collect_platform"
    })
    im.SameLine()
    temp = im.BoolPtr(settings.getValue("zeit_graphics_collect_platform"))
    if im.Checkbox("Collect Relevant Platform Data", temp) then
        settings.setValue("zeit_graphics_collect_platform", temp[0])
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

    scrollPos["Debug"] = im.GetCursorPosY()
    im.Separator()
    im.PushFont3("cairo_bold")
    resizeFont(2)
    im.Text("Updates")
    im.PopFont()
    im.PopFont()

    widgets.tooltipButton({
        desc = "Check for updates every time the game starts up.",
        default = "true",
        key = "zeit_graphics_auto_update_check"
    })
    im.SameLine()
    temp = im.BoolPtr(settings.getValue("zeit_graphics_auto_update_check"))
    if im.Checkbox("Automatic Update Check", temp) then
        settings.setValue("zeit_graphics_auto_update_check", temp[0])
    end

    im.Text("Changelog for the current version:")
    local intendedWindowHeight = 150
    im.BeginChild1("zeitRenderSettingsSettingsChangelog", im.ImVec2(im.GetContentRegionAvailWidth(), intendedWindowHeight))
    im.Indent()
    im.Text(zeit_rcMain.currentChangelog)
    im.Unindent()

    if im.IsWindowHovered() and im.GetCursorPosY() > intendedWindowHeight then
        local scroll = im.GetScrollY()
        if scroll == 0 then
            preventScrollDown = true
        elseif scroll == im.GetScrollMaxY() then
            preventScrollUp = true
        else
            preventScrollUp = true
            preventScrollDown = true
        end
    end
    im.EndChild()
    if widgets.button("Check for Updates", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        if zeit_rcUI_updateCheck then
           zeit_rcUI_updateCheck.getUpdateAvailable()
        end
    end

    scrollPos["Updates"] = im.GetCursorPosY()
    im.Separator()
    im.PushFont3("cairo_bold")
    resizeFont(2)
    im.Text("About")
    im.SameLine()
    widgets.textCentered("Zeit's Graphics Settings Utils")
    im.PopFont()
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
    if im.IsWindowHovered() and im.GetCursorPosY() > intendedWindowHeight then
        local scroll = im.GetScrollY()
        if scroll == 0 then
            preventScrollDown = true
        elseif scroll == im.GetScrollMaxY() then
            preventScrollUp = true
        else
            preventScrollUp = true
            preventScrollDown = true
        end
    end
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
    scrollPos["About"] = im.GetCursorPosY()

    im.PopStyleColor()
    im.PopStyleColor()

    if im.IsWindowHovered(im.HoveredFlags_RootAndChildWindows) then
        local input = im.GetIO().MouseWheel
        if input ~= 0 then
            if (input > 0 and not preventScrollUp) or (input < 0 and not preventScrollDown) then
                totalScroll = math.max(math.min(totalScroll - im.GetIO().MouseWheel/6, 1), 0)
            end

            if noScrollInputTicks == 0 then
                preventScrollUp = false
                preventScrollDown = false
                noScrollInputTicks = 1
            else
                noScrollInputTicks = noScrollInputTicks - 1
            end
        end
    end

    if scrollTo then totalScroll = scrollPos[scrollTo]/im.GetCursorPosY(); scrollTo = nil end
    local lastScroll = currentScroll
    currentScroll = scrollSmoother:get(totalScroll, dt)*im.GetScrollMaxY()
    im.SetScrollY(currentScroll)
    if math.floor(lastScroll) ~= im.GetScrollY() then
        totalScroll = im.GetScrollY()/im.GetScrollMaxY()
    end
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

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsSettings", nil) end
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.toggleUI = toggleUI
M.setScrollTo = setScrollTo

return M