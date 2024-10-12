-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")
local exportModule = require("zeit/rcTool/export")

local undoImage = im.ImTextureHandler("/settings/zeit/rendercomponents/edit/undo.png")
local redoImage = im.ImTextureHandler("/settings/zeit/rendercomponents/edit/redo.png")

M.showUI = false

local SSAOContrast = im.FloatPtr(0)
local SSAORadius = im.FloatPtr(0)
local SSAOHighQuality = false

local GeneralEffectsEntryKeyNew = im.ArrayChar(256)

local generalEffectsKeysReplaced
local generalEffectsValues = {}
local generalEffectsKeys = {}
local generalEffectsKeysSorted = {}
local generalEffectsAvailableKeys = {}

local typeMatchFill = {
    float = function(ptr, v) ptr[0] = tonumber(v) end,
    int = function(ptr, v) ptr[0] = tonumber(v) end,
    bool = function(ptr, v) ptr[0] = v end,
    str = function(ptr, v) ffi.copy(ptr, tostring(v)) end,
}
local typeMatchRender = {
    float = function(name, ptr, min, max, format)
        local prev = ptr[0]
        im.SliderFloat(name, ptr, min or 0, max or 1, format or "%.3f", 0)
        return ptr[0], ptr[0] ~= prev
    end,
    int = function(name, ptr, min, max, format)
        local prev = ptr[0]
        im.SliderInt(name, ptr, min or 0, max or 1, format or "%d", 0)
        return ptr[0], ptr[0] ~= prev
    end,
    bool = function(name, ptr, min, max)
        local prev = ptr[0]
        im.Checkbox(name, ptr)
        local new = ptr[0] and (max or 1) or (min or 0)
        return new, new ~= prev
    end,
    str = function(name, ptr)
        local prev = ffi.string(ptr)
        im.InputText(name, ptr)
        local new = ffi.string(ptr)
        return new, new ~= prev
    end,
}

local autofocusCheckbox = im.BoolPtr(false)
local autofocusVehicleCheckbox = im.BoolPtr(true)

local letterboxOverride = 0
local dofState = {
    "Force Off",
    "Force On",
    "Use Game Setting"
}
local dofVals = {
    IsEnabled = "2",
    FarBlurMax = im.FloatPtr(0),
    FarSlope = im.FloatPtr(0),
    FocalDist = 0,
    LerpBias = ffi.new("float[4]", {0, 0, 0, 0}),
    LerpScale = ffi.new("float[4]", {0, 0, 0, 0}),
    MaxRange = im.FloatPtr(0),
    MinRange = im.FloatPtr(0),
    NearBlurMax = im.FloatPtr(0),
    NearSlope = im.FloatPtr(0),
    Debug = im.BoolPtr(false)
}

local colorCorrectionPrefix = "/art/postfx/"
local colorCorrectionRampIndex = 0
local colorCorrectionRamps = {
    [0] = "None"
}
local hdrVals = {
    colorCorrectionRampPath = "",
    colorCorrectionStrength = im.FloatPtr(1),
}
local uiFpsValue = im.IntPtr(30)
local queueEditorOpen = false

local customPFXVals = {
    ContrastPFX = im.BoolPtr(0),
    ContrastPFXValue = im.FloatPtr(1),
    SaturationPFXValue = im.FloatPtr(1),
    VibrancePFXValue = im.FloatPtr(0),
    VibranceBalancePFX = ffi.new("float[3]", {1, 1, 1}),

    VignettePFX = im.BoolPtr(0),
    VmaxPFXValue = im.FloatPtr(0),
    VminPFXValue = im.FloatPtr(0),
    ColorPFX = ffi.new("float[3]", {0, 0, 0}),

    SharpnessPFX = im.BoolPtr(0),
    SharpnessPFXValue = im.FloatPtr(0),

    FilmgrainPFX = im.BoolPtr(0),
    FilmgrainPFXIntensityValue = im.FloatPtr(0),
    FilmgrainPFXVarianceValue = im.FloatPtr(0),
    FilmgrainPFXMeanValue = im.FloatPtr(0),
    FilmgrainPFXSignalToNoiseRatioValue = im.FloatPtr(0),

    LetterboxPFX = im.BoolPtr(0),
    HeightPFXValue = im.FloatPtr(0),
    WidthPFXValue = im.FloatPtr(0),
    LetterboxColorPFX = ffi.new("float[3]", {0, 0, 0}),

    ChromaticAbberationPFX = im.BoolPtr(0),
    DistCoefficient = im.FloatPtr(0),
    CubeDistortionFactor = im.FloatPtr(0),
    ColorDistortionFactor = ffi.new("float[3]", {0, 0, 0}),
}

local shadowVals = {
    Active = im.BoolPtr(1),
    TexSizeValue = im.IntPtr(32),
    OverDarkValue = ffi.new("float[4]", {0, 0, 0, 0}),
    ShadowDistanceValue = im.FloatPtr(1500),
    ShadowSoftnessValue = im.FloatPtr(0.15),
    NumSplitsValue = im.IntPtr(4),
    LogWeightValue = im.FloatPtr(0.996),
    FadeDistanceValue = im.FloatPtr(0),
    LastSplitTerrainOnly = im.BoolPtr(1),
}

local exported = false
local exportTime = 0

local exportedZip = false
local exportZipTime = 0

local imported = false
local importTime = 0

local historySaveTime = 0

local function toggleUI()
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)

    if not M.showUI and zeit_rcMain.currentRollBack > 1 then
        -- save the current history element as the selected profile
        zeit_rcMain.saveProfile(zeit_rcMain.currentProfile, zeit_rcMain.currentSettings)
    end
end

local modules = {
    menubar = function(dtReal)
        im.BeginMenuBar()
        local menuBarHeight = im.GetFont().FontSize + im.GetStyle().FramePadding.y * 2

        local buttonSize = im.CalcTextSize("").y*1.25
        local undo = zeit_rcMain.currentRollBack < zeit_rcMain.maxRollBack
        if not undo then im.BeginDisabled() end
        if widgets.imageButton("##undobtn", undoImage:getID(), im.ImVec2(buttonSize,buttonSize)) then
            zeit_rcMain.undo()
        end
        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text("Undo")
            im.EndTooltip()
        end
        if not undo then im.EndDisabled() end

        local redo = zeit_rcMain.currentRollBack > 1
        if not redo then im.BeginDisabled() end
        if widgets.imageButton("##redobtn", redoImage:getID(), im.ImVec2(buttonSize,buttonSize)) then
            zeit_rcMain.redo()
        end
        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text("Redo")
            im.EndTooltip()
        end
        if not redo then im.EndDisabled() end
        im.SameLine()

        historySaveTime = math.max(historySaveTime - dtReal, 0.2)
        im.TextColored(im.ImVec4(1,1,1,historySaveTime), " History Saved")

        widgets.horizontalSeparator(menuBarHeight)

        if widgets.button("Open Settings") and zeit_rcUI_settings then
            zeit_rcUI_settings.toggleUI()
        end

        widgets.horizontalSeparator(menuBarHeight)

        if im.BeginMenu("Save") then
            if im.MenuItem1("Save Profile") then
                zeit_rcMain.saveCurrentProfileDialog(true)
            end
            if im.MenuItem1("Save Profile As") then
                zeit_rcMain.saveCurrentProfileDialog(false)
            end
            im.EndMenu()
        end
        if im.MenuItem1("Load") then
            zeit_rcMain.loadProfileDialog()
        end

        widgets.horizontalSeparator(menuBarHeight)

        if im.BeginMenu("Export") then
            exportModule.formatSelector()
            if widgets.button("Export to Clipboard") then
                exported = exportModule.exportProfileToClipboard(zeit_rcMain.currentProfile)
                exportTime = 2
            end
            im.SameLine()
            exportModule.infoCheckbox()
            im.Text("This will not export color ramps.")
            if exportTime > 0 then
                if exported then
                    exportTime = math.max(exportTime - dtReal*2, 0)
                    im.TextColored(im.ImVec4(1,1,1,exportTime), "Successfully exported.")
                else
                    im.TextColored(im.ImVec4(1,0.6,0.6,exportTime), "Export failed. See console for details.")
                end
            end

            im.Separator()

            if widgets.button("Export as Mod") then
                local path
                exportedZip, path = exportModule.exportProfileAsMod(zeit_rcMain.currentProfile)
                exportZipTime = 5
                if path then
                    Engine.Platform.exploreFolder(path)
                end
            end
            if exportZipTime > 0 then
                if exportedZip then
                    exportZipTime = math.max(exportZipTime - dtReal*2, 0)
                    im.TextColored(im.ImVec4(1,1,1,exportZipTime), "Successfully exported.")
                else
                    im.TextColored(im.ImVec4(1,0.6,0.6,exportZipTime), "Export failed. See console for details.")
                end
            end
            im.EndMenu()
        else
            exportedZip = false
            exportZipTime = 0
            exported = false
            exportTime = 0
        end

        if im.BeginMenu("Import from Clipboard") then
            if widgets.button("Import") then
                imported = exportModule.importProfileFromClipboard()
                importTime = 2
            end
            if importTime > 0 then
                im.Separator()
                if imported then
                    importTime = math.max(importTime - dtReal*2, 0)
                    im.TextColored(im.ImVec4(1,1,1,importTime), "Successfully imported.")
                else
                    im.TextColored(im.ImVec4(1,0.6,0.6,importTime), "Import failed. See console for details.")
                end
            end
            im.EndMenu()
        else
            imported = false
            importTime = 0
        end

        im.Dummy(im.ImVec2(200, 0))
        im.EndMenuBar()
    end,
    hdr = function()
        im.Text('These settings can be edited using the "Renderer Components" world editor window.')

        if widgets.button("Open Window in World Editor") then
            queueEditorOpen = true
            if editor.isEditorActive() then
                editor.showWindow("rendererComponents")
            end
        end
        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text("This button will open the world editor.")
            im.Text("Click again to show the appropiate window.")
            im.EndTooltip()
        end

        im.PushID1("RenderComponents")
        if widgets.button("Save \"HDR\" and \"Bloom\" Settings") then
            if zeit_rc_rendercomponents then zeit_rc_rendercomponents.getAndSaveSettings() end
        end
        im.NewLine()

        local width = im.GetCursorPosX()
        widgets.tooltipButton({
            desc = "1-dimensional image for basic color correction mapping.",
            default = "None",
            varName = "PostEffectCombinePassObject.colorCorrectionRampPath",
            varType = "string"
        })
        do
            im.SameLine()
            local disabled = colorCorrectionRampIndex == 0
            if disabled then im.BeginDisabled() end
            if widgets.resetButton("ColorCorrectionRampPathReset") then
                if zeit_rc_rendercomponents then zeit_rc_rendercomponents.saveSetting("colorCorrectionRampPath", 0) end
            end
            if disabled then im.EndDisabled() end
            im.SameLine()
            if im.BeginCombo("##ColorCorrectionRampPath", colorCorrectionRamps[colorCorrectionRampIndex] or "") then
                for k = 0, #colorCorrectionRamps do
                    if im.Selectable1(colorCorrectionRamps[k], k == colorCorrectionRampIndex) then
                        if zeit_rc_rendercomponents then
                            colorCorrectionRampIndex = k
                            zeit_rc_rendercomponents.saveSetting("colorCorrectionRampPath", colorCorrectionPrefix..colorCorrectionRamps[k])
                        end
                    end
                end
                im.EndCombo()
            end
            im.SameLine()
            width = im.GetCursorPosX()-width-style.FramePadding.x*3
            im.Text("Color Correction Ramp")
        end

        if zeit_rcUI_colorCorrectionEditor then
            if widgets.button("Create##ColorRamp", im.ImVec2(width, 0)) then
                zeit_rcUI_colorCorrectionEditor.toggleUI()
            end
        end

        widgets.renderFloatGeneric(
            "PostEffectCombinePassObject.colorCorrectionStrength", {
                desc = "Blend strength of the color correction",
                default = "1",
                varName = "PostEffectCombinePassObject.colorCorrectionStrength",
                varType = "float"
            }, {
                name = "Color Correction Strength",
                ptr = hdrVals.colorCorrectionStrength,
                min = 0,
                max = 1,
                format = "%.3f",
                resetDisabled = (hdrVals.colorCorrectionStrength[0] == 1)
            }, function()
                if zeit_rc_rendercomponents then zeit_rc_rendercomponents.saveSetting("colorCorrectionStrength", hdrVals.colorCorrectionStrength[0]) end
            end, function()
                if zeit_rc_rendercomponents then zeit_rc_rendercomponents.saveSetting("colorCorrectionStrength", 1) end
            end)
        im.PopID()
    end,
    ui = function()
        im.PushID1("UISettings")

        widgets.renderIntGeneric(
            "CefGui::maxFPSLimit", {
                desc = "Interface FPS Limiter",
                default = "30",
                varName = "CefGui::maxFPSLimit",
                varType = "int"
            }, {
                name = "Max UI FPS",
                ptr = uiFpsValue,
                min = 1,
                max = 60,
                resetDisabled = (uiFpsValue[0] == 30)
            }, function()
                if zeit_rc_uifps then zeit_rc_uifps.getAndSaveSettings(uiFpsValue[0]) end
            end, function()
                if zeit_rc_uifps then zeit_rc_uifps.getAndSaveSettings(nil) end
            end)

        im.PopID()
    end,
    customPostFx = function()
        local colOverwritten = dofVals.IsEnabled == 0
        if colOverwritten then im.PushStyleColor1(im.Col_Button, im.GetColorU321(im.Col_FrameBg)) end
        if im.BeginCombo("##DepthOfFieldControl", dofState[dofVals.IsEnabled+1], im.ComboFlags_NoPreview) then
            for i = 0, #dofState-1 do
                if im.Selectable1(dofState[i+1], i == dofVals.IsEnabled) then
                    if zeit_rc_dof then zeit_rc_dof.setEnabled(i) end
                end
            end
            im.EndCombo()
        end
        if colOverwritten then im.PopStyleColor() end
        im.SameLine()

        if im.CollapsingHeader1("Depth of Field") then
            im.PushID1("DOFSettings")
            im.Indent()
            im.Indent()

            widgets.renderFloatGeneric(
                "DOFPostEffect.farBlurMax", {
                    desc = "Maximum amount of distance blur",
                    default = "0.15",
                    varName = "DOFPostEffect.farBlurMax",
                    varType = "float"
                }, {
                    name = "Far Blur",
                    ptr = dofVals.FarBlurMax,
                    min = 0,
                    max = 1,
                    format = "%.3f",
                    resetDisabled = (dofVals.FarBlurMax[0] == 0.15)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("farBlurMax", dofVals.FarBlurMax[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("farBlurMax", nil) end
                end)

            widgets.renderFloatGeneric(
                "DOFPostEffect.nearBlurMax", {
                    desc = "Maximum amount of blur in front of focus",
                    default = "0.15",
                    varName = "DOFPostEffect.nearBlurMax",
                    varType = "float"
                }, {
                    name = "Near Blur",
                    ptr = dofVals.NearBlurMax,
                    min = 0,
                    max = 1,
                    format = "%.3f",
                    resetDisabled = (dofVals.NearBlurMax[0] == 0.15)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("nearBlurMax", dofVals.NearBlurMax[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("nearBlurMax", nil) end
                end)

            widgets.renderFloatGeneric(
                "DOFPostEffect.farSlope", {
                    desc = "The far end distance of the slope calculation to affect the blur.",
                    default = "10",
                    varName = "DOFPostEffect.farSlope",
                    varType = "float"
                }, {
                    name = "Far Slope (Aperture)",
                    ptr = dofVals.FarSlope,
                    min = 0,
                    max = 100,
                    format = "%.3f",
                    resetDisabled = (dofVals.FarSlope[0] == 10)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("farSlope", dofVals.FarSlope[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("farSlope", nil) end
                end)

            widgets.renderFloatGeneric(
                "DOFPostEffect.nearSlope", {
                    desc = "The close end distance of the slope calculation to affect the blur.",
                    default = "-20",
                    varName = "DOFPostEffect.nearSlope",
                    varType = "float"
                }, {
                    name = "Near Slope",
                    ptr = dofVals.NearSlope,
                    min = -30,
                    max = 100,
                    format = "%.3f",
                    resetDisabled = (dofVals.NearSlope[0] == -20)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("nearSlope", dofVals.NearSlope[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("nearSlope", nil) end
                end)


            widgets.renderFloatGeneric(
                "DOFPostEffect.maxRange", {
                    desc = "Maximum range of the blur-less focused area. Disable Auto Focus to change this manually.",
                    default = "100",
                    varName = "DOFPostEffect.maxRange",
                    varType = "float"
                }, {
                    name = "Max Range (Focus)",
                    ptr = dofVals.MaxRange,
                    min = 0,
                    max = 100,
                    format = "%.3f",
                    resetDisabled = (dofVals.MaxRange[0] == 100)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("maxRange", dofVals.MaxRange[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("maxRange", nil) end
                end)

            widgets.renderFloatGeneric(
                "DOFPostEffect.minRange", {
                    desc = "Minimum range of the blur-less focused area. Disable Auto Focus to change this manually.",
                    default = "100",
                    varName = "DOFPostEffect.minRange",
                    varType = "float"
                }, {
                    name = "Min Range (Aperture Fine)",
                    ptr = dofVals.MinRange,
                    min = 0,
                    max = 100,
                    format = "%.3f",
                    resetDisabled = (dofVals.MinRange[0] == 100)
                }, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("minRange", dofVals.MinRange[0]) end
                end, function()
                    if zeit_rc_dof then zeit_rc_dof.saveSetting("minRange", nil) end
                end)

            widgets.renderCheckboxGeneric(
                "autofocuscheckbox", {
                    desc = "Automatically adjust focus to the distance of whatever object the camera is looking at.",
                    default = "false",
                    varName = "",
                    varType = "bool"
                }, {
                    name = "Auto Focus",
                    ptr = autofocusCheckbox,
                    resetDisabled = (autofocusCheckbox[0] == false)
                }, function()
                    if zeit_rc_autofocus then zeit_rc_autofocus.toggle(autofocusCheckbox[0], autofocusVehicleCheckbox[0]) end
                end, function()
                    if zeit_rc_autofocus then zeit_rc_autofocus.toggle(false, autofocusVehicleCheckbox[0]) end
                end)

            widgets.renderCheckboxGeneric(
                "autofocusvehiclecheckbox", {
                    desc = "Raycast onto vehicle bounding boxes as well. Can be expensive the more vehicles are spawned.",
                    default = "true",
                    varName = "",
                    varType = "bool"
                }, {
                    name = "Auto Focus on Vehicles",
                    ptr = autofocusVehicleCheckbox,
                    resetDisabled = (autofocusVehicleCheckbox[0] == true)
                }, function()
                    if zeit_rc_autofocus then zeit_rc_autofocus.toggle(autofocusCheckbox[0], autofocusVehicleCheckbox[0]) end
                end, function()
                    if zeit_rc_autofocus then zeit_rc_autofocus.toggle(autofocusCheckbox[0], true) end
                end)

            im.Separator()

            widgets.renderCheckboxGeneric(
                "dofVals.Debug", {
                    desc = "Enable a debug view that visualizes the DOF settings. This does not save.",
                    default = "false",
                    varName = "DOFPostEffect.debugModeEnabled",
                    varType = "bool"
                }, {
                    name = "Debug Display",
                    ptr = dofVals.Debug
                }, function()
                    if scenetree.DOFPostEffect then scenetree.DOFPostEffect.debugModeEnabled = dofVals.Debug[0] end
                    if zeit_rc_autofocus then zeit_rc_autofocus.toggleDebug(dofVals.Debug[0]) end
                end)

            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##ContrastSaturationEnabled", customPFXVals.ContrastPFX) then
            if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.setEnabled(customPFXVals.ContrastPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Contrast/Saturation") then
            im.Indent()
            im.Indent()
            im.PushID1("ContSatSettings")

            widgets.renderFloatGeneric(
                "ContrastSaturationPostFX.Contrast", {
                    desc = "Contrast modifier to add additionally.",
                    default = "1",
                    varName = "ContrastSaturationPostFX.Contrast",
                    varType = "float"
                }, {
                    name = "Contrast",
                    ptr = customPFXVals.ContrastPFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.ContrastPFXValue[0] == 1)
                }, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(nil, customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end)

            widgets.renderFloatGeneric(
                "ContrastSaturationPostFX.Saturation", {
                    desc = "Saturation modifier to add additionally.",
                    default = "1",
                    varName = "ContrastSaturationPostFX.Saturation",
                    varType = "float"
                }, {
                    name = "Saturation",
                    ptr = customPFXVals.SaturationPFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.SaturationPFXValue[0] == 1)
                }, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], nil, customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end)

            widgets.renderFloatGeneric(
                "ContrastSaturationPostFX.Vibrance", {
                    desc = "Intelligently saturate colors for more vibrance.",
                    default = "0",
                    varName = "ContrastSaturationPostFX.Vibrance",
                    varType = "float"
                }, {
                    name = "Vibrance",
                    ptr = customPFXVals.VibrancePFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.VibrancePFXValue[0] == 0)
                }, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end, function()
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], nil, {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end)

            widgets.tooltipButton({
                desc = "An RGB multiplier to the vibrance.",
                default = "1 1 1",
                varName = "ContrastSaturationPostFX.VibranceBalance",
                varType = "float[3]"
            })
            do
                im.SameLine()
                local disabled = customPFXVals.VibranceBalancePFX[0] == 1 and customPFXVals.VibranceBalancePFX[1] == 1 and customPFXVals.VibranceBalancePFX[2] == 1
                if disabled then im.BeginDisabled() end
                if widgets.resetButton("VibranceBalance") then
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {1, 1, 1}) end
                end
                if disabled then im.EndDisabled() end
                im.SameLine()
                if im.ColorEdit3("Vibrance Balance", customPFXVals.VibranceBalancePFX, 0) then
                    if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0], customPFXVals.VibrancePFXValue[0], {customPFXVals.VibranceBalancePFX[0], customPFXVals.VibranceBalancePFX[1], customPFXVals.VibranceBalancePFX[2]}) end
                end
            end

            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##VignetteEnabled", customPFXVals.VignettePFX) then
            if zeit_rc_vignette then zeit_rc_vignette.setEnabled(customPFXVals.VignettePFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Vignette") then
            im.Indent()
            im.Indent()
            im.PushID1("VignetteSettings")

            widgets.renderFloatGeneric(
                "VignettePostFX.Vmax", {
                    desc = "The maximum vignette size equals this times the screen size.",
                    default = "0",
                    varName = "VignettePostFX.Vmax",
                    varType = "float"
                }, {
                    name = "Maximum Scalar",
                    ptr = customPFXVals.VmaxPFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.VmaxPFXValue[0] == 0)
                }, function()
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
                end, function()
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(nil, customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
                end)

            widgets.renderFloatGeneric(
                "VignettePostFX.Vmin", {
                    desc = "The minimum vignette size equals this times the screen size.",
                    default = "0",
                    varName = "VignettePostFX.Vmin",
                    varType = "float"
                }, {
                    name = "Minimum Scalar",
                    ptr = customPFXVals.VminPFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.VminPFXValue[0] == 0)
                }, function()
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
                end, function()
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], nil, {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
                end)

            widgets.tooltipButton({
                desc = "Color of the vignette.",
                default = "0 0 0",
                varName = "VignettePostFX.Color",
                varType = "float[3]"
            })
            do
                im.SameLine()
                local disabled = customPFXVals.ColorPFX[0] == 0 and customPFXVals.ColorPFX[1] == 0 and customPFXVals.ColorPFX[2] == 0
                if disabled then im.BeginDisabled() end
                if widgets.resetButton("VignettePostFX") then
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {0,0,0}) end
                end
                if disabled then im.EndDisabled() end
                im.SameLine()
                if im.ColorEdit3("Color##Vignette", customPFXVals.ColorPFX, 0) then
                    if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
                end
            end
            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##SharpnessEnabled", customPFXVals.SharpnessPFX) then
            if zeit_rc_sharpen then zeit_rc_sharpen.setEnabled(customPFXVals.SharpnessPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Sharpness") then
            im.Indent()
            im.Indent()
            im.PushID1("SharpnessSettings")

            widgets.renderFloatGeneric(
                "SharpenPostFX.Sharpness", {
                    desc = "Sharpness modifier to apply to the screen.",
                    default = "0",
                    varName = "SharpenPostFX.Sharpness",
                    varType = "float"
                }, {
                    name = "Sharpness",
                    ptr = customPFXVals.SharpnessPFXValue,
                    min = 0,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.SharpnessPFXValue[0] == 0)
                }, function()
                    if zeit_rc_sharpen then zeit_rc_sharpen.getAndSaveSettings(customPFXVals.SharpnessPFXValue[0]) end
                end, function()
                    if zeit_rc_sharpen then zeit_rc_sharpen.getAndSaveSettings(nil) end
                end)

            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##FilmgrainEnabled", customPFXVals.FilmgrainPFX) then
            if zeit_rc_filmgrain then zeit_rc_filmgrain.setEnabled(customPFXVals.FilmgrainPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Film Grain") then
            im.Indent()
            im.Indent()
            im.PushID1("SharpnessSettings")

            widgets.renderFloatGeneric(
                "FilmGrainPostFX.Intensity", {
                    desc = "How visible the grain is. Higher is more visible.",
                    default = "0.5",
                    varName = "FilmGrainPostFX.Intensity",
                    varType = "float"
                }, {
                    name = "Intensity",
                    ptr = customPFXVals.FilmgrainPFXIntensityValue,
                    min = 0,
                    max = 10,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.FilmgrainPFXIntensityValue[0] == 0.5)
                }, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
                end, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(nil, customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
                end)

            widgets.renderFloatGeneric(
                "FilmGrainPostFX.Variance", {
                    desc = "Controls the variance of the Gaussian noise. Lower values look smoother.",
                    default = "0.4",
                    varName = "FilmGrainPostFX.Variance",
                    varType = "float"
                }, {
                    name = "Variance",
                    ptr = customPFXVals.FilmgrainPFXVarianceValue,
                    min = 0,
                    max = 1,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.FilmgrainPFXVarianceValue[0] == 0.4)
                }, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
                end, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], nil, customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
                end)

            widgets.renderFloatGeneric(
                "FilmGrainPostFX.SignalToNoiseRatio", {
                    desc = "Higher Signal-to-Noise Ratio values give less grain to brighter pixels. 0 disables this feature.",
                    default = "6",
                    varName = "FilmGrainPostFX.SignalToNoiseRatio",
                    varType = "float"
                }, {
                    name = "Signal To Noise Ratio",
                    ptr = customPFXVals.FilmgrainPFXSignalToNoiseRatioValue,
                    min = 0,
                    max = 15,
                    format = "%.2f",
                    resetDisabled = (customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0] == 6)
                }, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
                end, function()
                    if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], nil) end
                end)

            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##ChromaticAbberationEnabled", customPFXVals.ChromaticAbberationPFX) then
            if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.setEnabled(customPFXVals.ChromaticAbberationPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Chromatic Aberration") then
            im.Indent()
            im.Indent()
            im.PushID1("ChromaticAbberationSettings")

            widgets.renderFloatGeneric(
                "ChromaticAbberationPostFX.DistCoefficient", {
                    desc = "The amount of non-cubic distortion to apply.",
                    default = "0",
                    varName = "ChromaticAbberationPostFX.DistCoefficient",
                    varType = "float"
                }, {
                    name = "Distortion Coefficient",
                    ptr = customPFXVals.DistCoefficient,
                    min = -2,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.DistCoefficient[0] == 0)
                }, function()
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(customPFXVals.DistCoefficient[0], customPFXVals.CubeDistortionFactor[0], {customPFXVals.ColorDistortionFactor[0], customPFXVals.ColorDistortionFactor[1], customPFXVals.ColorDistortionFactor[2]}) end
                end, function()
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(nil, customPFXVals.CubeDistortionFactor[0], {customPFXVals.ColorDistortionFactor[0], customPFXVals.ColorDistortionFactor[1], customPFXVals.ColorDistortionFactor[2]}) end
                end)

            widgets.renderFloatGeneric(
                "ChromaticAbberationPostFX.CubeDistortionFactor", {
                    desc = "The amount of cubic distortion to apply.",
                    default = "0",
                    varName = "ChromaticAbberationPostFX.CubeDistortionFactor",
                    varType = "float"
                }, {
                    name = "Cube Distortion Factor",
                    ptr = customPFXVals.CubeDistortionFactor,
                    min = -2,
                    max = 2,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.CubeDistortionFactor[0] == 0)
                }, function()
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(customPFXVals.DistCoefficient[0], customPFXVals.CubeDistortionFactor[0], {customPFXVals.ColorDistortionFactor[0], customPFXVals.ColorDistortionFactor[1], customPFXVals.ColorDistortionFactor[2]}) end
                end, function()
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(customPFXVals.DistCoefficient[0], nil, {customPFXVals.ColorDistortionFactor[0], customPFXVals.ColorDistortionFactor[1], customPFXVals.ColorDistortionFactor[2]}) end
                end)

            widgets.tooltipButton({
                desc = "The color distortion to apply.",
                default = "0 0 0",
                varName = "ChromaticAbberationPostFX.ColorDistortionFactor",
                varType = "float[3]"
            })
            do
                im.SameLine()
                local disabled = customPFXVals.ColorDistortionFactor[0] == 0 and customPFXVals.ColorDistortionFactor[1] == 0 and customPFXVals.ColorDistortionFactor[2] == 0
                if disabled then im.BeginDisabled() end
                if widgets.resetButton("ChromaticAbberationPostFX.ColorDistortionFactor") then
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(customPFXVals.DistCoefficient[0], customPFXVals.CubeDistortionFactor[0], {0,0,0}) end
                end
                if disabled then im.EndDisabled() end
                im.SameLine()
                if im.SliderFloat3("Color Distortion Factor##ChromaticAbberationPostFX.ColorDistortionFactor", customPFXVals.ColorDistortionFactor, -1, 1, "%.6f", 0) then
                    if zeit_rc_chromaticAbberation then zeit_rc_chromaticAbberation.getAndSaveSettings(customPFXVals.DistCoefficient[0], customPFXVals.CubeDistortionFactor[0], {customPFXVals.ColorDistortionFactor[0], customPFXVals.ColorDistortionFactor[1], customPFXVals.ColorDistortionFactor[2]}) end
                end
            end

            im.PopID()
            im.Unindent()
            im.Unindent()
        end

        if im.Checkbox("##LetterboxEnabled", customPFXVals.LetterboxPFX) then
            if zeit_rc_letterbox then zeit_rc_letterbox.setEnabled(customPFXVals.LetterboxPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Letterbox") then
            im.Indent()
            im.Indent()
            im.PushID1("LetterboxSettings")
            widgets.tooltipButton({
                desc = "Aspect Ratio, overrides height setting.",
            })
            if zeit_rc_letterbox then
                im.SameLine()
                if im.BeginCombo("##aspectRatioHeightSelector", letterboxOverride ~= 0 and zeit_rc_letterbox.ratios[letterboxOverride][2] or "Select Aspect Ratio...") then
                    for k,v in ipairs(zeit_rc_letterbox.ratios) do
                        if im.Selectable1(v[2], letterboxOverride == k) then
                            if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(0, 0, {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, k) end
                        end
                    end
                    im.EndCombo()
                end
            end

            widgets.renderFloatGeneric(
                "LetterboxPostFX.uvY1, LetterboxPostFX.uvY2", {
                    desc = "The height of one bar equals the screen height times this value.",
                    default = "0",
                    varName = "LetterboxPostFX.uvY1, LetterboxPostFX.uvY2",
                    varType = "float"
                }, {
                    name = "Height",
                    ptr = customPFXVals.HeightPFXValue,
                    min = 0,
                    max = 0.5,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.HeightPFXValue[0] == 0)
                }, function()
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], customPFXVals.WidthPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, 0) end
                end, function()
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(nil, customPFXVals.WidthPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, 0) end
                end)

            widgets.renderFloatGeneric(
                "LetterboxPostFX.uvX1, LetterboxPostFX.uvX2", {
                    desc = "The width of one bar equals the screen width times this value.",
                    default = "0",
                    varName = "LetterboxPostFX.uvX1, LetterboxPostFX.uvX2",
                    varType = "float"
                }, {
                    name = "Width",
                    ptr = customPFXVals.WidthPFXValue,
                    min = 0,
                    max = 0.5,
                    format = "%.3f",
                    resetDisabled = (customPFXVals.WidthPFXValue[0] == 0)
                }, function()
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], customPFXVals.WidthPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, 0) end
                end, function()
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], nil, {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, 0) end
                end)

            widgets.tooltipButton({
                desc = "Color of the letterbox.",
                default = "0 0 0",
                varName = "LetterboxPostFX.Color",
                varType = "float[3]"
            })
            do
                im.SameLine()
                local disabled = customPFXVals.LetterboxColorPFX[0] == 0 and customPFXVals.LetterboxColorPFX[1] == 0 and customPFXVals.LetterboxColorPFX[2] == 0
                if disabled then im.BeginDisabled() end
                if widgets.resetButton("LetterboxPostFX.Color") then
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], customPFXVals.WidthPFXValue[0], {0,0,0}, 0) end
                end
                if disabled then im.EndDisabled() end
                im.SameLine()
                if im.ColorEdit3("Color##Letterbox", customPFXVals.LetterboxColorPFX, 0) then
                    if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], customPFXVals.WidthPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}, 0) end
                end
            end

            im.PopID()
            im.Unindent()
            im.Unindent()
        end
    end,
    ssao = function()
        im.PushID1("SSAOSettings")

        widgets.renderFloatGeneric(
            "PostEffectSSAO::setContrast", {
                desc = "Sets the contrast/intensity of the ambient occlusion.",
                default = "2",
                varName = "PostEffectSSAO::setContrast",
                varType = "float"
            }, {
                name = "Contrast",
                ptr = SSAOContrast,
                min = 0,
                max = 10,
                format = "%.3f",
                resetDisabled = (zeit_rc_ssao and zeit_rc_ssao.isNil("contrast") or false)
            }, function()
                if zeit_rc_ssao then zeit_rc_ssao.setContrast(SSAOContrast[0]) end
            end, function()
                if zeit_rc_ssao then zeit_rc_ssao.setContrast(nil) end
            end)

        widgets.renderFloatGeneric(
            "PostEffectSSAO::setRadius", {
                desc = "Maximum radius of the ambient occlusion spread.",
                default = "1.5",
                varName = "PostEffectSSAO::setRadius",
                varType = "float"
            }, {
                name = "Radius",
                ptr = SSAORadius,
                min = 0,
                max = 10,
                format = "%.3f",
                resetDisabled = (zeit_rc_ssao and zeit_rc_ssao.isNil("radius") or false)
            }, function()
                if zeit_rc_ssao then zeit_rc_ssao.setRadius(SSAORadius[0]) end
            end, function()
                if zeit_rc_ssao then zeit_rc_ssao.setRadius(nil) end
            end)

        widgets.tooltipButton({
            desc = "The amount of samples SSAO uses.",
            default = "16",
            varName = "PostEffectSSAO::setSamples",
            varType = "int"
        })
        do
            local width = (im.CalcItemWidth()/2)-style.ItemInnerSpacing.x+1
            im.SameLine()
            local disabled = zeit_rc_ssao and zeit_rc_ssao.isNil("samples") or false
            if disabled then im.BeginDisabled() end
            if widgets.resetButton("ssao_samples") then
                if zeit_rc_ssao then zeit_rc_ssao.setQuality(nil) end
            end
            if disabled then im.EndDisabled() end
            im.SameLine()
            local _SSAOHighQuality = SSAOHighQuality
            if SSAOHighQuality then im.BeginDisabled() end
            if widgets.button("High", im.ImVec2(width, 0)) then
                _SSAOHighQuality = true
                if zeit_rc_ssao then zeit_rc_ssao.setQuality(_SSAOHighQuality) end
            end
            if SSAOHighQuality then im.EndDisabled() end
            im.SameLine()
            if not SSAOHighQuality then im.BeginDisabled() end
            if widgets.button("Low", im.ImVec2(width, 0)) then
                _SSAOHighQuality = false
                if zeit_rc_ssao then zeit_rc_ssao.setQuality(_SSAOHighQuality) end
            end
            if not SSAOHighQuality then im.EndDisabled() end
            SSAOHighQuality = _SSAOHighQuality

            im.SameLine()
            im.Text("Quality")
        end

        im.PopID()
    end,
    shadow = function()
        im.PushID1("ShadowSettings")

        if scenetree.sunsky then
            if im.Checkbox("##Enable Shadow Override", shadowVals.Active) then
                if zeit_rc_shadowsettings then zeit_rc_shadowsettings.setEnabled(shadowVals.Active[0]) end
            end
            im.SameLine()
            if im.CollapsingHeader1("Shadow Overrides") then
                im.Indent()
                im.Indent()
                widgets.renderIntGeneric(
                    "ScatterSky::texSize", {
                        desc = "The texture size of the shadow map.",
                        default = tostring(zeit_rc_shadowsettings.origValues.texSize or "/"),
                        varName = "ScatterSky::texSize",
                        varType = "int"
                    }, {
                        name = "Texture Size",
                        ptr = shadowVals.TexSizeValue,
                        min = 256,
                        max = 2048,
                        resetDisabled = (tostring(scenetree.sunsky.texSize) == zeit_rc_shadowsettings.origValues.texSize)
                    }, function()
                        scenetree.sunsky.texSize = shadowVals.TexSizeValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.texSize = zeit_rc_shadowsettings.origValues.texSize
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.tooltipButton({
                    desc = "The ESM shadow darkening factor. Controls how dark each split of the shadow map is.",
                    default = tostring(zeit_rc_shadowsettings.origValues.overDarkFactor or "/"),
                    varName = "ScatterSky::overDarkFactor",
                    varType = "float[4]"
                })
                do
                    im.SameLine()
                    local disabled = tostring(scenetree.sunsky.overDarkFactor):gsub(",", "") == zeit_rc_shadowsettings.origValues.overDarkFactor
                    if disabled then im.BeginDisabled() end
                    if widgets.resetButton("shadow_overDarkFactor") then
                        local default = split(zeit_rc_shadowsettings.origValues.overDarkFactor, " ")
                        scenetree.sunsky.overDarkFactor = Point4F(tonumber(default[1]), tonumber(default[2]), tonumber(default[3]), tonumber(default[4]))
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end
                    if disabled then im.EndDisabled() end
                    im.SameLine()
                    if im.SliderFloat4("Over Dark Factor", shadowVals.OverDarkValue, 256, 131072, "%.3f") then
                        scenetree.sunsky.overDarkFactor.x = shadowVals.OverDarkValue[0]
                        scenetree.sunsky.overDarkFactor.y = shadowVals.OverDarkValue[1]
                        scenetree.sunsky.overDarkFactor.z = shadowVals.OverDarkValue[2]
                        scenetree.sunsky.overDarkFactor.w = shadowVals.OverDarkValue[3]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end
                end

                widgets.renderFloatGeneric(
                    "ScatterSky::shadowDistance", {
                        desc = "The distance from the camera to extend the PSSM shadow.",
                        default = tostring(zeit_rc_shadowsettings.origValues.shadowDistance or "/"),
                        varName = "ScatterSky::shadowDistance",
                        varType = "float"
                    }, {
                        name = "Shadow Distance",
                        ptr = shadowVals.ShadowDistanceValue,
                        min = 500,
                        max = 5000,
                        format = "%.3f",
                        resetDisabled = (tostring(scenetree.sunsky.shadowDistance) == zeit_rc_shadowsettings.origValues.shadowDistance)
                    }, function()
                        scenetree.sunsky.shadowDistance = shadowVals.ShadowDistanceValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.shadowDistance = zeit_rc_shadowsettings.origValues.shadowDistance
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.renderFloatGeneric(
                    "ScatterSky::shadowSoftness", {
                        desc = "How much filtering is applied to the shadow edges.",
                        default = tostring(zeit_rc_shadowsettings.origValues.shadowSoftness or "/"),
                        varName = "ScatterSky::shadowSoftness",
                        varType = "float"
                    }, {
                        name = "Shadow Softness",
                        ptr = shadowVals.ShadowSoftnessValue,
                        min = 0,
                        max = 1,
                        format = "%.3f",
                        resetDisabled = (tostring(scenetree.sunsky.shadowSoftness) == zeit_rc_shadowsettings.origValues.shadowSoftness)
                    }, function()
                        scenetree.sunsky.shadowSoftness = shadowVals.ShadowSoftnessValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.shadowSoftness = zeit_rc_shadowsettings.origValues.shadowSoftness
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.renderIntGeneric(
                    "ScatterSky::numSplits", {
                        desc = "How many times the shadow is split up into sections.",
                        default = tostring(zeit_rc_shadowsettings.origValues.numSplits or "/"),
                        varName = "ScatterSky::numSplits",
                        varType = "int"
                    }, {
                        name = "Number of splits",
                        ptr = shadowVals.NumSplitsValue,
                        min = 1,
                        max = 4,
                        resetDisabled = (tostring(scenetree.sunsky.numSplits) == zeit_rc_shadowsettings.origValues.numSplits)
                    }, function()
                        scenetree.sunsky.numSplits = shadowVals.NumSplitsValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.numSplits = zeit_rc_shadowsettings.origValues.numSplits
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.renderFloatGeneric(
                    "ScatterSky::logWeight", {
                        desc = "The logarithmic PSSM split distance factor.",
                        default = tostring(zeit_rc_shadowsettings.origValues.logWeight or "/"),
                        varName = "ScatterSky::logWeight",
                        varType = "float"
                    }, {
                        name = "Logarithmic Weight",
                        ptr = shadowVals.LogWeightValue,
                        min = 0,
                        max = 1,
                        format = "%.3f",
                        resetDisabled = (tostring(scenetree.sunsky.logWeight) == zeit_rc_shadowsettings.origValues.logWeight)
                    }, function()
                        scenetree.sunsky.logWeight = shadowVals.LogWeightValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.logWeight = zeit_rc_shadowsettings.origValues.logWeight
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.renderFloatGeneric(
                    "ScatterSky::logWeight", {
                        desc = "Start fading shadows out at this distance. 0 = auto calculate this distance.",
                        default = tostring(zeit_rc_shadowsettings.origValues.fadeStartDistance or "/"),
                        varName = "ScatterSky::fadeStartDistance",
                        varType = "float"
                    }, {
                        name = "Fade Start Distance",
                        ptr = shadowVals.FadeDistanceValue,
                        min = 0,
                        max = 4000,
                        format = "%.3f",
                        resetDisabled = (tostring(scenetree.sunsky.fadeStartDistance) == zeit_rc_shadowsettings.origValues.fadeStartDistance)
                    }, function()
                        scenetree.sunsky.fadeStartDistance = shadowVals.FadeDistanceValue[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.fadeStartDistance = zeit_rc_shadowsettings.origValues.fadeStartDistance
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                widgets.renderCheckboxGeneric(
                    "ScatterSky::lastSplitTerrainOnly", {
                        desc = "This toggles only terrain being rendered in the last split of a PSSM shadow map.",
                        default = tostring(zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly == nil and "/" or (zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly == "1")),
                        varName = "ScatterSky::lastSplitTerrainOnly",
                        varType = "bool"
                    }, {
                        name = "Last Split Terrain Only",
                        ptr = shadowVals.LastSplitTerrainOnly,
                        resetDisabled = ((scenetree.sunsky.lastSplitTerrainOnly and "1" or "0") == zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly)
                    }, function()
                        scenetree.sunsky.lastSplitTerrainOnly = shadowVals.LastSplitTerrainOnly[0]
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end, function()
                        scenetree.sunsky.lastSplitTerrainOnly = zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly
                        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                    end)

                im.Unindent()
                im.Unindent()
            end
        else
            im.Text('This level does not have a sky object.')
        end
        im.PopID()
    end,
    shadowVars = function()
        im.PushID1("ShadowSettings2")
        do
            local _value = generalEffectsKeysReplaced["$pref::lightManager"]
            widgets.tooltipButton({
                desc = _value.desc,
                default = _value.default,
                varName = "$pref::lightManager",
                varType = "string"
            })
            im.SameLine()
            local disabled = zeit_rc_generaleffects and zeit_rc_generaleffects.isNil("$pref::lightManager") or false
            if disabled then im.BeginDisabled() end
            if widgets.resetButton("$pref::lightManager") then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::lightManager", nil) end
            end
            if disabled then im.EndDisabled() end
            im.SameLine()
            if im.BeginCombo(_value.name, _value.ptr) then
                if im.Selectable1("Basic Lighting", "Basic Lighting"==_value.ptr) then
                    if zeit_rc_generaleffects then
                        if k == "Basic Lighting" then
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "None")
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::disable", 2)
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::textureScalar", 0.5)
                        end
                        zeit_rc_generaleffects.addSetting("$pref::lightManager", "Basic Lighting")
                    end
                end
                if im.Selectable1("Advanced Lighting", "Advanced Lighting"==_value.ptr) then
                    if zeit_rc_generaleffects then
                        zeit_rc_generaleffects.addSetting("$pref::lightManager", "Advanced Lighting")
                    end
                end
                if im.Selectable1("Advanced Lighting 1.5", "Advanced Lighting 1.5"==_value.ptr) then
                    if zeit_rc_generaleffects then
                        zeit_rc_generaleffects.addSetting("$pref::lightManager", "Advanced Lighting 1.5")
                    end
                end
                im.EndCombo()
            end
        end

        local currentLightManager = ffi.string(generalEffectsKeysReplaced["$pref::lightManager"].ptr)
        if currentLightManager == "Basic Lighting" then
            im.Text("This Light Manager does not support shadows.")
            im.BeginDisabled()
        end
        do
            local _value = generalEffectsKeysReplaced["$pref::Shadows::filterMode"]
            widgets.tooltipButton({
                desc = _value.desc,
                default = _value.default,
                varName = "$pref::Shadows::filterMode",
                varType = "string"
            })
            im.SameLine()
            local disabled = zeit_rc_generaleffects and zeit_rc_generaleffects.isNil("$pref::Shadows::filterMode") or false
            if disabled then im.BeginDisabled() end
            if widgets.resetButton("$pref::Shadows::filterMode") then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", nil) end
            end
            if disabled then im.EndDisabled() end
            im.SameLine()
            if im.BeginCombo(_value.name, _value.ptr) then
                if im.Selectable1("None", "None"==_value.ptr) then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "None") end
                end
                if im.Selectable1("SoftShadow", "SoftShadow"==_value.ptr) then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "SoftShadow") end
                end
                if im.Selectable1("SoftShadowHighQuality", "SoftShadowHighQuality"==_value.ptr) then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "SoftShadowHighQuality") end
                end
                im.EndCombo()
            end
        end

        widgets.renderCheckboxGeneral("$pref::Shadows::disable", generalEffectsKeysReplaced["$pref::Shadows::disable"], nil, 2)
        widgets.renderCheckboxGeneral("$pref::imposter::canShadow", generalEffectsKeysReplaced["$pref::imposter::canShadow"])
        widgets.renderFloatGeneral("$pref::Shadows::textureScalar", generalEffectsKeysReplaced["$pref::Shadows::textureScalar"], 0.5, 2, "%.1f")
        if currentLightManager == "Basic Lighting" then
            im.EndDisabled()
        end
        im.PopID()
    end,
    generalEffects = function()
        im.PushID1("GeneralSettings")
        im.PopID()

        for n,k in pairs(generalEffectsKeysSorted) do
            local v = generalEffectsKeys[k]
            if not v then goto next end
            im.PushID1(tostring(k))

            local key = ffi.string(v)
            local valueData = generalEffectsValues[key]
            if not valueData.desc then
                im.BeginDisabled()
                widgets.button("?")
                im.EndDisabled()
            else
                widgets.tooltipButton({
                    desc = valueData.desc,
                    default = valueData.default,
                    varName = key,
                    varType = valueData.type or "str"
                })
            end
            im.SameLine()

            im.InputText("###GeneralEffectsEntryKey"..tostring(n), v)
            local keyChanged = key ~= ffi.string(v)
            im.SameLine()
            local val, changed = typeMatchRender[valueData.type]("###GeneralEffectsEntryVal"..tostring(n), valueData.ptr, valueData.min, valueData.max, valueData.format)
            if (keyChanged or changed) then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(key, val) end
            end
            im.SameLine()
            if widgets.button("Remove", im.ImVec2(im.GetContentRegionAvailWidth()-1, 0)) then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(key, nil) end
                generalEffectsKeys[k] = nil
                generalEffectsKeysSorted = tableKeysSorted(generalEffectsKeys)
            end
            im.PopID(tostring(k))
            ::next::
        end
    end,
    newGeneralEffects = function()
        im.PushID1("NewGeneralSettings")

        local selected = ffi.string(GeneralEffectsEntryKeyNew)
        local function validateInput(key)
            if zeit_rc_generaleffects then zeit_rc_generaleffects.addSettingTemp(selected, nil) end
            selected = key
        end

        if im.BeginCombo("###GeneralEffectsEntryDropdown", "", im.ComboFlags_NoPreview) then
            for i = 1, #generalEffectsAvailableKeys do
                local k = generalEffectsAvailableKeys[i]
                if not generalEffectsKeys[k] then
                    local v = generalEffectsValues[k]
                    widgets.tooltipButton({
                        desc = v.desc,
                        default = tostring(v.default),
                        varName = k,
                        varType = v.type or "str"
                    })
                    im.SameLine()
                    if im.Selectable1(k, k==selected) then
                        ffi.copy(GeneralEffectsEntryKeyNew, k)
                        validateInput(k)
                    end
                end
            end
            im.EndCombo()
        end
        im.SameLine()
        if im.InputText("###GeneralEffectsEntryKeyNew", GeneralEffectsEntryKeyNew) then
            validateInput(ffi.string(GeneralEffectsEntryKeyNew))
        end
        im.SameLine()

        local valueData = generalEffectsValues[selected]
        local val, changed = typeMatchRender[valueData.type or "str"]("###GeneralEffectsEntryValNew", valueData.ptr, valueData.min, valueData.max, valueData.format)
        if changed then
            if zeit_rc_generaleffects then zeit_rc_generaleffects.addSettingTemp(selected, val) end
        end

        im.SameLine()
        im.PopID()

        if selected ~= "" and val then
            if widgets.button("Add", im.ImVec2(im.GetContentRegionAvailWidth()-1, 0)) then
                ffi.copy(GeneralEffectsEntryKeyNew, "")
                if zeit_rc_generaleffects then
                    zeit_rc_generaleffects.addSetting(selected, val)
                end
                generalEffectsKeysSorted = tableKeysSorted(generalEffectsKeys)
            end
        else
            im.BeginDisabled()
            widgets.button("Add", im.ImVec2(im.GetContentRegionAvailWidth()-1, 0))
            im.EndDisabled()
        end
    end,
    detail = function()
        im.PushID1("LevelDetail")

        im.Text("Mesh and Terrain")
        widgets.renderFloatGeneral("$pref::TS::detailAdjust", generalEffectsKeysReplaced["$pref::TS::detailAdjust"], 0.25, 2, "%.3f")
        widgets.renderFloatGeneral("$pref::Terrain::lodScale", generalEffectsKeysReplaced["$pref::Terrain::lodScale"], 0.25, 2, "%.3f")
        widgets.renderFloatGeneral("$pref::GroundCover::densityScale", generalEffectsKeysReplaced["$pref::GroundCover::densityScale"], 0, 3, "%.3f")
        widgets.renderIntGeneral("$pref::TS::smallestVisiblePixelSize", generalEffectsKeysReplaced["$pref::TS::smallestVisiblePixelSize"], -1, 250, "%d")

        im.Text("Textures")
        widgets.renderFloatGeneral("$pref::Terrain::detailScale", generalEffectsKeysReplaced["$pref::Terrain::detailScale"], 0.25, 2, "%.3f")
        widgets.renderIntGeneral("$pref::Video::textureReductionLevel", generalEffectsKeysReplaced["$pref::Video::textureReductionLevel"], 0, 4, "%d")

        im.Text("Other")
        widgets.renderIntGeneral("$pref::TS::maxDecalCount", generalEffectsKeysReplaced["$pref::TS::maxDecalCount"], 0, 10000, "%d")
        widgets.renderCheckboxGeneral("$pref::TS::skipRenderDLs", generalEffectsKeysReplaced["$pref::TS::skipRenderDLs"])

        im.PopID()
    end,
    reflection = function()
        im.PushID1("Reflection")

        im.Text("Environment")
        widgets.renderCheckboxGeneral("$pref::Water::disableTrueReflections", generalEffectsKeysReplaced["$pref::Water::disableTrueReflections"])
        widgets.renderFloatGeneral("$pref::Reflect::refractTexScale", generalEffectsKeysReplaced["$pref::Reflect::refractTexScale"], 0.25, 2, "%.3f")
        im.Text("Vehicle")
        widgets.renderCheckboxGeneral("$pref::BeamNGVehicle::dynamicMirrors::enabled", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicMirrors::enabled"])
        widgets.renderFloatGeneral("$pref::BeamNGVehicle::dynamicMirrors::detail", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicMirrors::detail"], 0, 1, "%.3f")
        widgets.renderIntGeneral("$pref::BeamNGVehicle::dynamicMirrors::distance", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicMirrors::distance"], 0, 4000, "%d")
        widgets.renderIntGeneral("$pref::BeamNGVehicle::dynamicMirrors::textureSize", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicMirrors::textureSize"], 0, 8096, "%d")
        im.NewLine()
        widgets.renderCheckboxGeneral("$pref::BeamNGVehicle::dynamicReflection::enabled", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicReflection::enabled"])
        widgets.renderFloatGeneral("$pref::BeamNGVehicle::dynamicReflection::detail", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicReflection::detail"], 0, 1, "%.3f")
        widgets.renderIntGeneral("$pref::BeamNGVehicle::dynamicReflection::distance", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicReflection::distance"], 0, 4000, "%d")
        widgets.renderIntGeneral("$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate"], 0, 6, "%d")
        widgets.renderIntGeneral("$pref::BeamNGVehicle::dynamicReflection::textureSize", generalEffectsKeysReplaced["$pref::BeamNGVehicle::dynamicReflection::textureSize"], 0, 2048, "%d")

        im.PopID()
    end
}

local function render(dtReal)
    local isOpen = im.BoolPtr(true)
    im.Begin("Zeit's Graphics Utils: Profile Editor", isOpen, im.WindowFlags_AlwaysAutoResize + im.WindowFlags_MenuBar)

    modules.menubar(dtReal)
    local disabledNoLevel = false
    if not getCurrentLevelIdentifier() then -- no map, no work
        im.Text("No map detected, please load a map.")
        disabledNoLevel = true
        im.Separator()
        im.BeginDisabled()
    end

    if im.TreeNodeEx1("UI", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.ui()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("HDR", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.hdr()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Post Effects", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.customPostFx()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Ambient Occlusion", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.ssao()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Shadows", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.shadow()
        im.Separator()
        modules.shadowVars()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Environment", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.detail()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Reflection", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.reflection()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("General Effects", im.TreeNodeFlags_Selected + im.TreeNodeFlags_SpanFullWidth) then
        modules.generalEffects()
        im.Separator()
        modules.newGeneralEffects()
        im.TreePop()
    end
    im.Separator()
    if im.TreeNodeEx1("Tips", im.TreeNodeFlags_SpanFullWidth) then
        im.BulletText("CTRL + Left Click on sliders to use keyboard.")
        im.BulletText("Reset removes settings from the profile entirely. They will no longer overwrite game settings.")
        im.TreePop()
    end

    if disabledNoLevel then
        im.EndDisabled()
    end
    im.End()

    if not isOpen[0] then
        toggleUI()
    end
end

local function onUpdate(dtReal)
    if not M.showUI then return end

    if queueEditorOpen then
        if not editor.isEditorActive() then
            editor.toggleActive()
        end
        queueEditorOpen = false
    end

    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal)
    if not success and err then
        zeit_rcMain.log("E", "onUpdate", err..debug.traceback())
    end

    style.pop()
end

local function refreshColorCorrectionCache()
    for k,v in ipairs(FS:findFiles(colorCorrectionPrefix, "*.png\t*.jpg", 0, true, false)) do
        colorCorrectionRamps[k] = v:match("^.+/(.+)")
    end
    colorCorrectionRampIndex = arrayFindValueIndex(colorCorrectionRamps, hdrVals.colorCorrectionRampPath:match("^.+/(.+)")) or 0
end

local function onFileChanged(file)
    if file:match(colorCorrectionPrefix) then
        refreshColorCorrectionCache()
    end
end

local function onZeitGraphicsSettingsChange(CURSET)
    local defaultvars = require("zeit/rcTool/defaultVars")
    generalEffectsKeysReplaced = defaultvars.get()

    SSAOContrast[0] = CURSET.ssao and CURSET.ssao.contrast or 2
    SSAORadius[0] = CURSET.ssao and CURSET.ssao.radius or 1.5
    SSAOHighQuality = (CURSET.ssao and CURSET.ssao.samples or 16) == 32
    uiFpsValue[0] = math.ceil(CURSET.uifps and CURSET.uifps.fps or 30)

    hdrVals.colorCorrectionRampPath = CURSET.rendercomponents and CURSET.rendercomponents.colorCorrectionRampPath or ""
    hdrVals.colorCorrectionStrength[0] = tonumber(CURSET.rendercomponents and CURSET.rendercomponents.colorCorrectionStrength or 1)
    refreshColorCorrectionCache()

    dofVals.IsEnabled = tonumber(CURSET.dof and CURSET.dof.isEnabled or "2")
    dofVals.FarBlurMax[0] = CURSET.dof and CURSET.dof.farBlurMax or 0.15
    dofVals.NearBlurMax[0] = CURSET.dof and CURSET.dof.nearBlurMax or 0.15
    dofVals.FarSlope[0] = CURSET.dof and CURSET.dof.farSlope or 10
    dofVals.NearSlope[0] = CURSET.dof and CURSET.dof.nearSlope or -20
    dofVals.MaxRange[0] = CURSET.dof and CURSET.dof.maxRange or 100
    dofVals.MinRange[0] = CURSET.dof and CURSET.dof.minRange or 100
    dofVals.Debug[0] = scenetree.DOFPostEffect and scenetree.DOFPostEffect.debugModeEnabled or false

    if CURSET.autofocus then
        autofocusCheckbox[0] = CURSET.autofocus.isEnabled or false
        if CURSET.autofocus.doVehicle then
            autofocusVehicleCheckbox[0] = CURSET.autofocus.doVehicle
        end
    end

    customPFXVals.ContrastPFX[0] = CURSET.contrastsaturation ~= nil
    customPFXVals.ContrastPFXValue[0] = CURSET.contrastsaturation and CURSET.contrastsaturation.contrast or 1
    customPFXVals.SaturationPFXValue[0] = CURSET.contrastsaturation and CURSET.contrastsaturation.saturation or 1

    customPFXVals.VibrancePFXValue[0] = CURSET.contrastsaturation and CURSET.contrastsaturation.vibrance or 0
    if CURSET.contrastsaturation and CURSET.contrastsaturation.vibrancebal then
        customPFXVals.VibranceBalancePFX[0] = CURSET.contrastsaturation.vibrancebal[1]
        customPFXVals.VibranceBalancePFX[1] = CURSET.contrastsaturation.vibrancebal[2]
        customPFXVals.VibranceBalancePFX[2] = CURSET.contrastsaturation.vibrancebal[3]
    else
        customPFXVals.VibranceBalancePFX[0] = 1
        customPFXVals.VibranceBalancePFX[1] = 1
        customPFXVals.VibranceBalancePFX[2] = 1
    end

    customPFXVals.VignettePFX[0] = CURSET.vignette ~= nil
    customPFXVals.VmaxPFXValue[0] = CURSET.vignette and CURSET.vignette.vmax or 0
    customPFXVals.VminPFXValue[0] = CURSET.vignette and CURSET.vignette.vmin or 0
    if CURSET.vignette and CURSET.vignette.color then
        customPFXVals.ColorPFX[0] = CURSET.vignette.color[1]
        customPFXVals.ColorPFX[1] = CURSET.vignette.color[2]
        customPFXVals.ColorPFX[2] = CURSET.vignette.color[3]
    else
        customPFXVals.ColorPFX[0] = 0
        customPFXVals.ColorPFX[1] = 0
        customPFXVals.ColorPFX[2] = 0
    end

    customPFXVals.SharpnessPFX[0] = CURSET.sharpen ~= nil
    customPFXVals.SharpnessPFXValue[0] = CURSET.sharpen and CURSET.sharpen.sharpness or 0

    customPFXVals.FilmgrainPFX[0] = CURSET.filmgrain ~= nil
    customPFXVals.FilmgrainPFXIntensityValue[0] = CURSET.filmgrain and CURSET.filmgrain.intensity or 0.5
    customPFXVals.FilmgrainPFXVarianceValue[0] = CURSET.filmgrain and CURSET.filmgrain.variance or 0.4
    customPFXVals.FilmgrainPFXMeanValue[0] = CURSET.filmgrain and CURSET.filmgrain.mean or 0.5
    customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0] = CURSET.filmgrain and CURSET.filmgrain.signalToNoiseRatio or 6

    customPFXVals.LetterboxPFX[0] = CURSET.letterbox ~= nil
    customPFXVals.HeightPFXValue[0] = CURSET.letterbox and CURSET.letterbox.height or 0
    customPFXVals.WidthPFXValue[0] = CURSET.letterbox and CURSET.letterbox.width or 0
    letterboxOverride = CURSET.letterbox and CURSET.letterbox.heightOverride or 0
    if CURSET.letterbox and CURSET.letterbox.color then
        customPFXVals.LetterboxColorPFX[0] = CURSET.letterbox.color[1]
        customPFXVals.LetterboxColorPFX[1] = CURSET.letterbox.color[2]
        customPFXVals.LetterboxColorPFX[2] = CURSET.letterbox.color[3]
    else
        customPFXVals.LetterboxColorPFX[0] = 0
        customPFXVals.LetterboxColorPFX[1] = 0
        customPFXVals.LetterboxColorPFX[2] = 0
    end

    customPFXVals.ChromaticAbberationPFX[0] = CURSET.chromaticAbberation ~= nil
    customPFXVals.DistCoefficient[0] = CURSET.chromaticAbberation and CURSET.chromaticAbberation.dist or 0
    customPFXVals.CubeDistortionFactor[0] = CURSET.chromaticAbberation and CURSET.chromaticAbberation.cube or 0
    if CURSET.chromaticAbberation and CURSET.chromaticAbberation.color then
        customPFXVals.ColorDistortionFactor[0] = CURSET.chromaticAbberation.color[1]
        customPFXVals.ColorDistortionFactor[1] = CURSET.chromaticAbberation.color[2]
        customPFXVals.ColorDistortionFactor[2] = CURSET.chromaticAbberation.color[3]
    else
        customPFXVals.ColorDistortionFactor[0] = 0
        customPFXVals.ColorDistortionFactor[1] = 0
        customPFXVals.ColorDistortionFactor[2] = 0
    end

    shadowVals.Active[0] = CURSET.shadowsettings ~= nil
    shadowVals.TexSizeValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.texSize) or (scenetree.sunsky and scenetree.sunsky.texSize or 1024)
    local overdarkFactor = CURSET.shadowsettings and CURSET.shadowsettings.overDarkFactor or (scenetree.sunsky and scenetree.sunsky.overDarkFactor or "0 0 0 0")
    if overdarkFactor then
        if type(overdarkFactor) == "string" then
            local vals = split(overdarkFactor, " ")
            shadowVals.OverDarkValue[0] = tonumber(vals[1])
            shadowVals.OverDarkValue[1] = tonumber(vals[2])
            shadowVals.OverDarkValue[2] = tonumber(vals[3])
            shadowVals.OverDarkValue[3] = tonumber(vals[4])
        elseif type(overdarkFactor) == "userdata" then
            shadowVals.OverDarkValue[0] = overdarkFactor.x
            shadowVals.OverDarkValue[1] = overdarkFactor.y
            shadowVals.OverDarkValue[2] = overdarkFactor.z
            shadowVals.OverDarkValue[3] = overdarkFactor.w
        end
    end

    shadowVals.ShadowDistanceValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.shadowDistance) or (scenetree.sunsky and scenetree.sunsky.shadowDistance or 1500)
    shadowVals.ShadowSoftnessValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.shadowSoftness) or (scenetree.sunsky and scenetree.sunsky.shadowSoftness or 0.15)
    shadowVals.NumSplitsValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.numSplits) or (scenetree.sunsky and scenetree.sunsky.numSplits or 4)
    shadowVals.LogWeightValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.logWeight) or (scenetree.sunsky and scenetree.sunsky.logWeight or 0.98)
    shadowVals.FadeDistanceValue[0] = CURSET.shadowsettings and tonumber(CURSET.shadowsettings.fadeStartDistance) or (scenetree.sunsky and scenetree.sunsky.fadeStartDistance or 0)
    if CURSET.shadowsettings and CURSET.shadowsettings.lastSplitTerrainOnly then
        shadowVals.LastSplitTerrainOnly[0] = CURSET.shadowsettings.lastSplitTerrainOnly == "1"
    elseif scenetree.sunsky then
        shadowVals.LastSplitTerrainOnly[0] = scenetree.sunsky:getField("lastSplitTerrainOnly", 0) == "1"
    else
        shadowVals.LastSplitTerrainOnly[0] = true
    end

    generalEffectsKeys = {}
    generalEffectsValues = defaultvars.getOthers()
    generalEffectsAvailableKeys = tableKeysSorted(generalEffectsValues)

    local generalEffectsSourceData = CURSET.generaleffects or {}
    for k,v in pairs(generalEffectsSourceData) do
        if not generalEffectsKeysReplaced[k] then
            generalEffectsKeys[k] = im.ArrayChar(256)
            ffi.copy(generalEffectsKeys[k], tostring(k))

            typeMatchFill[generalEffectsValues[k].type](generalEffectsValues[k].ptr, v)
        end
    end
    table.sort(generalEffectsKeys)

    for k in pairs(generalEffectsKeysReplaced) do
        if generalEffectsSourceData[k] then
            pcall(function()
                generalEffectsKeysReplaced[k].ptr[0] = generalEffectsSourceData[k]
            end)
        end
    end

    if generalEffectsSourceData["$pref::lightManager"] then
        generalEffectsKeysReplaced["$pref::lightManager"].ptr = generalEffectsSourceData["$pref::lightManager"]
    end
    if generalEffectsSourceData["$pref::Shadows::filterMode"] then
        generalEffectsKeysReplaced["$pref::Shadows::filterMode"].ptr = generalEffectsSourceData["$pref::Shadows::filterMode"]
    end
    if generalEffectsSourceData["$pref::Shadows::disable"] then
        generalEffectsKeysReplaced["$pref::Shadows::disable"].ptr[0] = generalEffectsSourceData["$pref::Shadows::disable"]==2
    end
    generalEffectsKeysSorted = tableKeysSorted(generalEffectsKeys)
end

local function onZeitGraphicsHistoryCommit()
    historySaveTime = 2
end

local function onZeitGraphicsLoaded()
    if zeit_rcUI_select then
        zeit_rcUI_select.addEntry("edit", {
            id = "zeit_rcUI_edit",
            name = "Profile Editor",
            texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/edit.png")
        })
    end
end

local function onExtensionLoaded()
end

M.onUpdate = onUpdate
M.toggleUI = toggleUI
M.onExtensionLoaded = onExtensionLoaded
M.onZeitGraphicsSettingsChange = onZeitGraphicsSettingsChange
M.onZeitGraphicsHistoryCommit = onZeitGraphicsHistoryCommit
M.onZeitGraphicsLoaded = onZeitGraphicsLoaded
M.onFileChanged = onFileChanged

return M