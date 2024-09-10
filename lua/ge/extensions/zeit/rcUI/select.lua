-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")

M.showUI = false
M.tab = 0

local selectedItem = settings.getValue("zeit_graphics_selected_window", 1)
local primaryInput = false
local secondaryInput = false
local entrySize = im.ImVec2(128,128)

local setBgAlpha = false

--[[ TODO
Move these entries to be manually registered by each module.
This will require some sort of priority system which would also allow for the user to re-arrange these.
(Although unlikely other modders could then register their windows here as well)
]]
local entries = {
    {
        id = "zeit_rcUI_profileManager",
        name = "Profile Manager",
        texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/manager.png")
    },
    {
        id = "zeit_rcUI_edit",
        name = "Profile Editor",
        texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/edit.png")
    },
    {
        id = "zeit_rcUI_screenshot",
        name = "Photo Tool",
        texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/photo.png")
    },
    {
        id = "zeit_rcUI_settings",
        name = "Settings",
        texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/settings.png")
    }
}
M.entries = #entries

local function toggleUI(...)
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsWindowSelector", nil) end
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)
end

local function launchWindow(index)
    toggleUI()
    local selectedIcon = entries[index].id
    if extensions[selectedIcon] and extensions[selectedIcon].toggleUI then
        extensions[selectedIcon].toggleUI()
    end
end

local function primary(value)
    primaryInput = value == 1
    if M.showUI and not primaryInput then
        launchWindow(selectedItem)
    end
end

local function secondary(value)
    secondaryInput = value == 1
    if not M.showUI and primaryInput and secondaryInput then
        toggleUI()
    elseif M.showUI and secondaryInput then
        selectedItem = selectedItem + 1
        if selectedItem == #entries+1 then
            selectedItem = 1
        end
        settings.setValue("zeit_graphics_selected_window", selectedItem)
    end
end

local function renderEntry(entry)
    entry = entries[entry]
    if entry.texObj then
        local textSize = im.CalcTextSize("").y
        local imageDimensions = im.ImVec2(entrySize.x/2, entrySize.y/2)
        local windowSize = im.GetWindowSize()
        im.SetCursorPos(im.ImVec2(windowSize.x/2-imageDimensions.x/2, windowSize.y/2-imageDimensions.y/2-textSize/2))
        im.Image(entry.texObj.texId, imageDimensions)
    end
    widgets.textCentered(entry.name)
end

local function render(dt)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.5)
    end

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))
    im.SetNextWindowPos(pos, nil, im.ImVec2(0.5, 0.5))

    im.PushStyleVar1(im.StyleVar_ChildRounding, 10)
    im.PushStyleVar1(im.StyleVar_ChildBorderSize, 3)

    im.SetNextWindowFocus()
    im.Begin("Zeit's Graphics Utils: Window Selector", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse + im.WindowFlags_AlwaysAutoResize)

    im.PushFont3("cairo_bold")
    widgets.textCentered("Zeit's Graphics Utils: Window Selector")
    for i=1, #entries do
        if setBgAlpha then
            im.SetNextWindowBgAlpha(0.6)
        end
        if i == selectedItem then
            im.PushStyleColor1(im.Col_Border, im.GetColorU321(im.Col_Button))
        end

        im.BeginChild1("##zeitRenderSettingsWindowSelector"..entries[i].id, entrySize, true)
        renderEntry(i)
        if im.IsWindowHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            if im.IsMouseClicked(0) then
                launchWindow(i)
                selectedItem = i
                settings.setValue("zeit_graphics_selected_window", i)
            end
        end
        im.EndChild()
        im.SameLine()

        if i == selectedItem then
            im.PopStyleColor()
        end
    end
    --[[
    if zeit_rcUI_settings then
        im.NewLine()
        im.PushStyleVar1(im.StyleVar_Alpha, 0.35)
        widgets.textCentered("Configure")
        if im.IsItemHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            if im.IsMouseClicked(0) then
                if not zeit_rcUI_settings.showUI then zeit_rcUI_settings.toggleUI() end
                zeit_rcUI_settings.setScrollTo("Interface")
                toggleUI()
            end
        end
        im.PopStyleVar()
    end
    ]]
    im.PopFont()

    local pos1 = im.GetWindowPos()
    local pos2 = im.GetMainViewport().Pos
    local size1 = im.GetWindowSize()
    local deskRes = GFXDevice.getVideoMode()
    local data = {(pos1.x-pos2.x)/deskRes.width, (pos1.y-pos2.y)/deskRes.height, size1.x/deskRes.width, size1.y/deskRes.height, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsWindowSelector", {["1"] = data})

    im.End()

    im.PopStyleVar()
    im.PopStyleVar()
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
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsWindowSelector", nil) end
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.renderEntry = renderEntry
M.primary = primary
M.secondary = secondary

return M