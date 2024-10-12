-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")
local api = rerequire("zeit/rcTool/colorCorrectionExport")

local rampChanged
local colorrampSavePath = zeit_rcMain.profilePath.."colorramps/"
local colorrampSaves = {}
local colorrampIndex = 0

local autoApply = im.BoolPtr(settingsManager.get("color_correction_auto_apply"))
local exportName = im.ArrayChar(256)
ffi.copy(exportName, "Neutral")

local points = {
    api.createPoint(0, {0, 0, 0}),
    api.createPoint(256, {1, 1, 1}),
}
local markerPos = im.GetColorU322(im.ImVec4(1,1,1,1))

local viewportPadding = im.ImVec2(7.5, 5)
local viewportScale = im.ImVec2(3, 75)

M.showUI = false

local function refreshColorrampCache()
    for k,v in ipairs(FS:findFiles(colorrampSavePath, "*.colorramp.json", 0, false, false)) do
        colorrampSaves[k] = v:match("^.+/(.+)")
    end
end

local function toggleUI(...)
    widgets.blurRemove("zeitRenderSettingsColorCorrectionEditor")
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)

    if not M.showUI then
        zeit_rc_rendercomponents.saveSettingTemp("colorCorrectionRampPath")
    else
        refreshColorrampCache()
    end
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

local function renderViewportBackground(cursorPos)
    for i = 1, #points-1 do
        local point0 = points[i]
        local point1 = points[i+1]

        im.ImDrawList_AddRectFilledMultiColor(im.GetWindowDrawList(),
            im.ImVec2(cursorPos.x + point0.x*viewportScale.x, cursorPos.y),
            im.ImVec2(cursorPos.x + point1.x*viewportScale.x, cursorPos.y + viewportScale.y),
            point0.u32, point1.u32, point1.u32, point0.u32)
    end
end

local draggingMarker
local hoveringMarker
local function renderMarkers(cursorPos, viewportSize)
    local startingCursorPos = im.GetCursorPos()
    local itemSize = im.GetItemRectSize()

    local contextOpen = im.IsPopupOpen("Color Correction Editor Context")
    hoveringMarker = contextOpen and hoveringMarker or nil

    for i = 1, #points do
        local point = points[i]

        local xpos = point.x*viewportScale.x
        local bottomPos = viewportScale.y
        im.ImDrawList_AddLine(im.GetWindowDrawList(),
            im.ImVec2(cursorPos.x + xpos, cursorPos.y),
            im.ImVec2(cursorPos.x + xpos, cursorPos.y + bottomPos),
            markerPos, 1)

        local colorCursorPos = im.ImVec2(startingCursorPos.x+xpos-itemSize.y/2, startingCursorPos.y+bottomPos/2-itemSize.y/2)
        im.SetCursorPos(colorCursorPos)
        if im.ColorEdit3("##color_correction_editor_point_i"..i, point.color, im.ColorEditFlags_NoInputs+im.ColorEditFlags_NoDragDrop) then
            point.u32 = im.GetColorU322(im.ImVec4(point.color[0], point.color[1], point.color[2], 1))
            point.rgb = {point.color[0]*255, point.color[1]*255, point.color[2]*255}

            rampChanged = true
        end
        im.SameLine()

        local setCursor = false
        local rectBoundsTL = im.ImVec2(colorCursorPos.x+im.GetWindowPos().x, colorCursorPos.y+im.GetWindowPos().y)

        if i > 1 and i < #points then
            if i == draggingMarker then
                setCursor = true
                local delta = im.GetMouseDragDelta()
                point.x = clamp(point.x+(delta.x/viewportScale.x), 0, 256)
                rampChanged = true

                if points[i-1] and points[i-1].x > point.x then
                    drag(points, i, 1, i-1)
                    draggingMarker = draggingMarker - 1
                elseif points[i+1] and points[i+1].x < point.x then
                    drag(points, i, 1, i+1)
                    draggingMarker = draggingMarker + 1
                end

                im.ResetMouseDragDelta()

                if im.IsMouseReleased(0) then
                    draggingMarker = nil
                end
            elseif not draggingMarker and im.IsMouseHoveringRect(rectBoundsTL, im.ImVec2(rectBoundsTL.x+itemSize.y, rectBoundsTL.y+itemSize.y)) then
                setCursor = true
                if im.IsMouseDragging(0) then
                    draggingMarker = i
                end
                if not contextOpen then
                    hoveringMarker = i
                end
            end
        end

        if setCursor then
            im.SetMouseCursor(im.MouseCursor_ResizeEW)
        end
    end
    im.SetCursorPos(startingCursorPos)

    if (im.IsMouseHoveringRect(cursorPos, im.ImVec2(cursorPos.x+viewportSize.x, cursorPos.y+viewportSize.y)) or contextOpen) and im.BeginPopupContextWindow("Color Correction Editor Context") then
        if hoveringMarker then
            if im.Selectable1("Delete") then
                rampChanged = true
                table.remove(points, hoveringMarker)
                hoveringMarker = nil
            end
        else
            if im.Selectable1("Add") then
                local x = (im.GetWindowPos().x-cursorPos.x)/viewportScale.x
                for i = 1, #points do
                    local point = points[i]
                    if x <= point.x then
                        local newPoint = api.createPoint()
                        newPoint.x = x
                        newPoint.rgb = api.getInterpolation(points[i-1], points[i], x)

                        newPoint.u32 = im.GetColorU322(im.ImVec4(newPoint.rgb[1]/255, newPoint.rgb[2]/255, newPoint.rgb[3]/255, 1))
                        newPoint.color[0] = newPoint.rgb[1]/255
                        newPoint.color[1] = newPoint.rgb[2]/255
                        newPoint.color[2] = newPoint.rgb[3]/255
                        rampChanged = true
                        table.insert(points, i, newPoint)
                        break
                    end
                end
            end
        end
        im.EndPopup()
    end
end

local function renderViewport()
    im.SetCursorPosX(im.GetCursorPosX()+viewportPadding.x)
    im.SetCursorPosY(im.GetCursorPosY()+viewportPadding.y)

    local cursorPos = im.GetCursorScreenPos()
    local viewportSize = im.ImVec2(256*viewportScale.x, viewportScale.y+viewportPadding.y)
    renderViewportBackground(cursorPos)
    renderMarkers(cursorPos, viewportSize)

    im.Dummy(im.ImVec2(viewportSize.x+viewportPadding.x, viewportSize.y+viewportPadding.y))
end

local function export()
    local name = ffi.string(exportName)
    api.export("/art/postFx/"..name..".png", points)
    api.save(colorrampSavePath..ffi.string(exportName)..".colorramp.json", points)
    refreshColorrampCache()
    Engine.Platform.exploreFolder("/art/postFx/"..name..".png")
end

local function tempUpdate()
    local path = "/temp/art/postFx/"..ffi.string(exportName)..".png"
    api.export(path, points)
    if zeit_rc_rendercomponents then
        zeit_rc_rendercomponents.saveSettingTemp("colorCorrectionRampPath", path)
    end
    rampChanged = false
end

local function renderMenuBar()
    im.BeginMenuBar()

    if im.BeginMenu("Save") then
        if im.MenuItem1("Save as \""..ffi.string(exportName).."\"") then
            api.save(colorrampSavePath..ffi.string(exportName)..".colorramp.json", points)
            refreshColorrampCache()
        end
        im.EndMenu()
    end
    if im.BeginMenu("Load") then
        for k,v in ipairs(colorrampSaves) do
            if im.Selectable1(v, k == colorrampIndex) then
                local file = ""
                points, file = api.load(colorrampSavePath..colorrampSaves[k])
                ffi.copy(exportName, file)
                colorrampIndex = k
                tempUpdate()
            end
        end
        im.EndMenu()
    end

    im.EndMenuBar()
end

local function render(dt)
    local isOpen = im.BoolPtr(true)
    im.Begin("Zeit's Graphics Utils: Color Correction Editor", isOpen, im.WindowFlags_AlwaysAutoResize + im.WindowFlags_MenuBar)
    renderMenuBar()

    --im.PushFont3("cairo_bold")
    --widgets.textCentered("Zeit's Graphics Utils: Window Selector")
    --im.PopFont()

    renderViewport()

    im.InputText("Color Ramp Name", exportName)

    if widgets.button("Export to PNG") then
        export()
    end
    im.SameLine()

    if im.Checkbox("Automatically apply changes", autoApply) then
        settingsManager.set("color_correction_auto_apply", autoApply[0])
    end
    if rampChanged and autoApply[0] then
        tempUpdate()
    end

    widgets.blurUpdate("zeitRenderSettingsColorCorrectionEditor")
    im.End()

    if not isOpen[0] then
        toggleUI()
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
M.toggleUI = toggleUI

return M