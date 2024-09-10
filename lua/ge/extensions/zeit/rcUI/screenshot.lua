-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local widgets = require("zeit/rcUI/editWidgets")
local style = require("zeit/rcTool/style")

local setBgAlpha = false

M.showUI = false

local prevFOV = {}
local customSettings = {
    superSampling = im.IntPtr(1),
    downsample = im.BoolPtr(false),
    detail = im.FloatPtr(20),
    terrain = im.FloatPtr(0.001),
    groundcover = im.IntPtr(1),
    screenshotFormat = "png",
    motionblur = im.BoolPtr(false),
    motionblurAmount = im.FloatPtr(1),
    tilt = im.FloatPtr(0),
    fov = im.FloatPtr(0),
    grid = im.BoolPtr(false),
}

local initialTodState
local todState
local timeOfDay = im.FloatPtr(1)
local azimuthOverride = im.FloatPtr(0)

local presets = {
    ["1 to 1"] = {
        superSampling = 1,
        downsample = false,
        detail = 20,
        terrain = 0.001,
        groundcover = 1,
    },
    ["Normal"] = {
        superSampling = 4,
        downsample = true,
        detail = 20,
        terrain = 0.001,
        groundcover = 1,
    },
    ["Big"] = {
        superSampling = 9,
        downsample = false,
        detail = 20,
        terrain = 0.001,
        groundcover = 1,
    },
    ["Huge"] = {
        superSampling = 36,
        downsample = false,
        detail = 20,
        terrain = 0.001,
        groundcover = 8,
    }
}
local selectedPreset = 1
local keys = {
    "1 to 1",
    "Normal",
    "Big",
    "Huge"
}

local jobRunning = false
local function screenshot()
    if jobRunning then return end
    jobRunning = true

    local screenshotFolderString = getScreenShotFolderString()
    local path = string.format("screenshots/%s", screenshotFolderString)
    if not FS:directoryExists(path) then FS:directoryCreate(path) end
    local screenshotDateTimeString = getScreenShotDateTimeString()
    local subFilename = string.format("%s/screenshot_%s", path, screenshotDateTimeString)

    local fullFilename
    local screenshotNumber = 0
    repeat
      if screenshotNumber > 0 then
        fullFilename = FS:expandFilename(string.format("%s_%s", subFilename, screenshotNumber))
      else
        fullFilename = FS:expandFilename(subFilename)
      end
      screenshotNumber = screenshotNumber + 1
    until not FS:fileExists(fullFilename)
    zeit_rcMain.log('I','screenshot', "Taking screenshot "..fullFilename.."; Format = "..customSettings.screenshotFormat.."; superSampling = "..tostring(customSettings.superSampling[0]).. "; downsample = "..tostring(customSettings.downsample[0])..
    "; detail = "..tostring(customSettings.detail[0]).."; terrain = "..tostring(customSettings.terrain[0]).."; groundcover = "..tostring(customSettings.groundcover[0]).."; motionblur = "..tostring(customSettings.motionblur[0]))

    core_jobsystem.wrap(function(job)
        local prevDetail = TorqueScriptLua.getVar("$pref::TS::detailAdjust")
        local prevTerrain = TorqueScriptLua.getVar("$pref::Terrain::lodScale")
        local prevGroundcover = getGroundCoverScale()
        TorqueScriptLua.setVar("$pref::TS::detailAdjust", customSettings.detail[0])
        TorqueScriptLua.setVar("$pref::Terrain::lodScale", customSettings.terrain[0])
        setGroundCoverScale(customSettings.groundcover[0])
        flushGroundCoverGrids()

        SFXSystem.setGlobalParameter("g_FadeTimeMS", 100)
        SFXSystem.setGlobalParameter("g_GameLoading", 1)
        ui_visibility.set(false)
        scenetree.maincef:setHidden(true) -- usual method is not fast enough
        local prevPause = bullettime.getPause()
        job.sleep(0.495)
        if customSettings.motionblur[0] then
            bullettime.pause(false)
            be:setSimulationTimeScale(customSettings.motionblurAmount[0])
        end
        job.sleep(0.005)
        zeit_rcMain.log('I','screenshot', "Writing screenshot "..fullFilename)
        createScreenshot(fullFilename, customSettings.screenshotFormat, customSettings.superSampling[0], 1, 0, customSettings.downsample[0])
        job.sleep(0.005)
        if customSettings.motionblur[0] then
            bullettime.setInstant(bullettime.get())
            bullettime.pause(prevPause)
        end
        job.sleep(0.245)
        SFXSystem.setGlobalParameter("g_GameLoading", 0)
        SFXSystem.setGlobalParameter("g_FadeTimeMS", 1000)

        TorqueScriptLua.setVar("$pref::TS::detailAdjust", prevDetail)
        TorqueScriptLua.setVar("$pref::Terrain::lodScale", prevTerrain)
        setGroundCoverScale(prevGroundcover)
        flushGroundCoverGrids()
        ui_visibility.set(true)
        scenetree.maincef:setHidden(false)

        jobRunning = false
    end, 0.1)()
end

local function applyTimeOfDay()
    if todState then
        core_environment.setTimeOfDay(tableMerge(todState, {
            time = (timeOfDay[0]+0.5)%1,
            azimuthOverride = math.rad(azimuthOverride[0]),
        }))
    end
end

local function toggleUI(...)
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsPhoto", nil) end
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)

    local player = getPlayerVehicle(0)
    if M.showUI then
        customSettings.fov[0] = core_camera.getFovDeg()
        customSettings.screenshotFormat = settings.getValue("screenshotFormat")
        if player then
            for k,v in pairs(core_camera.getCameraDataById(player:getId())) do
                if k ~= "relative" then
                    prevFOV[k] = v.manualzoom and v.manualzoom.fov or v.fov
                end
            end
        end

        local tod = core_environment.getTimeOfDay()
        if tod then
            initialTodState = deepcopy(tod)
            todState = tod
            timeOfDay[0] = (tod.time+0.5)%1
            azimuthOverride[0] = math.deg(tod.azimuthOverride)
        end
    else
        if player then
            for k,v in pairs(core_camera.getCameraDataById(player:getId())) do
                if v.manualzoom then
                    v.manualzoom.fov = prevFOV[k] or v.manualzoom.fov
                else
                    v.fov = prevFOV[k] or v.fov
                end
            end
        end
        if initialTodState then
            core_environment.setTimeOfDay(initialTodState)
        end
        if core_camera.getActiveCamName() ~= 'path' then
            commands.setGameCamera()
        end
    end
end

local function selectPreset(preset)
    local _key = keys[preset or 0] or ""
    local _selectedPreset = presets[_key]
    if _selectedPreset then
        for k,v in pairs(_selectedPreset) do
            customSettings[k][0] = v
        end

        selectedPreset = preset
    end
end

local function renderTopBar()
    im.SetCursorPosY(-style.ItemSpacing.y+im.GetScrollY())
    im.PushFont3("cairo_bold")

    widgets.textCentered("Zeit's Graphics Utils: Photo Tool")

    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("X").x-style.ItemInnerSpacing.x*2-style.ItemSpacing.x*2)
    if widgets.button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)
    im.PopFont()

    im.Separator()
end

--[[
local function getOrientedRelativeRot(_tilt)
    local rot = core_camera.getQuat():toEulerYXZ()
    rot.x = math.deg(rot.x)
    rot.y = math.deg(-rot.y+math.pi)
    rot.z = math.deg(_tilt or rot.z)

    return rot
end
]]

local function verifyPreset()
    local _preset
    for i = 1, #keys do local preset = presets[keys[i]]
        for k,v in pairs(preset) do
            if customSettings[k][0] ~= v then goto next end
        end
        _preset = i
        ::next::
    end
    selectedPreset = _preset or 0
end

local function render(dt)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.5)
    end

    im.Begin("Zeit's Graphics Utils: Photo Tool", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_MenuBar + im.WindowFlags_NoResize + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse + im.WindowFlags_AlwaysAutoResize)

    im.BeginMenuBar()
    renderTopBar()
    im.EndMenuBar()

    im.SetNextItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("##DepthOfFieldControl", keys[selectedPreset] or "Custom") then
        for i = 1, #keys do
            if im.Selectable1(keys[i], selectedPreset == i) then
                selectPreset(i)
            end
        end
        im.EndCombo()
    end

    im.Separator()
    widgets.tooltipButton({
        desc = "Settings to apply for the screenshot only."
    })
    im.SameLine()
    im.Text("Photo Settings")

    local itemWidth = im.CalcItemWidth()-math.max(im.CalcTextSize("Super Sampling").x, im.CalcTextSize("Downsample").x, im.CalcTextSize("LOD Scale").x, im.CalcTextSize("Terrain LOD Scale").x, im.CalcTextSize("Ground Cover Scale").x, im.CalcTextSize("File Format").x)
    im.PushItemWidth(itemWidth)

    widgets.tooltipButton({
        desc = "Samples the output image back to the screen resolution."
    })
    im.SameLine()
    if im.Checkbox("Downsample", customSettings.downsample) then
        verifyPreset()
    end

    widgets.tooltipButton({
        desc = "Reduces edge artifacts by increasing output resolution."
    })
    im.SameLine()
    if im.SliderInt("Super Sampling", customSettings.superSampling, 1, 36) then
        verifyPreset()
    end

    widgets.tooltipButton({
        desc = "Output file format of the screenshot."
    })
    im.SameLine()
    local prevCursor = im.GetCursorPosY()
    im.SetCursorPosY(prevCursor - style.FramePadding.y * 2)
    if im.BeginTable("##photo_output_format", 2, im.TableFlags_SizingStretchSame+im.TableFlags_PreciseWidths, im.ImVec2(itemWidth, im.GetTextLineHeightWithSpacing())) then
        im.TableNextColumn()
        do
            local selected = customSettings.screenshotFormat == "png"
            if selected then im.BeginDisabled() end
            if widgets.button("PNG", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
                customSettings.screenshotFormat = "png"
            end
            if selected then im.EndDisabled() end
        end
        im.TableNextColumn()
        do
            local selected = customSettings.screenshotFormat == "jpg"
            if selected then im.BeginDisabled() end
            if widgets.button("JPG", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
                customSettings.screenshotFormat = "jpg"
            end
            if selected then im.EndDisabled() end
        end
        im.EndTable()
    end
    im.SameLine()
    im.SetCursorPosY(prevCursor + style.FramePadding.y)
    im.SetCursorPosX(im.GetCursorPosX() - style.FramePadding.x * 2)
    im.Text("File Format")

    widgets.tooltipButton({
        desc = "The smaller the value the closer the camera must get to see the highest level of detail. This setting can have a huge impact on performance in mesh heavy scenes. (Higher is better)"
    })
    im.SameLine()
    if im.SliderFloat("LOD Scale", customSettings.detail, 1, 100, "%.3f", im.SliderFlags_Logarithmic) then
        verifyPreset()
    end

    widgets.tooltipButton({
        desc = "A global level of detail scale used to tweak the default terrain screen error value. (Lower is better)"
    })
    im.SameLine()
    if im.SliderFloat("Terrain LOD Scale", customSettings.terrain, 0.001, 1, "%.3f", im.SliderFlags_Logarithmic) then
        verifyPreset()
    end

    widgets.tooltipButton({
        desc = "A level of detail scale used to tweak the density of grass and other foliage."
    })
    im.SameLine()
    if im.SliderInt("Ground Cover Scale", customSettings.groundcover, 1, 16) then
        verifyPreset()
    end

    im.Separator()

    widgets.tooltipButton({
        desc = "Time of day on a 0-1 scale."
    })
    im.SameLine()
    if im.SliderFloat("Time of Day", timeOfDay, 0, 1) then
        applyTimeOfDay()
    end

    widgets.tooltipButton({
        desc = "Position of the sun along the sky."
    })
    im.SameLine()
    if im.SliderFloat("Sun Direction", azimuthOverride, 0, 360) then
        applyTimeOfDay()
    end

    widgets.tooltipButton({
        desc = "FOV slider."
    })
    im.SameLine()
    if im.SliderFloat("FOV", customSettings.fov, 10, 120) then
        local player = getPlayerVehicle(0)
        if player then
            local playerId = player:getId()
            core_camera.setFOV(playerId, customSettings.fov[0])
        end
    end

    widgets.tooltipButton({
        desc = "Apply motion blur to the image.\nUse a camera relative to the car when taking screenshots of it."
    })
    im.SameLine()
    im.Checkbox("##MotionBlurCheckbox", customSettings.motionblur)
    im.SameLine()
    if not customSettings.motionblur[0] then
        im.BeginDisabled()
    end
    im.SetNextItemWidth(itemWidth-im.GetFrameHeight()-style.ItemSpacing.x)
    im.SliderFloat("Motion Blur", customSettings.motionblurAmount, 0, 10, "%.3f")
    if not customSettings.motionblur[0] then
        im.EndDisabled()
    end

    im.Separator()
    --[[widgets.tooltipButton({
        desc = "A level of detail scale used to tweak the density of grass and other foliage."
    })
    im.SameLine()
    if im.SliderFloat("Camera Tilt", tilt, -180, 180) then
        local player = getPlayerVehicle(0)
        if player then
            local playerId = player:getId()
            local rot = getOrientedRelativeRot(math.rad(tilt[0]))
            core_camera.setRotation(playerId, rot)
        end
    end]]
    widgets.tooltipButton({
        desc = "Draw a grid on screen."
    })
    im.SameLine()
    im.Checkbox("Grid", customSettings.grid)

    im.PopItemWidth()

    if GFXDevice then
        im.Separator()

        local desktopMode = GFXDevice.getVideoMode()
        local s = customSettings.superSampling[0]
        local x = desktopMode.width
        local y = desktopMode.height

        if not customSettings.downsample[0] then
            local maxSize = math.max(x, y) * math.sqrt(s)
            if x > y then
            y = y * (maxSize / x)
            x = maxSize
            else
            x = x * (maxSize / y)
            y = maxSize
            end
            x = math.floor(x)
            y = math.floor(y)
        end

        x = clamp(x, 0, 8192)
        y = clamp(y, 0, 4608)

        local rawSize = x * y * 3 -- RGB = 3 byte
        if im.BeginTable("##photo_output_result", 2, im.TableFlags_SizingStretchSame+im.TableFlags_RowBg, im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            im.TableNextColumn()
            im.Text("Output")
            im.TableNextColumn()

            widgets.resizeFont(0.9)
            im.TableNextColumn()
            im.Text("Resolution")
            im.TableNextColumn()
            im.Text(string.format("%d x %d", x, y))

            im.TableNextColumn()
            im.Text("Megapixel")
            im.TableNextColumn()
            im.Text(string.format("%0.2f", x * y / 1000000))

            im.TableNextColumn()
            im.Text("Format")
            im.TableNextColumn()
            im.Text(customSettings.screenshotFormat:upper())

            im.TableNextColumn()
            im.Text("Raw image size")
            im.TableNextColumn()
            im.Text(bytes_to_string(rawSize))

            im.TableNextColumn()
            im.Text("Estimated file size")
            im.TableNextColumn()
            im.Text(bytes_to_string(rawSize * (customSettings.screenshotFormat=="png" and 0.5 or 0.14)))
            im.EndTable()
            im.PopFont()
        end
    end

    im.Separator()
    if im.BeginTable("##photo_camera_select", 2, im.TableFlags_SizingStretchSame+im.TableFlags_RowBg, im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        im.TableNextColumn()
        if widgets.button("Relative Camera", im.ImVec2(im.GetContentRegionAvailWidth(), im.GetTextLineHeightWithSpacing()*1.25)) then
            local player = getPlayerVehicle(0)
            if player then
                --local playerId =
                --local vehRot = quat(player:getRefNodeRotation())
                --local pos = (core_camera.getPosition() - player:getPosition()):rotated(vehRot)

                --local rot = getOrientedRelativeRot()
                core_camera.setVehicleCameraByNameWithId(player:getId(), "relative", false)
                --core_camera.setOffset(playerId, pos)
                --core_camera.setRotation(playerId, rot)
            end
        end
        im.TableNextColumn()
        if widgets.button("Free Camera", im.ImVec2(im.GetContentRegionAvailWidth(), im.GetTextLineHeightWithSpacing()*1.25)) then
            commands.setCameraFree()
        end
        im.EndTable()
    end

    im.PushFont3("cairo_bold")
    widgets.resizeFont(1.2)
    im.PushStyleColor2(im.Col_Button, im.ImVec4(1,0.25,0.2,1))
    if widgets.button("Take Screenshot", im.ImVec2(im.GetContentRegionAvailWidth(), im.GetTextLineHeightWithSpacing()*1.25)) then
        screenshot()
    end
    im.PopStyleColor()
    im.PopFont()
    im.PopFont()

    if widgets.button("Open Folder", im.ImVec2(im.GetContentRegionAvailWidth(), im.GetTextLineHeightWithSpacing()*1.25)) then
        local screenshotFolderString = getScreenShotFolderString()
        Engine.Platform.exploreFolder(screenshotFolderString and string.format("/screenshots/%s/", screenshotFolderString) or "/screenshots/")
    end

    local pos1 = im.GetWindowPos()
    local pos2 = im.GetMainViewport().Pos
    local size1 = im.GetWindowSize()
    local deskRes = GFXDevice.getVideoMode()
    local data = {(pos1.x-pos2.x)/deskRes.width, (pos1.y-pos2.y)/deskRes.height, size1.x/deskRes.width, size1.y/deskRes.height, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsPhoto", {["1"] = data})

    im.End()

    if customSettings.grid[0] then
        local lines = 3
        local drawList = im.GetBackgroundDrawList1()
        local viewport = im.GetMainViewport()
        local initialPos = im.ImVec2(viewport.Pos.x, viewport.Pos.y)
        local maxPos = im.ImVec2(viewport.Pos.x + viewport.Size.x, viewport.Pos.y + viewport.Size.y)
        local sizeAdd = im.ImVec2(viewport.Size.x/lines, viewport.Size.y/lines)
        for i = 1, lines do
            im.ImDrawList_AddLine(drawList, im.ImVec2(initialPos.x + sizeAdd.x*i, initialPos.y), im.ImVec2(initialPos.x + sizeAdd.x*i, maxPos.y), im.GetColorU321(im.Col_Separator, 1), 2)
            im.ImDrawList_AddLine(drawList, im.ImVec2(initialPos.x, initialPos.y + sizeAdd.y*i), im.ImVec2(maxPos.x, initialPos.y + sizeAdd.y*i), im.GetColorU321(im.Col_Separator, 1), 2)
        end

        -- and helpers for the golden ratio
        im.ImDrawList_AddLine(drawList, im.ImVec2(initialPos.x, initialPos.y+(viewport.Size.y*0.618)), im.ImVec2(maxPos.x, initialPos.y+(viewport.Size.y*0.618)), im.GetColorU322(im.ImVec4(0.991, 0.568627451, 0, 0.333)), 2)
        im.ImDrawList_AddLine(drawList, im.ImVec2(initialPos.x+(viewport.Size.x*0.618), initialPos.y), im.ImVec2(initialPos.x+(viewport.Size.x*0.618), maxPos.y), im.GetColorU322(im.ImVec4(0.991, 0.568627451, 0, 0.333)), 2)
        im.ImDrawList_AddLine(drawList, im.ImVec2(maxPos.x-(viewport.Size.x*0.618), initialPos.y), im.ImVec2(maxPos.x-(viewport.Size.x*0.618), maxPos.y), im.GetColorU322(im.ImVec4(0.991, 0.568627451, 0, 0.333)), 2)
    end
end

local function onUpdate(dtReal)
    if M.showUI == false then return end
    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render, dtReal)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()
end

local function onCameraModeChanged()
    -- somehow getFovDeg() manages to get behind...
    -- needs slight async
    core_jobsystem.wrap(function(job)
        job.sleep(0)
        customSettings.fov[0] = core_camera.getFovDeg()
    end, 0.1)()
end

local function onZeitGraphicsSettingsChange(CURSET)
    local _defaultvars = require("zeit/rcTool/defaultVars")
    local defaultvars = _defaultvars.get()

    local detailDefault = (CURSET.generaleffects or {})["$pref::TS::detailAdjust"] or defaultvars["$pref::TS::detailAdjust"].default
    presets["1 to 1"].detail = detailDefault
    presets["Normal"].detail = detailDefault
    presets["Big"].detail    = detailDefault

    local terrainDefault = (CURSET.generaleffects or {})["$pref::Terrain::lodScale"] or defaultvars["$pref::Terrain::lodScale"].default
    presets["1 to 1"].terrain = terrainDefault
    presets["Normal"].terrain = terrainDefault
    presets["Big"].terrain    = terrainDefault

    local groundcoverDefault = getGroundCoverScale()
    presets["1 to 1"].groundcover = groundcoverDefault
    presets["Normal"].groundcover = groundcoverDefault
    presets["Big"].groundcover    = groundcoverDefault

    selectPreset(1)
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsPhoto", nil) end
end

M.onCameraModeChanged = onCameraModeChanged
M.onZeitGraphicsSettingsChange = onZeitGraphicsSettingsChange
M.onUpdate = onUpdate
M.toggleUI = toggleUI
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M