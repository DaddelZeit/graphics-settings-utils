-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")

local spinner = imguiUtils.texObj("/settings/zeit/rendercomponents/spinner/spinner.png")

local setBgAlpha = false

local uv1, uv2, uv3, uv4 = im.ImVec2(0, 0), im.ImVec2(1, 0), im.ImVec2(1, 1), im.ImVec2(0, 1)

local function ImRotate(v, cosA, sinA)
    v:set(v.x * cosA - v.y * sinA, v.x * sinA + v.y * cosA, 0)
    return v
end

local function ImageRotated(texId, size, angle, color)
    local drawlist = im.GetWindowDrawList()
    local center = vec3(im.GetCursorScreenPos().x+size.x/2, im.GetCursorScreenPos().y+size.y/2)
    im.Dummy(im.ImVec2(size.x, size.y))

    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    local pos = {
        center + ImRotate(vec3(-size.x * 0.5, -size.y * 0.5, 0), cosA, sinA),
        center + ImRotate(vec3( size.x * 0.5, -size.y * 0.5, 0), cosA, sinA),
        center + ImRotate(vec3( size.x * 0.5,  size.y * 0.5, 0), cosA, sinA),
        center + ImRotate(vec3(-size.x * 0.5,  size.y * 0.5, 0), cosA, sinA)
    }

    im.ImDrawList_AddImageQuad(drawlist, texId,
        im.ImVec2(pos[1].x, pos[1].y), im.ImVec2(pos[2].x, pos[2].y), im.ImVec2(pos[3].x, pos[3].y), im.ImVec2(pos[4].x, pos[4].y),
        uv1, uv2, uv3, uv4, color)
end

local angle = 0
local function render(dt, setting)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.6)
    end

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x*0.033),
        mainPort.Pos.y + (mainPort.Size.y*0.033))
    im.SetNextWindowPos(pos, nil, im.ImVec2(0, 0))

    im.PushStyleVar1(im.StyleVar_WindowBorderSize, 0)
    im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(50,25))
    im.Begin("zeitRenderSettingsLoadingSpinner", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoMove + im.WindowFlags_NoResize + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse + im.WindowFlags_AlwaysAutoResize)

    angle = (angle+dt*15)%(math.pi*4)

    if setting == 1 or setting == 3 then
        ImageRotated(spinner.texId, im.ImVec2(64,64), angle, im.GetColorU321(im.Col_Button, 0.75))
    end

    if setting > 1 then
        im.PushFont3("cairo_semibold_large")
        im.SameLine()
        local cursorPosY = im.GetWindowHeight()/2-im.CalcTextSize("").y/2
        im.SetCursorPosX(im.GetCursorPosX()+im.CalcTextSize("--").x)
        im.SetCursorPosY(cursorPosY)
        im.Text("Applying Profile")
        im.SameLine()
        im.SetCursorPosY(cursorPosY)

        local i = angle/math.pi

        if i < 1 then
            im.Text("   ")
        elseif i < 2 then
            im.Text(".  ")
        elseif i < 3 then
            im.Text(".. ")
        else
            im.Text("...")
        end
        im.PopFont()
    end

    im.End()
    im.PopStyleVar()
    im.PopStyleVar()
end

local function onUpdate(dtReal)
    if not zeit_rcMain or not zeit_rcMain.isApplying then return end
    local setting = settings.getValue("zeit_graphics_apply_spinner", 0)
    if setting == 0 then return end
    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal, setting)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M