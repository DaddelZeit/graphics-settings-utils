-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local im = ui_imgui
local style = require("zeit/rcTool/style")

local undoImage = im.ImTextureHandler("/settings/zeit/rendercomponents/edit/undo.png")
local redoImage = im.ImTextureHandler("/settings/zeit/rendercomponents/edit/redo.png")

M.showUI = false

local disabledNoLevel = false

local SSAOContrast = im.FloatPtr(0)
local SSAORadius = im.FloatPtr(0)
local SSAOHighQuality = false

local GeneralEffectsEntryKeyNew = im.ArrayChar(256)

local generalEffectsDirty = false
local generalEffectsKeysReplaced
local generalEffectsValues = {}
local generalEffectsKeys = {}
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
local uiFpsValue = im.FloatPtr(30)
local queueEditorOpen = false

local customPFXVals = {
    ContrastPFX = im.BoolPtr(0),
    ContrastPFXValue = im.FloatPtr(1),
    SaturationPFXValue = im.FloatPtr(1),

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
    LetterboxColorPFX = ffi.new("float[3]", {0, 0, 0}),
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

local exportFormat = 1
local exportFormats = {
    "Default",
    "BeamNG Forums",
    "Discord"
}
local exportInfo = im.BoolPtr(true)

local exported = false
local exportTime = 0

local exportedZip = false
local exportZipTime = 0

local imported = false
local importTime = 0

M.historySaveTime = 0

local function horizontalSeparator(height)
    local cursorPos = im.GetCursorScreenPos()
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), cursorPos, im.ImVec2(cursorPos.x+1, cursorPos.y+height), im.GetColorU321(im.Col_SeparatorHovered), 0, 0)
    im.Dummy(im.ImVec2(1,0))
end

local function resizeFont(scale)
    local scaledFont = im.GetFont()
    local prevSize = scaledFont.Scale
    scaledFont.Scale = scale
    im.PushFont(scaledFont)
    scaledFont.Scale = prevSize
end

local function tooltipButton(inp)
    inp = inp or {}
    im.PushStyleColor1(im.Col_ButtonActive, im.GetColorU321(im.Col_ButtonHovered))
    im.Button("?")
    im.PopStyleColor()
    if im.IsItemHovered() then
        im.BeginTooltip()
        resizeFont(1.25)
        if inp.desc then im.Text(inp.desc) end
        im.PopFont()
        if inp.default then im.Text("Default: "..inp.default) end
        if inp.varName then im.Text("Variable Name: "..inp.varName) end
        if inp.varType then im.Text("Variable Type: "..inp.varType) end
        im.EndTooltip()
    end
end

local function renderInt(id, min, max, format)
    local value = generalEffectsKeysReplaced[id]
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = value.default,
        varName = id,
        varType = "int"
    })
    im.SameLine()
    local lastAction = value.active
    if im.SliderInt(value.name or ("##"..id), value.ptr, min, max, format, 0) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0]) end
    end
    value.active = im.IsItemActive()
    return not value.active and lastAction
end
local function renderFloat(id, min, max, format)
    local value = generalEffectsKeysReplaced[id]
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = value.default,
        varName = id,
        varType = "float"
    })
    im.SameLine()
    local lastAction = value.active
    if im.SliderFloat(value.name or ("##"..id), value.ptr, min, max, format, 0) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0]) end
    end
    value.active = im.IsItemActive()
    return not value.active and lastAction
end
local function renderCheckbox(id, min, max)
    local value = generalEffectsKeysReplaced[id]
    tooltipButton({
        name = value.name,
        desc = value.desc,
        default = tostring(value.default),
        varName = id,
        varType = "bool"
    })
    im.SameLine()
    local lastAction = value.active
    if im.Checkbox(value.name or ("##"..id), value.ptr) then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(id, value.ptr[0] and (max or 1) or (min or 0)) end
    end
    value.active = im.IsItemActive()
    return not value.active and lastAction
end

local modules = {
    menubar = function(dtReal)
        im.BeginMenuBar()
        local menuBarHeight = im.GetFont().FontSize + im.GetStyle().FramePadding.y * 2

        local buttonSize = im.CalcTextSize("").y*1.25
        local undo = zeit_rcMain.currentRollBack < zeit_rcMain.maxRollBack
        if not undo then im.BeginDisabled() end
        if im.ImageButton("##undobtn", undoImage:getID(), im.ImVec2(buttonSize,buttonSize)) then
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
        if im.ImageButton("##redobtn", redoImage:getID(), im.ImVec2(buttonSize,buttonSize)) then
            zeit_rcMain.redo()
        end
        if im.IsItemHovered() then
            im.BeginTooltip()
            im.Text("Redo")
            im.EndTooltip()
        end
        if not redo then im.EndDisabled() end
        im.SameLine()

        M.historySaveTime = math.max(M.historySaveTime - dtReal, 0.2)
        im.TextColored(im.ImVec4(1,1,1,M.historySaveTime), " History Saved")

        horizontalSeparator(menuBarHeight)

        if im.Button("Open Profile Manager") then
            zeit_rcUI_profileManager.toggleUI()
        end

        horizontalSeparator(menuBarHeight)

        im.Button("Open Mod Page")
        if im.IsItemHovered() then
            if im.IsMouseClicked(1) then
                openWebBrowser("https://beamng.com/threads/85768/")
            elseif im.IsMouseClicked(0) then
                be:queueJS([[open("https://beamng.com/threads/85768/")]])
            end
        end

        horizontalSeparator(menuBarHeight)

        if im.BeginMenu("Save") then
            if im.MenuItem1("Save Profile") then
                zeit_rcMain.saveCurrentProfile(true)
            end
            if im.MenuItem1("Save Profile As") then
                zeit_rcMain.saveCurrentProfile(false)
            end
            im.EndMenu()
        end
        if im.MenuItem1("Load") then
            zeit_rcMain.loadProfile()
        end

        horizontalSeparator(menuBarHeight)

        if im.BeginMenu("Export") then
            im.Text("Format:")
            im.SameLine()
            if im.BeginCombo("##FormatSelector", exportFormats[exportFormat]) then
                for k,v in pairs(exportFormats) do
                    if im.Selectable1(v, k == exportFormat) then
                        exportFormat = k
                    end
                end
                im.EndCombo()
            end
            if im.Button("Export to Clipboard") then
                exported = require("zeit/rcTool/export").exportProfileToClipboard(zeit_rcMain.currentProfile, exportFormat, exportInfo[0])
                exportTime = 2
            end
            im.SameLine()
            im.Checkbox("Export Info", exportInfo)
            if exportTime > 0 then
                if exported then
                    exportTime = math.max(exportTime - dtReal*2, 0)
                    im.TextColored(im.ImVec4(1,1,1,exportTime), "Successfully exported.")
                else
                    im.TextColored(im.ImVec4(1,0.6,0.6,exportTime), "Export failed. See console for details.")
                end
            end

            im.Separator()

            if im.Button("Export as Mod") then
                local path
                exportedZip, path = require("zeit/rcTool/export").exportProfileAsMod(zeit_rcMain.currentProfile)
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
            if im.Button("Import") then
                imported = require("zeit/rcTool/export").importProfileFromClipboard()
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
        im.EndMenuBar()
    end,
    renderComponents = function()
        im.Text('These settings can be edited using the "Renderer Components" world editor window.')

        if im.Button("Open Window in World Editor") then
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
        if im.Button("Save \"HDR\" and \"Bloom\" Settings") then
            if zeit_rc_rendercomponents then zeit_rc_rendercomponents.getAndSaveSettings() end
        end
        im.PopID()

        im.SameLine()
        horizontalSeparator(im.CalcTextSize("").y+style.ItemInnerSpacing.y)
        im.SameLine()

        im.PushID1("DOFSettings")
        if im.Button("Save \"Depth of Field\" Settings") then
            if zeit_rc_dof then zeit_rc_dof.getAndSaveSettings() end
        end
        im.SameLine()
        if im.Checkbox("Auto Focus", autofocusCheckbox) then
            if zeit_rc_autofocus then zeit_rc_autofocus.toggle(autofocusCheckbox[0]) end
        end

        im.PopID()
    end,
    ui = function()
        im.PushID1("UISettings")
        tooltipButton({
            desc = "Interface FPS Limiter",
            default = "30",
            varName = "CefGui::maxFPSLimit",
            varType = "int"
        })
        im.SameLine()
        if im.SliderFloat("Max UI FPS", uiFpsValue, 1, 60, "%.0f") then
            if zeit_rc_uifps then zeit_rc_uifps.getAndSaveSettings(uiFpsValue[0]) end
        end
        im.PopID()
    end,
    customPostFx = function()
        if im.Checkbox("##ContrastSaturationEnabled", customPFXVals.ContrastPFX) then
            if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.setEnabled(customPFXVals.ContrastPFX[0]) end
        end
        im.SameLine()
        if im.CollapsingHeader1("Contrast/Saturation") then
            im.Indent()
            im.Indent()
            im.PushID1("ContSatSettings")
            tooltipButton({
                desc = "Contrast modifier to add additionally.",
                default = "1",
                varName = "ContrastSaturationPostFX.Contrast",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Contrast", customPFXVals.ContrastPFXValue, 0, 2, "%.3f") then
                if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0]) end
            end

            tooltipButton({
                desc = "Saturation modifier to add additionally.",
                default = "1",
                varName = "ContrastSaturationPostFX.Saturation",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Saturation", customPFXVals.SaturationPFXValue, 0, 2, "%.3f") then
                if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(customPFXVals.ContrastPFXValue[0], customPFXVals.SaturationPFXValue[0]) end
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

            tooltipButton({
                desc = "The maximum vignette size equals this times the screen size.",
                default = "0",
                varName = "VignettePostFX.Vmax",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Maximum Scalar", customPFXVals.VmaxPFXValue, 0, 2, "%.3f") then
                if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
            end

            tooltipButton({
                desc = "The minimum vignette size equals this times the screen size.",
                default = "0",
                varName = "VignettePostFX.Vmin",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Minimum Scalar", customPFXVals.VminPFXValue, 0, 2, "%.3f") then
                if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
            end

            tooltipButton({
                desc = "Color of the vignette.",
                default = "0 0 0",
                varName = "VignettePostFX.Color",
                varType = "float[3]"
            })
            im.SameLine()
            if im.ColorEdit3("Color##Vignette", customPFXVals.ColorPFX, 0) then
                if zeit_rc_vignette then zeit_rc_vignette.getAndSaveSettings(customPFXVals.VmaxPFXValue[0], customPFXVals.VminPFXValue[0], {customPFXVals.ColorPFX[0], customPFXVals.ColorPFX[1], customPFXVals.ColorPFX[2]}) end
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

            tooltipButton({
                desc = "Sharpness modifier to apply to the screen.",
                default = "0",
                varName = "SharpenPostFX.Sharpness",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Sharpness", customPFXVals.SharpnessPFXValue, 0, 2, "%.3f") then
                if zeit_rc_sharpen then zeit_rc_sharpen.getAndSaveSettings(customPFXVals.SharpnessPFXValue[0]) end
            end
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

            tooltipButton({
                desc = "How visible the grain is. Higher is more visible.",
                default = "0.5",
                varName = "FilmGrainPostFX.Intensity",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Intensity", customPFXVals.FilmgrainPFXIntensityValue, 0, 10, "%.3f") then
                if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
            end

            tooltipButton({
                desc = "Controls the variance of the Gaussian noise. Lower values look smoother.",
                default = "0.4",
                varName = "FilmGrainPostFX.Variance",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Variance", customPFXVals.FilmgrainPFXVarianceValue, 0, 1, "%.3f") then
                if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
            end

            --[[
            tooltipButton({
                desc = "Affects the brightness of the noise.",
                default = "0.5",
                varName = "FilmGrainPostFX.Mean",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Mean", customPFXVals.FilmgrainPFXMeanValue, 0, 1, "%.2f") then
                if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
            end
            ]]

            tooltipButton({
                desc = "Higher Signal-to-Noise Ratio values give less grain to brighter pixels. 0 disables this feature.",
                default = "6",
                varName = "FilmGrainPostFX.SignalToNoiseRatio",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Signal To Noise Ratio", customPFXVals.FilmgrainPFXSignalToNoiseRatioValue, 0, 15, "%.2f") then
                if zeit_rc_filmgrain then zeit_rc_filmgrain.getAndSaveSettings(customPFXVals.FilmgrainPFXIntensityValue[0], customPFXVals.FilmgrainPFXVarianceValue[0], customPFXVals.FilmgrainPFXMeanValue[0], customPFXVals.FilmgrainPFXSignalToNoiseRatioValue[0]) end
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

            tooltipButton({
                desc = "The height of one bar equals the screen height times this value.",
                default = "0",
                varName = "LetterboxPostFX.uvY1, LetterboxPostFX.uvY2",
                varType = "float"
            })
            im.SameLine()
            if im.SliderFloat("Height", customPFXVals.HeightPFXValue, 0, 0.5, "%.3f") then
                if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}) end
            end

            tooltipButton({
                desc = "Color of the letterbox.",
                default = "0 0 0",
                varName = "LetterboxPostFX.Color",
                varType = "float[3]"
            })
            im.SameLine()
            if im.ColorEdit3("Color##Letterbox", customPFXVals.LetterboxColorPFX, 0) then
                if zeit_rc_letterbox then zeit_rc_letterbox.getAndSaveSettings(customPFXVals.HeightPFXValue[0], {customPFXVals.LetterboxColorPFX[0], customPFXVals.LetterboxColorPFX[1], customPFXVals.LetterboxColorPFX[2]}) end
            end
            im.PopID()
            im.Unindent()
            im.Unindent()
        end
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
                tooltipButton({
                    desc = "The texture size of the shadow map.",
                    default = tostring(zeit_rc_shadowsettings.origValues.texSize or "/"),
                    varName = "ScatterSky::texSize",
                    varType = "int"
                })
                im.SameLine()
                if im.SliderInt("Texture Size", shadowVals.TexSizeValue, 256, 2048, "%d") then
                    scenetree.sunsky.texSize = shadowVals.TexSizeValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "The ESM shadow darkening factor. Controls how dark each split of the shadow map is.",
                    default = tostring(zeit_rc_shadowsettings.origValues.overDarkFactor or "/"),
                    varName = "ScatterSky::overDarkFactor",
                    varType = "float[4]"
                })
                im.SameLine()
                if im.SliderFloat4("Over Dark Factor", shadowVals.OverDarkValue, 256, 131072, "%.3f") then
                    scenetree.sunsky.overDarkFactor.x = shadowVals.OverDarkValue[0]
                    scenetree.sunsky.overDarkFactor.y = shadowVals.OverDarkValue[1]
                    scenetree.sunsky.overDarkFactor.z = shadowVals.OverDarkValue[2]
                    scenetree.sunsky.overDarkFactor.w = shadowVals.OverDarkValue[3]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "The distance from the camera to extend the PSSM shadow.",
                    default = tostring(zeit_rc_shadowsettings.origValues.shadowDistance or "/"),
                    varName = "ScatterSky::shadowDistance",
                    varType = "float"
                })
                im.SameLine()
                if im.SliderFloat("Shadow Distance", shadowVals.ShadowDistanceValue, 500, 5000, "%.3f") then
                    scenetree.sunsky.shadowDistance = shadowVals.ShadowDistanceValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "How much filtering is applied to the shadow edges.",
                    default = tostring(zeit_rc_shadowsettings.origValues.shadowSoftness or "/"),
                    varName = "ScatterSky::shadowSoftness",
                    varType = "float"
                })
                im.SameLine()
                if im.SliderFloat("Shadow Softness", shadowVals.ShadowSoftnessValue, 0, 1, "%.3f") then
                    scenetree.sunsky.shadowSoftness = shadowVals.ShadowSoftnessValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "How many times the shadow is split up into sections.",
                    default = tostring(zeit_rc_shadowsettings.origValues.numSplits or "/"),
                    varName = "ScatterSky::numSplits",
                    varType = "int"
                })
                im.SameLine()
                if im.SliderInt("Number of splits", shadowVals.NumSplitsValue, 1, 4, "%d") then
                    scenetree.sunsky.numSplits = shadowVals.NumSplitsValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "The logarithmic PSSM split distance factor.",
                    default = tostring(zeit_rc_shadowsettings.origValues.logWeight or "/"),
                    varName = "ScatterSky::logWeight",
                    varType = "float"
                })
                im.SameLine()
                if im.SliderFloat("Logarithmic Weight", shadowVals.LogWeightValue, 0, 1, "%.3f") then
                    scenetree.sunsky.logWeight = shadowVals.LogWeightValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "Start fading shadows out at this distance. 0 = auto calculate this distance.",
                    default = tostring(zeit_rc_shadowsettings.origValues.fadeStartDistance or "/"),
                    varName = "ScatterSky::fadeStartDistance",
                    varType = "float"
                })
                im.SameLine()
                if im.SliderFloat("Fade Start Distance", shadowVals.FadeDistanceValue, 0, 4000, "%.3f") then
                    scenetree.sunsky.fadeStartDistance = shadowVals.FadeDistanceValue[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end

                tooltipButton({
                    desc = "This toggles only terrain being rendered in the last split of a PSSM shadow map.",
                    default = tostring(zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly == nil and "/" or (zeit_rc_shadowsettings.origValues.lastSplitTerrainOnly == "1")),
                    varName = "ScatterSky::lastSplitTerrainOnly",
                    varType = "bool"
                })
                im.SameLine()
                if im.Checkbox("Terrain only in last split", shadowVals.LastSplitTerrainOnly) then
                    scenetree.sunsky.lastSplitTerrainOnly = shadowVals.LastSplitTerrainOnly[0]
                    if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
                end
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
        local _value = generalEffectsKeysReplaced["$pref::lightManager"]
        tooltipButton({
            desc = _value.desc,
            default = _value.default,
            varName = "$pref::lightManager",
            varType = "string"
        })
        im.SameLine()
        if im.BeginCombo(_value.name, _value.ptr) then
            for _,k in ipairs({"Basic Lighting", "Advanced Lighting", "Advanced Lighting 1.5"}) do
                if im.Selectable1(k, k==_value.ptr) then
                    if zeit_rc_generaleffects then
                        if k == "Basic Lighting" then
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "None")
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::disable", 2)
                            zeit_rc_generaleffects.addSetting("$pref::Shadows::textureScalar", 0.5)
                        end
                        zeit_rc_generaleffects.addSetting("$pref::lightManager", k)
                        setLightManager(TorqueScriptLua.getVar("$pref::lightManager"))
                    end
                end
            end
            im.EndCombo()
        end

        local currentLightManager = ffi.string(generalEffectsKeysReplaced["$pref::lightManager"].ptr)
        if currentLightManager == "Basic Lighting" then
            im.Text("This Light Manager does not support shadows.")
            im.BeginDisabled()
        end
        local __value = generalEffectsKeysReplaced["$pref::Shadows::filterMode"]
        tooltipButton({
            desc = __value.desc,
            default = __value.default,
            varName = "$pref::Shadows::filterMode",
            varType = "string"
        })

        im.SameLine()
        if im.BeginCombo(__value.name, __value.ptr) then
            if im.Selectable1("None", "None"==__value.ptr) then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "None") end
            end
            if im.Selectable1("SoftShadow", "SoftShadow"==__value.ptr) then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "SoftShadow") end
            end
            if im.Selectable1("SoftShadowHighQuality", "SoftShadowHighQuality"==__value.ptr) then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting("$pref::Shadows::filterMode", "SoftShadowHighQuality") end
            end
            im.EndCombo()
        end

        renderCheckbox("$pref::Shadows::disable", nil, 2)
        renderCheckbox("$pref::imposter::canShadow")
        renderFloat("$pref::Shadows::textureScalar", 0.5, 2, "%.1f")
        if currentLightManager == "Basic Lighting" then
            im.EndDisabled()
        end
        im.PopID()
    end,
    ssao = function()
        im.PushID1("SSAOSettings")

        local dirty = false
        tooltipButton({
            desc = "Sets the contrast/intensity of the ambient occlusion.",
            default = "2",
            varName = "PostEffectSSAO::setContrast",
            varType = "float"
        })
        im.SameLine()
        if im.SliderFloat("Contrast", SSAOContrast, 0, 10, "%.3f", 0) then
            dirty = true
        end

        tooltipButton({
            desc = "Maximum radius of the ambient occlusion spread.",
            default = "1.5",
            varName = "PostEffectSSAO::setRadius",
            varType = "float"
        })
        im.SameLine()
        if im.SliderFloat("Radius", SSAORadius, 0, 10, "%.3f", 0) then
            dirty = true
        end

        local width = (im.CalcItemWidth()/2)-style.ItemInnerSpacing.x+1
        tooltipButton({
            desc = "The amount of samples SSAO uses.",
            default = "16",
            varName = "PostEffectSSAO::setSamples",
            varType = "int"
        })
        im.SameLine()
        local _SSAOHighQuality = SSAOHighQuality
        if SSAOHighQuality then im.BeginDisabled() end
        if im.Button("High", im.ImVec2(width, 0)) then
            _SSAOHighQuality = true
            dirty = true
        end
        if SSAOHighQuality then im.EndDisabled() end
        im.SameLine()
        if not SSAOHighQuality then im.BeginDisabled() end
        if im.Button("Low", im.ImVec2(width, 0)) then
            _SSAOHighQuality = false
            dirty = true
        end
        if not SSAOHighQuality then im.EndDisabled() end
        SSAOHighQuality = _SSAOHighQuality

        im.SameLine()
        im.Text("Quality")

        if dirty and SSAOContrast and SSAORadius then
            if zeit_rc_ssao then zeit_rc_ssao.getAndSaveSettings(SSAOContrast[0], SSAORadius[0], SSAOHighQuality and 32 or 16) end
        end

        im.PopID()
    end,
    generalEffects = function()
        im.PushID1("GeneralSettings")
        im.PopID()

        local n = 0
        for k,v in pairs(generalEffectsKeys) do
            n=n+1
            im.PushID1(tostring(k))

            local key = ffi.string(v)
            local valueData = generalEffectsValues[key]
            if not valueData.desc then
                im.BeginDisabled()
                im.Button("?")
                im.EndDisabled()
            else
                tooltipButton({
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
            generalEffectsValues[k].res = val
            im.SameLine()

            generalEffectsDirty = generalEffectsDirty or (keyChanged or changed)
            im.SameLine()

            if generalEffectsDirty then
                im.BeginDisabled()
                im.Button("Remove", im.ImVec2(im.GetContentRegionAvailWidth(), 0))
                im.EndDisabled()
            else
                if im.Button("Remove", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(key, nil) end
                    generalEffectsKeys[k] = nil
                    generalEffectsValues[k] = nil
                end
            end
            im.PopID(tostring(k))
        end

        if not generalEffectsDirty then
            im.BeginDisabled()
            im.Button("Apply Changes", im.ImVec2(im.GetContentRegionAvailWidth(), 0))
            im.EndDisabled()
        else
            if im.Button("Apply Changes", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
                generalEffectsDirty = false
                if zeit_rc_generaleffects then
                    for k,v in pairs(generalEffectsValues) do
                        if k ~= "" and v.res then
                            zeit_rc_generaleffects.addSetting(k, v.res, true)
                        end
                    end
                    zeit_rc_generaleffects.saveSettings()
                end
            end
        end
    end,
    newGeneralEffects = function()
        im.PushID1("NewGeneralSettings")

        local selected = ffi.string(GeneralEffectsEntryKeyNew)
        local function validateInput(key)
            selected = key
        end

        if im.BeginCombo("###GeneralEffectsEntryDropdown", "", im.ComboFlags_NoPreview) then
            for _,k in ipairs(generalEffectsAvailableKeys) do
                if not generalEffectsKeys[k] then
                    local v = generalEffectsValues[k]
                    tooltipButton({
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
        local val = typeMatchRender[valueData.type or "str"]("###GeneralEffectsEntryValNew", valueData.ptr, valueData.min, valueData.max, valueData.format)

        im.SameLine()
        im.PopID()

        local keystring = ffi.string(GeneralEffectsEntryKeyNew)
        if keystring ~= "" and val then
            if im.Button("Add", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
                ffi.copy(GeneralEffectsEntryKeyNew, "")
                if zeit_rc_generaleffects then
                    zeit_rc_generaleffects.addSetting(keystring, val)
                end
            end
        else
            im.BeginDisabled()
            im.Button("Add", im.ImVec2(im.GetContentRegionAvailWidth(), 0))
            im.EndDisabled()
        end
    end,
    detail = function()
        im.PushID1("LevelDetail")

        im.Text("Mesh and Terrain")
        renderFloat("$pref::TS::detailAdjust", 0.25, 2, "%.3f")
        renderFloat("$pref::Terrain::lodScale", 0.25, 2, "%.3f")
        renderFloat("$pref::GroundCover::densityScale", 0, 3, "%.3f")
        renderInt("$pref::TS::smallestVisiblePixelSize", -1, 250, "%d")

        im.Text("Textures")
        renderFloat("$pref::Terrain::detailScale", 0.25, 2, "%.3f")
        renderInt("$pref::Video::textureReductionLevel", 0, 4, "%d")

        im.Text("Other")
        renderFloat("$pref::Camera::distanceScale", 0.05, 2, "%.3f")
        renderInt("$pref::TS::maxDecalCount", 0, 10000, "%d")
        renderCheckbox("$pref::TS::skipRenderDLs")

        im.PopID()
    end,
    reflection = function()
        im.Text("Environment")
        renderCheckbox("$pref::Water::disableTrueReflections")
        renderFloat("$pref::Reflect::refractTexScale", 0.25, 2, "%.3f")
        im.Text("Vehicle")
        renderCheckbox("$pref::BeamNGVehicle::dynamicMirrors::enabled")
        renderFloat("$pref::BeamNGVehicle::dynamicMirrors::detail", 0, 1, "%.3f")
        renderInt("$pref::BeamNGVehicle::dynamicMirrors::distance", 0, 4000, "%d")
        renderInt("$pref::BeamNGVehicle::dynamicMirrors::textureSize", 0, 8096, "%d")
        im.NewLine()
        renderCheckbox("$pref::BeamNGVehicle::dynamicReflection::enabled")
        renderFloat("$pref::BeamNGVehicle::dynamicReflection::detail", 0, 1, "%.3f")
        renderInt("$pref::BeamNGVehicle::dynamicReflection::distance", 0, 4000, "%d")
        renderInt("$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate", 0, 6, "%d")
        renderInt("$pref::BeamNGVehicle::dynamicReflection::textureSize", 0, 2048, "%d")
    end
}

local function render(dtReal)
    im.Begin("Graphics Settings Utils - BeamNG "..beamng_versionb, nil, im.WindowFlags_AlwaysAutoResize + im.WindowFlags_MenuBar)

    if not getCurrentLevelIdentifier() then -- no map loaded, no work
        im.Separator()
        im.Text("No map detected, please load a map.")
        disabledNoLevel = true
        im.Separator()
        im.BeginDisabled()
    else disabledNoLevel = false end

    modules.menubar(dtReal)

    if im.CollapsingHeader1("HDR/DOF") then
        modules.renderComponents()
    end
    im.Separator()
    if im.CollapsingHeader1("UI") then
        modules.ui()
    end
    im.Separator()
    if im.CollapsingHeader1("Post Effects") then
        modules.customPostFx()
    end
    im.Separator()
    if im.CollapsingHeader1("Shadows") then
        modules.shadow()
        im.Separator()
        modules.shadowVars()
    end
    im.Separator()
    if im.CollapsingHeader1("Ambient Occlusion") then
        modules.ssao()
    end
    im.Separator()
    if im.CollapsingHeader1("Environment") then
        modules.detail()
    end
    im.Separator()
    if im.CollapsingHeader1("Reflection") then
        modules.reflection()
    end
    im.Separator()
    if im.CollapsingHeader1("General Effects") then
        modules.generalEffects()
        im.Separator()
        modules.newGeneralEffects()
    end

    if disabledNoLevel == true then im.EndDisabled() end
    im.End()
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
        log("E", "onUpdate", err)
    end

    style.pop()
end

local function initSettings(CURSET)
    local defaultvars = rerequire("zeit/rcTool/defaultVars")
    generalEffectsKeysReplaced = defaultvars.get()

    SSAOContrast[0] = CURSET.ssao and CURSET.ssao.contrast or 2
    SSAORadius[0] = CURSET.ssao and CURSET.ssao.radius or 1.5
    SSAOHighQuality = (CURSET.ssao and CURSET.ssao.samples or 16) == 32
    uiFpsValue[0] = math.ceil(CURSET.uifps and CURSET.uifps.fps or 30)

    customPFXVals.ContrastPFX[0] = CURSET.contrastsaturation ~= nil
    customPFXVals.ContrastPFXValue[0] = CURSET.contrastsaturation and CURSET.contrastsaturation.contrast or 1
    customPFXVals.SaturationPFXValue[0] = CURSET.contrastsaturation and CURSET.contrastsaturation.saturation or 1

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
    if CURSET.letterbox and CURSET.letterbox.color then
        customPFXVals.LetterboxColorPFX[0] = CURSET.letterbox.color[1]
        customPFXVals.LetterboxColorPFX[1] = CURSET.letterbox.color[2]
        customPFXVals.LetterboxColorPFX[2] = CURSET.letterbox.color[3]
    else
        customPFXVals.LetterboxColorPFX[0] = 0
        customPFXVals.LetterboxColorPFX[1] = 0
        customPFXVals.LetterboxColorPFX[2] = 0
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

    -- get autofocus state
    autofocusCheckbox[0] = CURSET.autofocus and CURSET.autofocus.isEnabled or false
end

local function toggleUI()
    M.showUI = not M.showUI

    if not M.showUI then
        zeit_rcMain.saveSettings(zeit_rcMain.currentSettings)
    end
end

local function onExtensionLoaded()
end

M.onUpdate = onUpdate
M.toggleUI = toggleUI
M.onExtensionLoaded = onExtensionLoaded
M.initSettings = initSettings

return M