-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain", "ui_imgui"}

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")
local prepareProfiles = require("zeit/rcUI/prepareProfiles")
local widgets = require("zeit/rcUI/editWidgets")
local exportModule = require("zeit/rcTool/export")

M.showUI = false
M.tab = 0

local winstate = {100, 100, --[[100, 100]]}
local fullscreen = settingsManager.get("profilemanager_full")
local icons = require("zeit/rcUI/icon").create("/settings/zeit/rendercomponents/manager/icons.png", 6, 1)

local size = im.ImVec2(1024,512)
local dotdotdotTimer = 3

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
    widgets.blurRemove("zeitRenderSettingsProfileManager")
    M.showUI = not M.showUI
    zeit_rcMain.toggleUI(M.showUI)
    if M.showUI == true then
        dotdotdotTimer = 3

        if not initialCache then
            refreshCache()
        end
        --refreshOnline()
        scenetree.maincef:setHidden(fullscreen)
    else
        scenetree.maincef:setHidden(false)
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

    im.SetCursorPosX(im.GetWindowWidth()-style.ItemSpacing.x*8-
    im.CalcTextSize("X").x-style.FramePadding.x*2-
    im.CalcTextSize("Import from Clipboard").x-style.FramePadding.x*2-
    im.CalcTextSize("Install Profiles").x-style.FramePadding.x*2
    -im.GetTextLineHeight())
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

    local prevCursor = im.GetCursorPosY()
    im.SetCursorPosY(prevCursor+1.5)
    if icons:imageButton(im.ImVec2(im.GetTextLineHeight(), im.GetTextLineHeight()), fullscreen and 6 or 5, 1) then
        if fullscreen then
            fullscreen = false
        else
            fullscreen = true
            winstate = {im.GetWindowPos().x, im.GetWindowPos().y,
            im.GetWindowSize().x, im.GetWindowSize().y}
        end
        scenetree.maincef:setHidden(fullscreen)
        settingsManager.set("profilemanager_full", fullscreen)
    end
    if im.IsItemHovered() then
        im.SetTooltip(fullscreen and "Exit fullscreen" or "Go fullscreen")
    end
    im.SetCursorPosY(prevCursor)

    if widgets.button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)
    im.PopFont()

    im.Separator()
end

local function renderExport(name, dtReal)
    if exportWindowOpen and exportWindowOpen == name then
        im.Separator()
        im.BeginChild1("##export"..name, im.ImVec2(im.GetContentRegionAvailWidth(), size.y/6), false, im.WindowFlags_NoScrollbar)

        if im.BeginTable("##zeitRenderSettingsProfileManagerExportMenu"..name, 2, im.TableFlags_BordersV, im.ImVec2(im.GetContentRegionAvailWidth()-1, 0)) then
            im.TableNextColumn()
            im.PushFont3("cairo_semibold_large")
            im.Text("Clipboard Export")
            im.PopFont()
            im.Indent()
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
            im.Unindent()

            im.TableNextColumn()

            im.PushFont3("cairo_semibold_large")
            im.Text("Mod Export")
            im.PopFont()
            im.Indent()
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
            im.Unindent()

            im.EndTable()
        end
        im.EndChild()
    end
end

local function renderChild(name, data, dtReal)
    local childSize = im.ImVec2(im.GetContentRegionAvailWidth(), size.y/4)
    im.BeginChild1("##"..name, childSize, false, im.WindowFlags_NoScrollbar + im.WindowFlags_NoScrollWithMouse)
    local cursorPos = im.GetCursorPos()
    local windowPos = im.GetWindowPos()
    local imgSizeMul = childSize.y/data.preview.size.y

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
        icons:image(im.ImVec2(26,26), 4, 1)
        if hovering then
            im.SetTooltip("Included")
        end
    elseif data.fileSource == 1 then
        icons:image(im.ImVec2(26,26), 2, 1)
        if hovering then
            im.SetTooltip("External")
        end
    elseif data.fileSource == 2 then
        icons:image(im.ImVec2(26,26), 1, 1)
        if hovering then
            im.SetTooltip("Custom")
        end
    end
    im.Separator()

    local screenCursorPos = im.GetCursorScreenPos()
    im.SetNextWindowPos(im.ImVec2(screenCursorPos.x+data.preview.size.x*imgSizeMul*1.025, screenCursorPos.y))
    local intendedWindowHeight = childSize.y-im.GetCursorPosY()-im.GetTextLineHeightWithSpacing()-style.FramePadding.y*2-style.WindowPadding.y
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0)
    end
    im.BeginChild1("##descriptionwindow_"..name, im.ImVec2(childSize.x-data.preview.size.x*imgSizeMul*1.025, intendedWindowHeight), false, im.WindowFlags_NoScrollWithMouse)
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
    im.EndChild()

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
            toggleUI()
        end
        im.SameLine()
    else
        im.SetCursorPosX(childSize.x-23-style.ItemInnerSpacing.x*2)
    end

    colOverwritten = data.edit
    if colOverwritten then
        im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    end
    if icons:imageButton(im.ImVec2(23,23), 3, 1) then
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

    renderExport(name, dtReal)
end

local function renderLoading(dt)
    im.PushFont3("cairo_bold")
    im.SetWindowFontScale(1.5)
    im.SetCursorPosY(im.GetWindowHeight()/2-im.CalcTextSize("").y/1.7)
    widgets.textCentered(dotdotdotTimer < 1 and "Loading." or
                 dotdotdotTimer < 2 and "Loading.." or
                 dotdotdotTimer < 3 and "Loading..." or
                 "Loading")
    im.PopFont()

    im.SetWindowFontScale(0.9)
    widgets.textCentered("This can take a while.")
    im.SetWindowFontScale(1)
    dotdotdotTimer = (dotdotdotTimer + dt*6)%4
end

local function renderInstalled(dtReal)
    if #searchkeys == 0 then
        im.PushFont3("cairo_bold")
        im.SetWindowFontScale(1.5)
        im.SetCursorPosY(im.GetWindowHeight()/2-im.CalcTextSize("").y/1.7)
        widgets.textCentered("No results")
        im.PopFont()

        im.SetWindowFontScale(0.9)
        widgets.textCentered("If you're looking for something, try a different query.")
        im.SetWindowFontScale(1)
    else
        for k,v in ipairs(searchkeys) do
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

                if k < #searchkeys then
                    im.Separator()
                end
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

    local mainPort = im.GetMainViewport()
    size = im.ImVec2(
        mainPort.Size.x/2,
        mainPort.Size.y/2)
    if fullscreen then
        im.SetNextWindowPos(mainPort.Pos, im.ImGuiCond_Always)
        im.SetNextWindowSize(mainPort.Size, im.ImGuiCond_Always)
    else
        if winstate[1] then
            im.SetNextWindowPos(im.ImVec2(
                winstate[1],
                winstate[2]))
            im.SetNextWindowSize(im.ImVec2(
                winstate[3] or size.x,
                winstate[4] or size.y))
            winstate = {}
        end
        im.SetNextWindowSizeConstraints(im.ImVec2(830, 300), im.ImVec2(size.x, size.y))
    end

    im.Begin("Zeit's Graphics Utils: Profile Manager", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + (fullscreen and (im.WindowFlags_NoBringToFrontOnFocus + im.WindowFlags_NoFocusOnAppearing) or 0))

    widgets.blurUpdate("zeitRenderSettingsProfileManager")
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

    widgets.guardViewportOverflow()
    im.End()
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

local function onZeitGraphicsLoaded()
    if zeit_rcUI_select then
        zeit_rcUI_select.addEntry("profileManager", {
            id = "zeit_rcUI_profileManager",
            name = "Profile Manager",
            texObj = imguiUtils.texObj("/settings/zeit/rendercomponents/switcher/manager.png")
        })
    end
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
M.refreshCache = refreshCache
M.onZeitGraphicsProfileChange = refreshCache
M.onZeitGraphicsLoaded = onZeitGraphicsLoaded

return M