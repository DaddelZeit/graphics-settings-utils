-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local widgets = require("zeit/rcUI/editWidgets")

local name = im.ArrayChar(256)
local style = require("zeit/rcTool/style")
local state = 0
local currentCallbackFunc = dump
local selectedDropdownItem = "Select Profile..."
local dropDownItems = {}
local showUI = false

local function render()
    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextFrameWantCaptureMouse(true)
    im.SetNextFrameWantCaptureKeyboard(true)
    im.ImDrawList_AddRectFilled(im.GetBackgroundDrawList1(), mainPort.Pos, mainPort.Size, im.GetColorU322(im.ImVec4(0,0,0,0.5)), 0)

    im.SetNextWindowPos(pos, nil, im.ImVec2(0.5, 0.5))
    im.Begin("zeitRenderSettingsLoaderProfileDialog", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.SetCursorPosX(im.GetContentRegionAvailWidth()-im.CalcTextSize("X").x-style.FramePadding.x*2)
    if widgets.button("X") then
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
        if widgets.button("Done") then
            if FS:fileExists(zeit_rcMain.constructProfilePath(ffi.string(name))) then
                state = 2
                zeit_rcMain.log("I", "", "profile "..ffi.string(name).." exists, redirecting...")
            else
                currentCallbackFunc(ffi.string(name))
                showUI = false
            end
        end
        im.SameLine()
        if widgets.button("Cancel") then
            showUI = false
        end
    elseif state == 1 then
        im.PushFont3("cairo_semibold_large")
        im.Text("Select a profile to load.")
        im.PopFont()

        if im.BeginCombo("##ProfileLoadSelector", selectedDropdownItem) then
            for _,v in ipairs(dropDownItems) do
                if im.Selectable1(v, v == selectedDropdownItem) then
                    selectedDropdownItem = v
                end
            end
            im.EndCombo()
        end
        im.Text("")
        if widgets.button("Done") then
            if selectedDropdownItem ~= "Select Profile..." then
                currentCallbackFunc(selectedDropdownItem)
            end
            showUI = false
        end
        im.SameLine()
        if widgets.button("Cancel") then
            showUI = false
        end
    elseif state == 2 then
        im.PushFont3("cairo_semibold_large")
        im.Text("File already exists. Overwrite?")
        im.PopFont()

        im.Text("")
        if widgets.button("Yes") then
            currentCallbackFunc(ffi.string(name))
            showUI = false
        end
        im.SameLine()
        if widgets.button("No") then
            showUI = false
            zeit_rcMain.log("I", "", "save cancelled")
        end
    elseif state == 3 then
        im.PushFont3("cairo_semibold_large")
        im.Text("Delete profile? This cannot be undone.")
        im.PopFont()

        im.Text("")
        if widgets.button("Yes") then
            currentCallbackFunc(ffi.string(name))
            showUI = false
        end
        im.SameLine()
        if widgets.button("No") then
            showUI = false
            zeit_rcMain.log("I", "", "delete cancelled")
        end
    end
    im.Separator()
    im.Text("")
    im.End()
end

local function onUpdate()
    if not showUI then return end

    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()
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
            table.insert(dropDownItems, str)
        end
        state = 1
        currentCallbackFunc = callbackFunc or dump
        showUI = true
    end
end

local function deleteDialog(callbackFunc, newname)
    if not showUI then
        state = 3
        currentCallbackFunc = callbackFunc or dump
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