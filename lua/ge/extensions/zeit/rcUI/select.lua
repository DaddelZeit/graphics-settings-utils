-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local im = ui_imgui
local style = require("zeit/rcTool/style")
local widgets = rerequire("zeit/rcUI/editWidgets")

M.showUI = false

local selectedItem = settingsManager.get("selected_window")
local primaryInput = false
local secondaryInput = false
local entrySize = im.ImVec2(128,128)

local setBgAlpha = false
local lineWrap = settingsManager.get("selected_linemax")

local windows = {}
local windowsKeys = {}
local entries = {}
M.windows = windows
M.windowsKeys = windowsKeys
M.entries = entries
local queueUIToggle = false

local function loadEntries()
    table.clear(entries)
    table.sort(windowsKeys)
    local entrySetting = settingsManager.get("select_windows")
    for i=1, #entrySetting do
        if windows[entrySetting[i]] then
            table.insert(entries, entrySetting[i])
        end
    end
end

local function addEntry(id, entry)
    if id then
        windows[id] = entry
        windowsKeys[#windowsKeys+1] = entry.name
        loadEntries()
    end
end

local function toggleUI(...)
    widgets.blurRemove("zeitRenderSettingsWindowSelector")
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)

    if M.showUI then
        selectedItem = settingsManager.get("selected_window")
        lineWrap = settingsManager.get("selected_linemax")
    end
end

local function launchWindow(index)
    if entries[index] then
        local windowEntry = windows[entries[index]]
        if windowEntry.enter then
            windowEntry.enter()
        else
            local selectedIcon = windowEntry.id
            if extensions[selectedIcon] and extensions[selectedIcon].toggleUI then
                extensions[selectedIcon].toggleUI()
            end
        end
        selectedItem = index
        settingsManager.set("selected_window", selectedItem)
    end
end

local function primary(value)
    primaryInput = value == 1
    if M.showUI and not primaryInput then
        launchWindow(selectedItem)
        toggleUI()
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
    end
end

local buttons = {
    function()
        widgets.textCenteredLocal("Configure")
        if im.IsItemHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            if im.IsMouseClicked(0) then
                if not zeit_rcUI_settings.showUI then zeit_rcUI_settings.toggleUI() end
                zeit_rcUI_settings.setScrollTo("Interface")
                queueUIToggle = true
            end
        end
    end,

    function()
        widgets.textCenteredLocal("Reload Profile")
        if im.IsItemHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            if im.IsMouseClicked(0) then
                zeit_rcMain.loadProfile(zeit_rcMain.currentProfile)
                queueUIToggle = true
            end
        end
    end,

    function()
        widgets.textCenteredLocal("Reload Lua")
        if im.IsItemHovered() then
            im.SetMouseCursor(im.MouseCursor_Hand)
            if im.IsMouseClicked(0) then
                extensions.reload("zeit_rcMain")
                queueUIToggle = true
            end
        end
    end
}

local function renderEntry(entry)
    entry = windows[entries[entry]]
    if entry.texObj then
        local textSize = im.GetTextLineHeight()
        local imageDimensions = im.ImVec2(entrySize.x/2, entrySize.y/2)
        local windowSize = im.GetWindowSize()
        im.SetCursorPos(im.ImVec2(windowSize.x/2-imageDimensions.x/2, windowSize.y/2-imageDimensions.y/2-textSize/2))
        im.Image(entry.texObj.texId, imageDimensions)
    end
    widgets.textCentered(entry.name or entry.id)
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

    local index = 1
    local rows = math.ceil(#entries/lineWrap)
    for row = 0, rows-1 do
        local _lineWrap = math.min(#entries-lineWrap*row, lineWrap)
        local lineWidth = _lineWrap*entrySize.x+style.ItemSpacing.x*(_lineWrap-1)
        im.SetCursorPosX(im.GetWindowWidth()/2 - lineWidth/2)
        for column=1, _lineWrap do
            if setBgAlpha then
                im.SetNextWindowBgAlpha(0.6)
            end
            if index == selectedItem then
                im.PushStyleColor1(im.Col_Border, im.GetColorU321(im.Col_Button))
            end

            im.BeginChild1("##zeitRenderSettingsWindowSelector"..entries[index]..index, entrySize, true)
            renderEntry(index)
            if im.IsWindowHovered() then
                im.SetMouseCursor(im.MouseCursor_Hand)
                if im.IsMouseClicked(0) then
                    launchWindow(index)
                    queueUIToggle = true
                end
            end
            im.EndChild()
            if index == selectedItem then
                im.PopStyleColor()
            end
            if column ~= _lineWrap then
                im.SameLine()
            end
            index = index + 1
        end
    end

    if zeit_rcUI_settings then
        im.PushStyleVar1(im.StyleVar_Alpha, 0.35)

        local tableColumns = math.min(#buttons, lineWrap)
        local tblAmount = #buttons%tableColumns
        local tableWidths = im.GetContentRegionAvailWidth()*0.75+(style.ColumnsMinSpacing*5*tableColumns)

        local buttonIndex = 1
        for tableIndex=0, tblAmount do
            local buttonCount = math.min(#buttons-lineWrap*tableIndex, lineWrap)
            im.SetCursorPosX(im.GetCursorPosX()+im.GetContentRegionAvailWidth()/2-tableWidths/2)
            if im.BeginTable("##zeitRenderSettingsSelectUtilButtons"..tableIndex, buttonCount, im.TableFlags_SizingStretchSame, im.ImVec2(tableWidths, im.GetTextLineHeight())) then
                for _=1, buttonCount do
                    im.TableNextColumn()
                    buttons[buttonIndex]()
                    buttonIndex = buttonIndex + 1
                end

                im.EndTable()
            end
        end
        im.PopStyleVar()
    end
    im.PopFont()

    widgets.blurUpdate("zeitRenderSettingsWindowSelector")
    im.End()

    im.PopStyleVar()
    im.PopStyleVar()

    if queueUIToggle then
        toggleUI()
        queueUIToggle = false
    end
end

local function onUpdate(dtReal)
    if M.showUI == false then return end
    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err..debug.traceback())
    end

    style.pop()
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
    if M.showUI then
        toggleUI()
    end
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.primary = primary
M.secondary = secondary
M.addEntry = addEntry
M.loadEntries = loadEntries

return M