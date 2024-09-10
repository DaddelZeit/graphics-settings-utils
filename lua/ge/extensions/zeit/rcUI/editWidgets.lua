-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local C = ffi.C

local im = ui_imgui
local emptyVec = im.ImVec2(0,0)

local undoImage = im.ImTextureHandler("/settings/zeit/rendercomponents/edit/undo.png")
local undoSize = undoImage:getSize().y

local function horizontalSeparator(height)
    local cursorPos = im.GetCursorScreenPos()
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), cursorPos, im.ImVec2(cursorPos.x+1, cursorPos.y+height), im.GetColorU321(im.Col_SeparatorHovered), 0, 0)
    im.Dummy(im.ImVec2(1,0))
end
M.horizontalSeparator = horizontalSeparator

local function resizeFont(scale)
    local scaledFont = im.GetFont()
    local prevSize = scaledFont.Scale
    scaledFont.Scale = scale
    im.PushFont(scaledFont)
    scaledFont.Scale = prevSize
end
M.resizeFont = resizeFont

local function imageButton(string_str_id, ImTextureID_user_texture_id, ImVec2_size, ImVec2_uv0, ImVec2_uv1, ImVec4_bg_col, ImVec4_tint_col)
    if string_str_id == nil then return end
    local retVal = C.imgui_ImageButton1(string_str_id, ImTextureID_user_texture_id, ImVec2_size, ImVec2_uv0 or im.ImVec2(0,0), ImVec2_uv1 or im.ImVec2(1,1), ImVec4_bg_col or im.ImVec4(0,0,0,0), ImVec4_tint_col or im.ImVec4(1,1,1,1))
    if im.IsItemHovered() then
        im.SetMouseCursor(im.MouseCursor_Hand)
    end
    return retVal
end
M.imageButton = imageButton

local function button(label, size)
    if label == nil then return end
    C.imgui_PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(6,2))
    local retVal = C.imgui_Button(label, size or im.ImVec2(0,0))
    C.imgui_PopStyleVar(1)
    if im.IsItemHovered() then
        im.SetMouseCursor(im.MouseCursor_Hand)
    end
    return retVal
end
M.button = button

local function textCentered(text)
    local windowWidth = im.GetWindowSize().x
    local textWidth   = im.CalcTextSize(text).x

    im.SetCursorPosX((windowWidth - textWidth)/2)
    im.Text(text)
end
M.textCentered = textCentered

local function tooltipButton(inp)
    inp = inp or {}
    im.PushStyleColor1(im.Col_ButtonActive, im.GetColorU321(im.Col_ButtonHovered))
    C.imgui_PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(6,2))
    C.imgui_Button("?", emptyVec)
    C.imgui_PopStyleVar(1)
    im.PopStyleColor()
    if im.IsItemHovered() then
        im.BeginTooltip()
        resizeFont(1.25)
        if inp.desc then im.Text(inp.desc) end
        im.PopFont()
        if inp.default then im.Text("Default: "..inp.default) end
        if inp.varName then im.Text("Variable Name: "..inp.varName) end
        if inp.varType then im.Text("Variable Type: "..inp.varType) end
        if inp.key then im.Text("Key: "..inp.key) end
        im.EndTooltip()
    end
end
M.tooltipButton = tooltipButton

local resetButton
if undoSize == 0 then
    resetButton = function(id)
        return button("Reset##"..id)
    end
else
    local btnSize = im.CalcTextSize("").y*1.1
    local buttonSize = im.ImVec2(btnSize,btnSize)
    resetButton = function(id)
        return imageButton(id, undoImage:getID(), buttonSize)
    end
end
M.resetButton = resetButton

local function renderIntGeneral(id, value, min, max, format)
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = value.default,
        varName = id,
        varType = "int"
    })
    im.SameLine()
    local disabled = zeit_rc_generaleffects and zeit_rc_generaleffects.isNil(id) or false
    if disabled then im.BeginDisabled() end
    if resetButton(id) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, nil) end
    end
    if disabled then im.EndDisabled() end
    im.SameLine()
    local lastAction = value.active
    if im.SliderInt(value.name or ("##"..id), value.ptr, min, max, format, 0) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0]) end
    end
    value.active = im.IsItemActive()

    return not value.active and lastAction
end
M.renderIntGeneral = renderIntGeneral

local function renderFloatGeneral(id, value, min, max, format)
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = value.default,
        varName = id,
        varType = "float"
    })
    im.SameLine()
    local disabled = zeit_rc_generaleffects and zeit_rc_generaleffects.isNil(id) or false
    if disabled then im.BeginDisabled() end
    if resetButton(id) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, nil) end
    end
    if disabled then im.EndDisabled() end
    im.SameLine()
    local lastAction = value.active
    if im.SliderFloat(value.name or ("##"..id), value.ptr, min, max, format, 0) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0]) end
    end
    value.active = im.IsItemActive()
    return not value.active and lastAction
end
M.renderFloatGeneral = renderFloatGeneral

local function renderCheckboxGeneral(id, value, min, max)
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = tostring(value.default),
        varName = id,
        varType = "bool"
    })
    im.SameLine()
    local disabled = zeit_rc_generaleffects and zeit_rc_generaleffects.isNil(id) or false
    if disabled then im.BeginDisabled() end
    if resetButton(id) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, nil) end
    end
    if disabled then im.EndDisabled() end
    im.SameLine()
    local lastAction = value.active
    if im.Checkbox(value.name or ("##"..id), value.ptr) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0] and (max or 1) or (min or 0)) end
    end
    value.active = im.IsItemActive()
    return not value.active and lastAction
end
M.renderCheckboxGeneral = renderCheckboxGeneral



local function renderIntGeneric(id, tooltip, val, applyFunc, resetFunc)
    tooltipButton(tooltip)
    im.SameLine()
    if resetFunc then
        if val.resetDisabled then im.BeginDisabled() end
        if resetButton(id) then
            resetFunc()
        end
        if val.resetDisabled then im.EndDisabled() end
        im.SameLine()
    end
    if im.SliderInt(val.name.."##"..(id or "placeholder"), val.ptr, val.min, val.max, val.format) then
        (applyFunc or nop)()
    end
end
M.renderIntGeneric = renderIntGeneric

local function renderFloatGeneric(id, tooltip, val, applyFunc, resetFunc)
    tooltipButton(tooltip)
    im.SameLine()
    if resetFunc then
        if val.resetDisabled then im.BeginDisabled() end
        if resetButton(id) then
            resetFunc()
        end
        if val.resetDisabled then im.EndDisabled() end
        im.SameLine()
    end
    if im.SliderFloat(val.name.."##"..(id or "placeholder"), val.ptr, val.min, val.max, val.format) then
        (applyFunc or nop)()
    end
end
M.renderFloatGeneric = renderFloatGeneric

local function renderCheckboxGeneric(id, tooltip, val, applyFunc, resetFunc)
    tooltipButton(tooltip)
    im.SameLine()
    if resetFunc then
        if val.resetDisabled then im.BeginDisabled() end
        if resetButton(id) then
            resetFunc()
        end
        if val.resetDisabled then im.EndDisabled() end
        im.SameLine()
    end
    if im.Checkbox(val.name.."##"..(id or "placeholder") or ("##"..id), val.ptr) then
        (applyFunc or nop)()
    end
end
M.renderCheckboxGeneric = renderCheckboxGeneric

return M