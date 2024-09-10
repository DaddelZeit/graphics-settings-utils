-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local im = ui_imgui
local widgets = require("zeit/rcUI/editWidgets")

local style = require("zeit/rcTool/style")
local currentCallbackFunc = dump
local showUI = false

local unloadQueued = false
local progressSmoother = newTemporalSigmoidSmoothing(10, 40)
local active = 0
local progress = 0
local text = ""
local callbacks = {
    progress = function(a,b)
        progress = a
        text = b
    end,
    finished = function()
        active = 2
    end
}

local function toggleUI(show, func)
    showUI = show
    currentCallbackFunc = func or dump
end

local function render(dt)
    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextFrameWantCaptureMouse(true)
    im.SetNextFrameWantCaptureKeyboard(true)

    im.ImDrawList_AddRectFilled(im.GetBackgroundDrawList1(), mainPort.Pos, mainPort.Size, im.GetColorU322(im.ImVec4(0,0,0,0.5)), 0)

    im.SetNextWindowPos(pos, nil, im.ImVec2(0.5, 0.5))
    im.Begin("Zeit's Graphics Utils: Remove", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.Text("")
    im.Separator()

    im.PushFont3("cairo_semibold_large")
    im.Text("Remove all remnants")
    im.PopFont()

    if active == 0 then
        im.Text("Would you like to remove all parts of \"Zeit's graphics settings utils\"?")
        im.Text("")

        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Yes").x-im.CalcTextSize("No").x-style.ItemSpacing.x*3-style.ItemInnerSpacing.x*4-style.WindowPadding.x)
        im.PushStyleColor2(im.Col_Button, im.ImVec4(1,0.25,0.2,1))
        if widgets.button("Yes") then
            core_jobsystem.wrap(function(job)
                active = 1
                currentCallbackFunc(callbacks, job)
                active = 2
            end)()
        end
        im.PopStyleColor()
        im.SameLine()
        if widgets.button("No") then
            showUI = false
        end
    elseif active == 1 then
        im.ProgressBar(progressSmoother:get(progress, dt), im.ImVec2(im.GetContentRegionAvailWidth(), im.CalcTextSize("").y*2+style.ItemSpacing.y*0.75), text)

        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Close").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
        im.BeginDisabled()
        widgets.button("Close")
        im.EndDisabled()
    else
        im.ProgressBar(progressSmoother:get(progress, dt), im.ImVec2(im.GetContentRegionAvailWidth(), im.CalcTextSize("").y*2+style.ItemSpacing.y*0.75), text)

        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Close").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
        if widgets.button("Close") then
            showUI = false
            unloadQueued = true
        end
    end

    im.Separator()
    im.Text("")
    im.End()
end

local function onUpdate(dtReal)
    if not showUI then return end

    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()

    if unloadQueued then
        unloadQueued = false
        extensions.unload(M.__extensionName__)
    end
end

M.toggleUI = toggleUI
M.onUpdate = onUpdate

return M