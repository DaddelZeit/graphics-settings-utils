-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local prepareProfiles = rerequire("zeit/rcUI/prepareProfiles")
local widgets = require("zeit/rcUI/editWidgets")
local exportModule = require("zeit/rcTool/export")

M.showUI = false
M.tab = 0

local iconsTex = imguiUtils.texObj("/settings/zeit/rendercomponents/manager/icons.png")
local size = im.ImVec2(1024,512)
local dotdotdotTimer = 3

local currentScroll = 0
local noScrollInputTicks = 0
local preventScrollUp = false
local preventScrollDown = false
local totalScroll = 0
local scrollSmoother = newTemporalSigmoidSmoothing(10, 20, 20, 10, 0)

local profiles = {}
local keys = {}
local searchkeys = {}
local searchQuery = im.ArrayChar(2048)
local currentTag

local profileImported
local setBgAlpha = false

local initialCache = false
local refreshInProgress = false

local exportWindowOpen

local exported = false
local exportTime = 0
local exportedZip = false
local exportZipTime = 0

--[[
local onlineRefreshInProgress = false
local onlineProfiles = {}
local tempPath = "/temp/zeit/rendercomponents/"
]]

local function resetScroll()
    currentScroll = 0
    totalScroll = 0
    noScrollInputTicks = 0
    scrollSmoother:set(0)
    preventScrollUp = false
    preventScrollDown = false
end

local function refreshCache()
    if refreshInProgress then return end
    refreshInProgress = true
    dotdotdotTimer = 3
    profiles = {}
    keys = {}

    prepareProfiles.prep(zeit_rcMain.getAllProfiles(),
    function(_profiles, _keys)
        profiles = _profiles

        keys = _keys
        searchkeys = keys
        exportWindowOpen = nil
        initialCache = true

        resetScroll()
        refreshInProgress = false
    end, true)
end

--[[
local function refreshOnline()
    if settings.getValue('onlineFeatures') ~= 'enable' then return end
    onlineRefreshInProgress = true
    onlineProfiles = {}
    core_online.apiCall('s1/v4/getMods' , function(request)
        local modList = request.responseData and request.responseData.data
        if modList then
            local imgAmount = 0
            local needImgAmount = #modList
            for k,m in ipairs(modList) do
                dump(m)
                core_online.download("s1/v4/download/mods/"..m.path.."icon.jpg", function(data)
                    if data.responseCode == 200 then
                        writeFile(tempPath..m.path.."icon.jpg", data.responseBuffer)

                        local tex = imguiUtils.texObj(tempPath..m.path.."icon.jpg")
                        tex.url = "https://api.beamng.com/s1/v4/download/mods/"..m.path.."icon.jpg"

                        table.insert(onlineProfiles, {
                            thumbnail = tex,
                            title = m.title,
                            tagline = m.tag_line,
                            author = m.username
                        })
                        imgAmount = imgAmount + 1
                    end
                end)
            end

            core_jobsystem.wrap(function(job)
                while onlineRefreshInProgress do
                    if imgAmount == needImgAmount then
                        onlineRefreshInProgress = false
                    end
                    job.sleep(0.05)
                end
            end, 0.1)()
        end
    end, {
        query = ffi.string(searchQuery),
        order_by = "update",
        order = "desc",
        page = 1-1,
        categories = {7},
    })
end
]]

local function search(tag)
    if tag then
        searchkeys = prepareProfiles.searchTags(keys, tag)
        currentTag = tag
    else
        searchkeys = prepareProfiles.searchIn(keys, searchQuery)
        --refreshOnline()
        currentTag = nil
    end
end

local function toggleUI()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", nil) end
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)
    if M.showUI == true then
        dotdotdotTimer = 3

        local mainPort = im.GetMainViewport()
        local pos = im.ImVec2(
            mainPort.Pos.x + (mainPort.Size.x/2),
            mainPort.Pos.y + (mainPort.Size.y/2))
        size = im.ImVec2(
            mainPort.Size.x/2,
            mainPort.Size.y/2)

        im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))

        if not initialCache then
            refreshCache()
        end
        --refreshOnline()
    end
end

local function renderTopBar()
    im.SetCursorPosY(-style.ItemSpacing.y+im.GetScrollY())
    im.PushFont3("cairo_bold")
    if widgets.button("Open Settings") then
        zeit_rcUI_settings.toggleUI()
    end
    if widgets.button("Refresh") then
        refreshCache()
        --refreshOnline()
    end

    --[[
    if M.tab == 0 then
       if widgets.button("Go online") then
           M.tab = 1
           refreshOnline()
       end
    else
       if widgets.button("Go offline") then
           M.tab = 0
           refreshCache()
       end
    end
    ]]

    if currentTag then
        if widgets.button("Searching by tag: "..currentTag) then
            search()
        end
        if im.IsItemHovered() then
            im.SetTooltip("Click to clear")
        end
    else
        local cursorPos = im.GetCursorPos()
        im.SetNextItemWidth(im.GetWindowSize().x/6)
        if im.InputText("##search", searchQuery) then
            search()
        end
        if not im.IsItemActive() and searchQuery[0] == 0 then
            im.SetCursorPosX(cursorPos.x+5)
            im.SetCursorPosY(cursorPos.y)
            im.BeginDisabled()
            im.Text("Search...")
            im.EndDisabled()
        end
    end

    widgets.textCentered("Zeit's Graphics Utils: Profile Manager")

    im.SetCursorPosX(im.GetWindowSize().x-style.ScrollbarSize-im.CalcTextSize("X").x-im.CalcTextSize("Import from Clipboard").x-im.CalcTextSize("Install Profiles").x-style.ItemSpacing.x*5-style.ItemInnerSpacing.x*5)
    if widgets.button("Import from Clipboard") then
        profileImported = exportModule.importProfileFromClipboard()
        if profileImported then
            refreshCache()
        end
    end
    if im.IsItemHovered() then
        if profileImported == false then
            im.SetTooltip("Import failed. Make sure you copied the source correctly.")
        elseif profileImported == true then
            im.SetTooltip("Import succesful.")
        else
            im.SetTooltip("Click to import a profile you copied into your clipboard.")
        end
    else
        profileImported = nil
    end

    if widgets.button("Install Profiles") then
        Engine.Platform.exploreFolder("/mods/")
    end
    if im.IsItemHovered() then
        im.SetTooltip("Click to open your mods folder.\nInstall new profiles here.")
    end

    if widgets.button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)
    im.PopFont()

    im.Separator()
end

local function renderExport(name, dtReal)
    if exportWindowOpen and exportWindowOpen == name then
        im.BeginChild1("##export"..name, im.ImVec2(im.GetContentRegionAvailWidth(), size.y/6.5), false, im.WindowFlags_NoScrollbar)

        if im.BeginTable("##zeitRenderSettingsProfileManagerExportMenu"..name, 2, im.TableFlags_BordersV) then
            im.TableNextColumn()
            im.PushFont3("cairo_semibold_large")
            im.Text("Clipboard Export")
            im.PopFont()
            exportModule.formatSelector()
            if widgets.button("Export to Clipboard") then
                exported = exportModule.exportProfileToClipboard(name)
                exportTime = 2
            end
            im.SameLine()
            exportModule.infoCheckbox()
            if exportTime > 0 then
                if exported then
                    exportTime = math.max(exportTime - dtReal*2, 0)
                    im.TextColored(im.ImVec4(1,1,1,exportTime), "Successfully exported.")
                else
                    im.TextColored(im.ImVec4(1,0.6,0.6,exportTime), "Export failed. See console for details.")
                end
            else
                im.Text("")
            end

            im.TableNextColumn()

            im.PushFont3("cairo_semibold_large")
            im.Text("Mod Export")
            im.PopFont()
            if widgets.button("Export as Mod") then
                local path
                exportedZip, path = exportModule.exportProfileAsMod(name)
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
            else
                im.Text("")
            end

            im.EndTable()
        end
        im.EndChild()
    end
end

local function renderChild(name, data, dtReal)
    local childSize = im.ImVec2(im.GetContentRegionAvailWidth(), size.y/4)
    im.BeginChild1("##"..name, childSize, false, im.WindowFlags_NoScrollbar)
    local cursorPos = im.GetCursorPos()
    local windowPos = im.GetWindowPos()
    local imgSizeMul = (size.y/4)/data.preview.size.y

    im.PushFont3("cairo_semibold_large")
    im.SetCursorPosX(cursorPos.x+data.preview.size.x*imgSizeMul*1.025)
    local textSize = im.CalcTextSize(ffi.string(data.info.name))
    if data.edit then
        im.SetNextItemWidth(im.GetWindowSize().x-im.GetCursorPos().x)
        im.InputText("##name_"..name, data.info.name)
    else
        im.Text(ffi.string(data.info.name))
    end
    im.PopFont()
    im.SameLine()

    local newCursorPos = im.ImVec2(childSize.x-26-style.ItemSpacing.x, textSize.y/2-13)
    local hovering = im.IsMouseHoveringRect(im.ImVec2(newCursorPos.x+windowPos.x, newCursorPos.y+windowPos.y), im.ImVec2(newCursorPos.x+windowPos.x+26, newCursorPos.y+windowPos.y+26))
    im.SetCursorPos(newCursorPos)
    if data.fileSource == 0 then
        im.Image(iconsTex.texId, im.ImVec2(26,26), im.ImVec2(0.75,0), im.ImVec2(1,1))
        if hovering then
            im.SetTooltip("Included")
        end
    elseif data.fileSource == 1 then
        im.Image(iconsTex.texId, im.ImVec2(26,26), im.ImVec2(0.25,0), im.ImVec2(0.5,1))
        if hovering then
            im.SetTooltip("External")
        end
    elseif data.fileSource == 2 then
        im.Image(iconsTex.texId, im.ImVec2(26,26), im.ImVec2(0,0), im.ImVec2(0.25,1))
        if hovering then
            im.SetTooltip("Custom")
        end
    end
    im.Separator()

    local screenCursorPos = im.GetCursorScreenPos()
    im.SetNextWindowPos(im.ImVec2(screenCursorPos.x+data.preview.size.x*imgSizeMul*1.025, screenCursorPos.y))
    local intendedWindowHeight = (size.y/4)-im.GetCursorPosY()-25
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0)
    end
    im.BeginChild1("##descriptionwindow_"..name, im.ImVec2(childSize.x-data.preview.size.x*imgSizeMul*1.05, intendedWindowHeight), false, im.WindowFlags_NoScrollbar)
    im.Text("Description:")
    im.SameLine()
    if data.edit then
        im.SetNextItemWidth(im.GetWindowSize().x-im.CalcTextSize("Description:").x)
        local gsubResult = {ffi.string(data.info.desc):gsub("\n", "")}
        im.InputTextMultiline("##description_"..name, data.info.desc, im.GetLengthArrayCharPtr(data.info.desc), im.ImVec2(0, im.GetTextLineHeight() * (gsubResult[2]+1)+5), im.flags(im.InputTextFlags_AllowTabInput))
    else
        im.TextWrapped(data.info.desc)
    end
    im.Text("Author:")
    im.SameLine()
    if data.edit then
        im.SetNextItemWidth(im.GetWindowSize().x-im.CalcTextSize("Author:").x)
        im.InputText("##author_"..name, data.info.author)
    else
        im.TextWrapped(data.info.author)
    end
    im.Text("Date:")
    im.SameLine()
    if data.edit then
        im.SetNextItemWidth(im.GetWindowSize().x-im.CalcTextSize("Date:").x-im.CalcTextSize("Set      to      now").x)
        im.InputText("##date_"..name, data.info.date)
        im.SameLine()
        if widgets.button("Set to now") then
            ffi.copy(data.info.date, os.date())
        end
    else
        im.TextWrapped(data.info.date)
    end

    if data.edit then
        for k,v in ipairs(data.info.tags) do
            if data.editingTag and k == #data.info.tags then break end
            if widgets.button(v) then
                table.remove(data.info.tags, k)
            end
            im.SameLine()
        end
        if data.editingTag then
            im.SetNextItemWidth(im.GetWindowSize().x/8)
            im.InputText("##tag_new"..name, data.info.tags[#data.info.tags])
            im.SameLine()
        end
        if widgets.button("+") then
            if not data.editingTag then
                data.editingTag = true
                data.info.tags[#data.info.tags+1] = im.ArrayChar(128)
            else
                data.editingTag = false
            end
        end
    else
        for k,v in ipairs(data.info.tags) do
            if widgets.button(v) then
                local tag = ffi.string(v)
                if currentTag == tag then
                    search()
                else
                    search(tag)
                end
            end
            im.SameLine()
        end
    end
    im.Dummy(im.ImVec2(0,0))
    im.Dummy(im.ImVec2(0,0))

    if im.IsWindowHovered() and im.GetCursorPosY() > intendedWindowHeight then
        local scroll = im.GetScrollY()
        if scroll == 0 then
            preventScrollDown = true
        elseif scroll == im.GetScrollMaxY() then
            preventScrollUp = true
        else
            preventScrollUp = true
            preventScrollDown = true
        end
    end
    im.EndChild()

    im.SetCursorPosY((size.y/4)-26)
    im.Separator()
    im.SetCursorPosX(cursorPos.x+data.preview.size.x*imgSizeMul*1.025)

    local colOverwritten = zeit_rcMain.currentProfile == name
    if colOverwritten then
        im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    end
    if widgets.button("Apply") then
        zeit_rcMain.loadProfile(name)
    end
    if colOverwritten then
        im.PopStyleColor()
    end
    im.SameLine()

    if widgets.button("Duplicate") then
        zeit_rcMain.duplicateProfile(name)
    end
    im.SameLine()

    colOverwritten = exportWindowOpen and exportWindowOpen == name
    if colOverwritten then
        im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    end
    if widgets.button("Export") then
        if exportWindowOpen and exportWindowOpen == name then
            exportWindowOpen = nil
        else
            exportWindowOpen = name
        end
    end
    if colOverwritten then
        im.PopStyleColor()
    end
    im.SameLine()

    if data.fileSource == 2 then
        if data.overwrite then
            if widgets.button("Reset") then
                zeit_rcMain.deleteProfileDialog(name)
            end
        else
            if widgets.button("Delete") then
                zeit_rcMain.deleteProfileDialog(name)
            end
        end
    end
    im.SameLine()

    if data.fileSource == 2 then
        im.SetCursorPosX(childSize.x-23-im.CalcTextSize("View in Explorer").x-style.ItemSpacing.x*3-style.ItemInnerSpacing.x*2)
        if widgets.button("View in Explorer") then
            Engine.Platform.exploreFolder(zeit_rcMain.profilePath..name..".profile.json")
        end
        im.SameLine()
    elseif data.fileSource == 1 then
        im.SetCursorPosX(childSize.x-23-im.CalcTextSize("View Mod").x-style.ItemSpacing.x*3-style.ItemInnerSpacing.x*2)
        if widgets.button("View Mod") and data.modPath then
            guihooks.trigger("ChangeState", {state = "menu.modsDetails", params = {modFilePath = data.modPath}})
        end
        im.SameLine()
    else
        im.SetCursorPosX(childSize.x-23-style.ItemInnerSpacing.x*2)
    end

    colOverwritten = data.edit
    if colOverwritten then
        im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    end
    if im.ImageButton2(iconsTex.texId, im.ImVec2(23,23), im.ImVec2(0.5,0), im.ImVec2(0.75,1), 0, nil, nil) then
        data.edit = not data.edit
        if data.edit == false then
            local tags = {}
            for k,v in ipairs(data.info.tags) do
                tags[k] = ffi.string(v)
            end
            zeit_rcMain.saveInfo({
                name = ffi.string(data.info.name),
                desc = ffi.string(data.info.desc),
                author = ffi.string(data.info.author),
                date = ffi.string(data.info.date),
                tags = tags
            }, name)
        end
    end
    if colOverwritten then
        im.PopStyleColor()
    end

    -- must draw last
    im.SetCursorPos(cursorPos)
    im.Image(data.preview.texId, im.ImVec2(data.preview.size.x*imgSizeMul, data.preview.size.y*imgSizeMul))
    if im.IsItemHovered() then
        if getCurrentLevelIdentifier() ~= "utah" then
            im.SetTooltip("Generate Image\nLoad Utah, USA before use.")
        else
            im.SetTooltip("Click to generate image.\nWARNING: This will not return your game to the previous state.")
            if im.IsMouseClicked(0) then
                toggleUI()
                zeit_rcMain.loadProfile(name)

                extensions.load("zeit_rcTool_takePreview")
                if zeit_rcTool_takePreview then
                    zeit_rcTool_takePreview.start(zeit_rcMain.profilePath..name..".preview")
                end
            end
        end
    end

    im.EndChild()
    im.Separator()

    renderExport(name, dtReal)
end

local function renderLoading(dt)
    im.PushFont3("cairo_bold")
    widgets.resizeFont(1.5)
    im.SetCursorPosY(im.GetWindowHeight()/2-im.CalcTextSize("").y/1.7)
    widgets.textCentered(dotdotdotTimer < 1 and "Loading." or
                 dotdotdotTimer < 2 and "Loading.." or
                 dotdotdotTimer < 3 and "Loading..." or
                 "Loading")
    im.PopFont()
    im.PopFont()

    widgets.resizeFont(0.9)
    widgets.textCentered("This can take a while.")
    im.PopFont()
    dotdotdotTimer = (dotdotdotTimer + dt*6)%4
end

local function renderInstalled(dtReal)
    if #searchkeys == 0 then
        im.PushFont3("cairo_bold")
        widgets.resizeFont(1.5)
        im.SetCursorPosY(im.GetWindowHeight()/2-im.CalcTextSize("").y/1.7)
        widgets.textCentered("No results")
        im.PopFont()
        im.PopFont()

        widgets.resizeFont(0.9)
        widgets.textCentered("If you're looking for something, try a different query.")
        im.PopFont()
    else
        for _,v in ipairs(searchkeys) do
            if profiles[v] then
                if setBgAlpha then
                    im.SetNextWindowBgAlpha(0.6)
                end

                local isInFrame = im.GetCursorPosY() < (im.GetWindowHeight()+im.GetScrollY())
                profiles[v].timeOffset = math.max(profiles[v].timeOffset-dtReal,0)

                local animProgress = (profiles[v].timeOffset == 0 and isInFrame) and profiles[v].smoothIn:get(1, dtReal) or 0
                im.PushStyleVar1(im.StyleVar_Alpha, animProgress*animProgress)
                im.SetCursorPosX(im.GetWindowWidth()*(1-animProgress))
                renderChild(v, profiles[v], dtReal)
                im.PopStyleVar()
            end
        end
    end
end

--[[
local function renderOnline()
    for k,oprofile in ipairs(onlineProfiles) do
        im.BeginChild1("##"..oprofile.title, im.ImVec2(im.GetContentRegionAvailWidth(), oprofile.thumbnail.size.y), false, im.WindowFlags_NoScrollbar + im.WindowFlags_NoScrollWithMouse)
        im.Image(oprofile.thumbnail.texId, oprofile.thumbnail.size)

        im.SameLine()
        im.Indent(im.GetCursorPosX())
        im.PushFont3("cairo_semibold_large")
        im.Text(oprofile.title)
        im.PopFont()

        im.SameLine()
        im.SetCursorPosX(im.GetWindowWidth()-im.CalcTextSize(oprofile.author).x-style.ItemSpacing.x)
        im.Text(oprofile.author)

        im.PushFont3("cairo_semibold_large")
        im.SetCursorPosY(im.CalcTextSize("").y)
        im.PopFont()
        im.PushFont3("cairo_bold")
        im.Text(oprofile.tagline)
        im.PopFont()

        im.Unindent()

        im.NewLine()
        im.EndChild()
    end
end
]]

local function render(dt)
    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.6)
    end

    im.SetNextWindowSize(size)
    im.Begin("Zeit's Graphics Utils: Profile Manager", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse)

    local pos1 = im.GetWindowPos()
    local pos2 = im.GetMainViewport().Pos
    local size1 = im.GetWindowSize()
    local deskRes = GFXDevice.getVideoMode()
    local data = {(pos1.x-pos2.x)/deskRes.width, (pos1.y-pos2.y)/deskRes.height, size1.x/deskRes.width, size1.y/deskRes.height, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", {["1"] = data})

    im.BeginMenuBar()
    renderTopBar()
    im.EndMenuBar()

    --[[
    if M.tab == 0 then
        if refreshInProgress then
            renderLoading(dt)
        else
            renderInstalled(dt)
        end
    else
        if onlineRefreshInProgress then
            renderLoading(dt)
        else
            renderOnline(dt)
        end
    end
    ]]
    if refreshInProgress then
        renderLoading(dt)
    else
        renderInstalled(dt)
    end

    im.PopStyleColor()
    im.PopStyleColor()

    if im.IsWindowHovered(im.HoveredFlags_RootAndChildWindows) then
        local input = im.GetIO().MouseWheel
        if input ~= 0 then
            if (input > 0 and not preventScrollUp) or (input < 0 and not preventScrollDown) then
                totalScroll = math.max(math.min(totalScroll - im.GetIO().MouseWheel/6, 1), 0)
            end

            if noScrollInputTicks == 0 then
                preventScrollUp = false
                preventScrollDown = false
                noScrollInputTicks = 1
            else
                noScrollInputTicks = noScrollInputTicks - 1
            end
        end
    end

    local lastScroll = currentScroll
    currentScroll = scrollSmoother:get(totalScroll, dt)*im.GetScrollMaxY()
    im.SetScrollY(currentScroll)
    if math.floor(lastScroll) ~= im.GetScrollY() then
        totalScroll = im.GetScrollY()/im.GetScrollMaxY()
    end
    im.End()
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

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", nil) end
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.toggleUI = toggleUI
M.refreshCache = refreshCache
M.onZeitGraphicsProfileChange = refreshCache

return M