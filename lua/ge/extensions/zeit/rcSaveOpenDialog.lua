-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local im = ui_imgui
local name = im.ArrayChar(256)
local imguiUtils = require("ui/imguiUtils")
local state = 0
local currentCallbackFunc = dump
local selectedDropdownItem = "Click here..."
local dropDownItems = {}
local showUI = false

local function onUpdate()
    if not showUI then return end

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextWindowPos(mainPort.Pos)
    im.SetNextWindowSize(mainPort.Size)
    im.Begin("zeitRenderSettingsLoaderProfileDialogBG", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_NoBackground + im.WindowFlags_NoBringToFrontOnFocus + im.WindowFlags_NoMouseInputs)
    im.ImDrawList_AddRectFilled(im.GetBackgroundDrawList1(), mainPort.Pos, mainPort.Size, im.GetColorU322(im.ImVec4(0,0,0,0.5)), 0)
    im.End()

    im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))
    im.Begin("zeitRenderSettingsLoaderProfileDialog", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.SetCursorPosX(im.GetWindowSize().x-27)
    if im.Button("X") then
        showUI = false
    end
    im.SetCursorPosX(0)

    im.Separator()
    if state == 0 then
        im.PushFont3("cairo_semibold_large")
        im.Text("Enter a name for your profile.")
        im.PopFont()
        im.InputText("###NewProfileName", name)
        im.Text("")
        if im.Button("Done") then
            if FS:fileExists(zeit_rcMain.constructProfilePath(ffi.string(name))) then
                state = 2
            else
                currentCallbackFunc(ffi.string(name))
                zeit_rcProfileManager.refreshCache()
                showUI = false
            end
        end
    elseif state == 1 then
        im.PushFont3("cairo_semibold_large")
        im.Text("Select a profile to load.")
        im.PopFont()

        imguiUtils.DropdownButton(ffi.string(selectedDropdownItem), im.ImVec2(100,30), dropDownItems)
        im.Text("")
        if im.Button("Done") then
            if selectedDropdownItem ~= "Click here..." then
                currentCallbackFunc(ffi.string(selectedDropdownItem))
                zeit_rcProfileManager.refreshCache()
            end
            showUI = false
        end
    elseif state == 2 then
        im.PushFont3("cairo_semibold_large")
        im.Text("File already exists. Overwrite?")
        im.PopFont()

        im.Text("")
        if im.Button("Yes") then
            currentCallbackFunc(ffi.string(name))
            zeit_rcProfileManager.refreshCache()
            showUI = false
        end
        im.SameLine()
        if im.Button("No") then
            showUI = false
        end
    elseif state == 3 then
        im.PushFont3("cairo_semibold_large")
        im.Text("Delete profile? This cannot be undone.")
        im.PopFont()

        im.Text("")
        if im.Button("Yes") then
            local path = zeit_rcMain.constructProfilePath(ffi.string(name))
            FS:removeFile(path:gsub(".profile.json", ".info.json"))
            FS:removeFile(path:gsub(".profile.json", ".preview.png"))
            FS:removeFile(path:gsub(".profile.json", ".preview.jpg"))
            FS:removeFile(path)
            zeit_rcProfileManager.refreshCache()
            showUI = false
        end
        im.SameLine()
        if im.Button("No") then
            showUI = false
        end
    end
    im.Separator()
    im.Text("")
    im.End()
end

local function saveDialog(callbackFunc, newname)
    if not showUI then
        state = 0
        currentCallbackFunc = callbackFunc or dump
        showUI = true
        name = im.ArrayChar(256)
        ffi.copy(name, newname or "")
    end
end

local function loadDialog(callbackFunc)
    if not showUI then
        selectedDropdownItem = "Click here..."
        dropDownItems = {}
        for _,v in ipairs(zeit_rcMain.getAllProfiles()) do
            local str = split(v, "/")
            str = str[#str]:gsub("%..+", "")
            table.insert(dropDownItems, imguiUtils.DropdownItem(str, nil, function() selectedDropdownItem = str end))
        end
        state = 1
        currentCallbackFunc = callbackFunc or dump
        showUI = true
    end
end

local function deleteDialog(newname)
    if not showUI then
        state = 3
        currentCallbackFunc = dump
        showUI = true
        name = im.ArrayChar(256)
        ffi.copy(name, newname or "")
    end
end

M.saveDialog = saveDialog
M.loadDialog = loadDialog
M.deleteDialog = deleteDialog
M.onUpdate = onUpdate

return M