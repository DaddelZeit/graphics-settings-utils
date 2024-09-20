-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local im = ui_imgui

M.showUI = false

-- local profileDirty = false
local disabledNoLevel = false

local SSAOContrast = im.ArrayChar(256)
local SSAORadius = im.ArrayChar(256)
local SSAOSamples = im.ArrayChar(256)

local GeneralEffectsEntryKeyNew = im.ArrayChar(256)
local GeneralEffectsEntryValNew = im.ArrayChar(256)

local generalEffectsSourceData = {}
local generalEffectsValues = {}
local generalEffectsKeys = {}

local autofocusCheckbox = im.BoolPtr(false)
local uiFpsValue = im.FloatPtr(30)

local contrastPFXValue = im.FloatPtr(1)
local saturationPFXValue = im.FloatPtr(1)

local function onUpdate()
    if not M.showUI then return end

    im.Begin("Graphics Settings Utils - BeamNG "..beamng_versionb, nil, im.WindowFlags_AlwaysAutoResize)

    if im.Button("Open Profile Manager") then
        zeit_rcProfileManager.toggleUI()
    end
    im.SameLine()
    if im.Button("Save Profile") then
        zeit_rcMain.saveCurrentProfile(true)
        -- profileDirty = false
    end
    im.SameLine()
    if im.Button("Save Profile As") then
        zeit_rcMain.saveCurrentProfile(false)
        -- profileDirty = false
    end
    im.SameLine()
    if im.Button("Load Profile") then
        zeit_rcMain.loadProfile()
    end

    if not getCurrentLevelIdentifier() then -- no map loaded, no work
        im.Text("No map detected, please load a map.")
        disabledNoLevel = true
        im.BeginDisabled()
    else disabledNoLevel = false end

    im.Separator()
    im.PushID1("RenderComponents")
    im.Text("Renderer Components Save&Load")
    if im.Button("Get and Save Settings") then
        if zeit_rc_rendercomponents then zeit_rc_rendercomponents.getAndSaveSettings() end
        -- profileDirty = true
    end
    im.PopID()

    im.Text("Depth of Field Save&Load")
    im.PushID1("DOFSettings")
    if im.Button("Get and Save Settings") then
        if zeit_rc_dof then zeit_rc_dof.getAndSaveSettings() end
        -- profileDirty = true
    end
    im.SameLine()
    if im.Checkbox("Auto Focus", autofocusCheckbox) then
        if zeit_rc_autofocus then zeit_rc_autofocus.toggle(autofocusCheckbox[0]) end
        -- profileDirty = true
    end

    im.Text('These settings can be edited using the "Renderer Components" world editor window.')
    --im.Text('You can open this window by opening the world editor, clicking on "Window" \nand then searching for "Renderer Components".')

    if im.Button("Open Window in World Editor") then
        if not editor.isEditorActive() then
            editor.toggleActive()
        end
        editor.showWindow("rendererComponents")
    end
    im.SameLine()
    im.Text('This button will open the world editor and show the appropiate window.')
    im.PopID()

    im.Separator()
    im.PushID1("UISettings")
    if im.SliderFloat("Max UI FPS", uiFpsValue, 1, 60, "%.0f") then
        if zeit_rc_uifps then zeit_rc_uifps.getAndSaveSettings(uiFpsValue[0]) end
        -- profileDirty = true
    end
    im.PopID()
    im.Separator()
    im.Text("Contrast & Saturation Adjust")
    im.PushID1("ContSatSettings")
    if im.SliderFloat("Contrast", contrastPFXValue, 0, 2, "%.5f") then
        if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(contrastPFXValue[0], saturationPFXValue[0]) end
        -- profileDirty = true
    end
    if im.SliderFloat("Saturation", saturationPFXValue, 0, 2, "%.5f") then
        if zeit_rc_contrastsaturation then zeit_rc_contrastsaturation.getAndSaveSettings(contrastPFXValue[0], saturationPFXValue[0]) end
        -- profileDirty = true
    end
    im.PopID()

    im.Separator()
    im.PushID1("ShadowSettings")
    im.Text("Shadow Settings Save&Load")
    if im.Button("Get and Save Settings") then
        if zeit_rc_shadowsettings then zeit_rc_shadowsettings.getAndSaveSettings() end
        -- profileDirty = true
    end
    im.Text('These settings can be found in the sky object (usually "sunsky") and edited using world editor.')
    --im.Text('After opening the editor there is a list of objects with a search bar on the left.')
    if scenetree.sunsky then
        if im.Button("Select Object in World Editor") then
            if not editor.isEditorActive() then
                editor.toggleActive()
            end
            editor.selectObjectById(scenetree.sunsky:getId())
        end
        im.SameLine()
        im.Text('This button will open the world editor and select the appropiate object.')
    else
        im.BeginDisabled()
        im.Button("Select Object in World Editor")
        im.EndDisabled()
    end
    im.PopID()
    im.Separator()
    im.PushID1("SSAOSettings")
    im.Text("SSAO Settings Save&Load")

    if tonumber(ffi.string(SSAOContrast)) and tonumber(ffi.string(SSAORadius)) and tonumber(ffi.string(SSAOSamples)) then
        if im.Button("Save Settings") then
            if zeit_rc_ssao then zeit_rc_ssao.getAndSaveSettings(tonumber(ffi.string(SSAOContrast)), tonumber(ffi.string(SSAORadius)), tonumber(ffi.string(SSAOSamples))) end
            -- profileDirty = true
        end
    else
        im.BeginDisabled()
        if im.Button("Save Settings") then
        end
        im.EndDisabled()
    end

    im.Text("SSAO Contrast: ") im.SameLine() im.InputText("##SSAOContrast", SSAOContrast)
    im.Text("SSAO Radius: ") im.SameLine() im.InputText("##SSAORadius", SSAORadius)
    im.Text("SSAO Samples: ") im.SameLine() im.InputText("##SSAOSamples", SSAOSamples)
    im.PopID()
    im.Separator()
    im.PushID1("GeneralSettings")
    im.Text("General Effect Settings Save&Load (for advanced users)")

    if im.Button("Save Settings") then
        if zeit_rc_generaleffects then zeit_rc_generaleffects.saveSettings() end
    end
    im.PopID()
    local n = 0
    if generalEffectsSourceData then
        for k,_ in pairs(generalEffectsSourceData) do
            n=n+1
            im.PushID1(tostring(k))
            im.InputText("###GeneralEffectsEntryKey"..tostring(n), generalEffectsKeys[k])
            im.SameLine()
            im.InputText("###GeneralEffectsEntryVal"..tostring(n), generalEffectsValues[k])
            im.SameLine()
            if tostring(ffi.string(generalEffectsKeys[k])) ~= "" and tonumber(ffi.string(generalEffectsValues[k])) then
                if im.Button("Save Setting") then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(ffi.string(generalEffectsKeys[k]), tonumber(ffi.string(generalEffectsValues[k]))) end
                    -- profileDirty = true
                end
            else
                im.BeginDisabled()
                if im.Button("Save Setting") then
                    if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(ffi.string(generalEffectsKeys[k]), tonumber(ffi.string(generalEffectsValues[k]))) end
                    -- profileDirty = true
                end
                im.EndDisabled()
            end
            im.SameLine()
            if im.Button("-") then
                if zeit_rc_generaleffects then zeit_rc_generaleffects.addSetting(ffi.string(generalEffectsKeys[k]), nil) end
                generalEffectsKeys[k] = nil -- cancel out
                generalEffectsValues[k] = nil -- cancel out
                generalEffectsSourceData[k] = nil -- cancel out
                -- profileDirty = true
            end
            im.PopID(tostring(k))
        end
    end

    -- to add new settings
    im.Separator()
    im.InputText("###GeneralEffectsEntryKeyNew", GeneralEffectsEntryKeyNew)
    im.SameLine()
    im.InputText("###GeneralEffectsEntryValNew", GeneralEffectsEntryValNew)
    im.SameLine()
    if tostring(ffi.string(GeneralEffectsEntryKeyNew)) ~= "" and tonumber(ffi.string(GeneralEffectsEntryValNew)) then
        if im.Button("+") then
            local keystring = ffi.string(GeneralEffectsEntryKeyNew)
            local valnum = tonumber(ffi.string(GeneralEffectsEntryValNew))

            generalEffectsKeys[keystring] = im.ArrayChar(256)
            ffi.copy(generalEffectsKeys[keystring], tostring(keystring))
            generalEffectsValues[keystring] = im.ArrayChar(256)
            ffi.copy(generalEffectsValues[keystring], tostring(valnum))
            generalEffectsSourceData[keystring] = ffi.string(GeneralEffectsEntryValNew)

            if zeit_rc_generaleffects then
                zeit_rc_generaleffects.addSetting(keystring, valnum)
                -- profileDirty = true
            end
        end
    else
        im.BeginDisabled()
        im.Button("+")
        im.EndDisabled()
    end

    -- if profileDirty == true then
    --     im.TextColored(im.ImVec4(1,0.4,0.4,1), "Profile unsaved")
    -- end
    if disabledNoLevel == true then im.EndDisabled() end
    im.End()
end

local function initSettings()
    ffi.copy(SSAOContrast, tostring(zeit_rcMain.currentSettings.ssao.contrast))
    ffi.copy(SSAORadius, tostring(zeit_rcMain.currentSettings.ssao.radius))
    ffi.copy(SSAOSamples, tostring(zeit_rcMain.currentSettings.ssao.samples))

    uiFpsValue = im.FloatPtr(math.ceil(zeit_rcMain.currentSettings.uifps.fps))
    contrastPFXValue = im.FloatPtr(zeit_rcMain.currentSettings.contrastsaturation.contrast)
    saturationPFXValue = im.FloatPtr(zeit_rcMain.currentSettings.contrastsaturation.saturation)

    -- load so imgui doesnt overwrite entire file
    generalEffectsSourceData = zeit_rcMain.currentSettings.generaleffects
    for k,v in pairs(generalEffectsSourceData) do
        generalEffectsKeys[k] = im.ArrayChar(256)
        ffi.copy(generalEffectsKeys[k], tostring(k))

        generalEffectsValues[k] = im.ArrayChar(256)
        ffi.copy(generalEffectsValues[k], tostring(v))
    end

    -- get autofocus state
    autofocusCheckbox[0] = zeit_rcMain.currentSettings.autofocus.isEnabled
end

local function toggleUI()
    M.showUI = not M.showUI

    initSettings()
end

local function onExtensionLoaded()
end

M.onUpdate = onUpdate
M.toggleUI = toggleUI
M.onExtensionLoaded = onExtensionLoaded
M.initSettings = initSettings

return M