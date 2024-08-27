-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local style = require("zeit/rcTool/style")

M.showUI = false

M.tab = 0
local iconsTex
local size = im.ImVec2(1024,512)
local dotdotdotTimer = 3

local noScrollInputTicks = 0
local preventScrollUp = false
local preventScrollDown = false
local totalScroll = 0
local scrollSmoother = newTemporalSigmoidSmoothing(10, 20, 20, 10, 0)
local profiles = {}

local search = im.ArrayChar(2048)
local keys = {}
local searchkeys = {}
local currentTag

local profileImported
local setBgAlpha = false

local onlineRefreshInProgress = false
local refreshInProgress = false
local onlineProfiles = {}
local tempPath = "/temp/zeit/rcProfileManager/"

local function getSortedAlphabeticalByDisplayName(tbl)
    local a,b,c = {},{},{}
    for k,v in ipairs(tbl) do
        a[k]=ffi.string(profiles[v].info.name)
    end
    b = shallowcopy(a)
    table.sort(a)
    for _,v in ipairs(a) do
        for k2,v2 in ipairs(b) do
            if v == v2 then
                table.insert(c, tbl[k2])
            end
        end
    end
    return c
end

local function refreshCache()
    if refreshInProgress then return end
    refreshInProgress = true
    iconsTex = imguiUtils.texObj("/settings/zeit/rendercomponents/icons.png")
    profiles = {}
    keys = {}

    core_jobsystem.wrap(function(job)
        local n = 0
        for _,v in ipairs(zeit_rcMain.getAllProfiles()) do
            local path = v:gsub(zeit_rcMain.profilePath, "")
            local internalName = split(path, ".")[1]
            local jsonInfo = jsonReadFile(zeit_rcMain.profilePath..internalName..".info.json") or {}
            local info = {
                author = im.ArrayChar(256),
                date = im.ArrayChar(256),
                desc = im.ArrayChar(1024*16),
                name = im.ArrayChar(256),
                tags = {}
            }
            for k,v2 in ipairs(jsonInfo.tags or {}) do
                info.tags[k] = im.ArrayChar(128)
                ffi.copy(info.tags[k], v2)
            end
            ffi.copy(info.author, jsonInfo.author or "Unknown")
            ffi.copy(info.date, jsonInfo.date or "Unavailable")
            ffi.copy(info.desc, jsonInfo.desc or "No description available")
            ffi.copy(info.name, jsonInfo.name or internalName)

            local preview = zeit_rcMain.profilePath..internalName..".preview."
            preview = FS:fileExists(preview.."png") and preview.."png" or FS:fileExists(preview.."jpg") and preview.."jpg" or "/settings/zeit/rendercomponents/default.png"
            if preview then
                preview = imguiUtils.texObj(preview)
            end

            local fileSource = FS:findOverrides(zeit_rcMain.profilePath..path)[1]
            if fileSource:match("renderer_components_loadsave_zeit") then fileSource = 0 -- included
            elseif fileSource:match("mods") then fileSource = 1 -- mod
            elseif fileSource == FS:getUserPath() then fileSource = 2 -- userfolder
            else fileSource = 3 end -- how

            profiles[internalName] = {
                path = path,
                info = info,
                preview = preview,
                fileSource = fileSource,
                smoothIn = newTemporalSigmoidSmoothing(20, 30, 30, 20, 0),
                timeOffset = n*0.075,
            }

            table.insert(keys, internalName)
            n = n + 1
            job.sleep(0.02)
        end

        -- sort key array
        keys = getSortedAlphabeticalByDisplayName(keys)
        searchkeys = keys
        refreshInProgress = false
    end, 0.1)()
end

--[[
local function refreshOnline()
    if settings.getValue('onlineFeatures') ~= 'enable' then return end
    onlineRefreshInProgress = true
    core_online.apiCall("s1/v4/getMod/MDF8E2YQ1", function(request)
        if request.responseData == nil then return end
        onlineProfiles = {
            {
                texHandlers = {},
                data = request.responseData.data.message
            }
        }

        local uriBase = string.format("s1/v4/download/mods/MDF8E2YQ1/%d/", request.responseData.data.current_version_id)
        local attachments = jsonDecode(request.responseData.data.attachments) or {}

        local imgAmount = 0
        local needImgAmount = #attachments
        for _,v in ipairs(attachments) do
            core_online.download(uriBase..v.thumb_filename, function(data)
                if data.responseCode == 200 then
                    writeFile(tempPath..v.thumb_filename, data.responseBuffer)

                    local tex = imguiUtils.texObj(tempPath..v.thumb_filename)
                    tex.id = v.data_filename:match("%d+")
                    tex.url = "https://www.beamng.com/attachments/"..tex.id

                    onlineProfiles[1].texHandlers[v.data_filename:match("%d+")] = tex
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
    end)
end
]]

local function toggleUI()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", nil) end
    M.showUI = not M.showUI
    if M.showUI == true then
        dotdotdotTimer = 3
        totalScroll = 0
        scrollSmoother:set(0)
        local mainPort = im.GetMainViewport()
        local pos = im.ImVec2(
            mainPort.Pos.x + (mainPort.Size.x/2),
            mainPort.Pos.y + (mainPort.Size.y/2))
        size = im.ImVec2(
            mainPort.Size.x/2,
            mainPort.Size.y/2)

        im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))

        refreshCache()
        --refreshOnline()

        M.onUpdate(0)
    end
end

local function textCentered(text)
    local windowWidth = im.GetWindowSize().x
    local textWidth   = im.CalcTextSize(text).x

    im.SetCursorPosX((windowWidth - textWidth)/2)
    im.Text(text)
end

local function searchIn(profileKeys, queries)
    queries = ffi.string(queries)
    if queries == "" then return profileKeys end
    queries = split(queries, ' ')

    local a = {}
    for _,v in ipairs(profileKeys) do
        local profile = profiles[v]
        for k,query in ipairs(queries) do
            if query == "" then goto next end
            if ffi.string(profile.info.name):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) or ffi.string(profile.info.desc):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) or ffi.string(profile.info.author):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) then
                table.insert(a, v)
                goto next
            end

            for _,v2 in ipairs(profile.info.tags) do
                if ffi.string(v2):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) then
                    table.insert(a, v)
                    goto next
                end
            end
        end

        ::next::
    end
    return a
end

local function renderTopBar()
    im.SetCursorPosY(-style.ItemSpacing.y+im.GetScrollY())
    im.PushFont3("cairo_bold")
    im.Button("Open Mod Page")
    if im.IsItemHovered() then
        if im.IsMouseClicked(1) then
            openWebBrowser("https://beamng.com/threads/85768/")
        elseif im.IsMouseClicked(0) then
            be:queueJS([[open("https://beamng.com/threads/85768/")]])
        end
    end
    if im.Button("Refresh") then
        refreshCache()
        --refreshOnline()
    end

    --[[
    if M.tab == 0 then
        if im.Button("Go online") then
            M.tab = 1
            refreshOnline()
        end
    else
        if im.Button("Go offline") then
            M.tab = 0
            refreshCache()
        end
    end
    ]]

    if currentTag then
        if im.Button("Searching by tag: "..ffi.string(currentTag)) then
            currentTag = nil
        end
        if im.IsItemHovered() then
            im.SetTooltip("Click to clear")
        end
    else
        local cursorPos = im.GetCursorPos()
        im.SetNextItemWidth(im.GetWindowSize().x/6)
        if im.InputText("##search", search) then
            searchkeys = searchIn(keys, search)
        end
        if not im.IsItemActive() and search[0] == 0 then
            im.SetCursorPosX(cursorPos.x+5)
            im.SetCursorPosY(cursorPos.y)
            im.BeginDisabled()
            im.Text("Search...")
            im.EndDisabled()
        end
    end

    textCentered("Zeit's Graphics Utils: Profile Manager")

    im.SetCursorPosX(im.GetWindowSize().x-style.ScrollbarSize-im.CalcTextSize("X").x-im.CalcTextSize("Import from Clipboard").x-im.CalcTextSize("Install Profiles").x-style.ItemSpacing.x*5-style.ItemInnerSpacing.x*5)
    if im.Button("Import from Clipboard") then
        profileImported = require("zeit/rcTool/export").importProfileFromClipboard()
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
            im.SetTooltip("Click to install a profile you copied into your clipboard.\nYou can export profiles within the edit window.")
        end
    else
        profileImported = nil
    end

    if im.Button("Install Profiles") then
        Engine.Platform.exploreFolder("/mods/")
    end
    if im.IsItemHovered() then
        im.SetTooltip("Click to open your mods folder.\nInstall new profiles here.")
    end

    if im.Button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)
    im.PopFont()

    im.Separator()
end

local function renderChild(name, data)
    im.BeginChild1("##"..name, im.ImVec2(im.GetWindowWidth()-style.ScrollbarSize-style.ItemSpacing.x, size.y/4), false, im.WindowFlags_NoScrollbar)
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

    local newCursorPos = im.ImVec2(size.x-50, textSize.y/2-13)
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
    im.BeginChild1("##descriptionwindow_"..name, im.ImVec2(size.x-data.preview.size.x*imgSizeMul*1.05, intendedWindowHeight), false, im.WindowFlags_NoScrollbar)
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
        if im.Button("Set to now") then
            ffi.copy(data.info.date, os.date())
        end
    else
        im.TextWrapped(data.info.date)
    end

    if data.edit then
        for k,v in ipairs(data.info.tags) do
            if data.editingTag and k == #data.info.tags then break end
            if im.Button(v) then
                table.remove(data.info.tags, k)
            end
            im.SameLine()
        end
        if data.editingTag then
            im.SetNextItemWidth(im.GetWindowSize().x/8)
            im.InputText("##tag_new"..name, data.info.tags[#data.info.tags])
            im.SameLine()
        end
        if im.Button("+") then
            if not data.editingTag then
                data.editingTag = true
                data.info.tags[#data.info.tags+1] = im.ArrayChar(128)
            else
                data.editingTag = false
            end
        end
    else
        for k,v in ipairs(data.info.tags) do
            if im.Button(v) then
                if currentTag == v then
                    currentTag = nil
                else
                    currentTag = v
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
    if im.Button("Apply") then
        zeit_rcMain.currentProfile = name
        zeit_rcMain.loadSettings(true)
    end
    if colOverwritten then
        im.PopStyleColor()
    end
    im.SameLine()

    if im.Button("Delete") then
        zeit_rcMain.deleteProfile(name)
    end
    im.SameLine()

    if im.Button("View in Explorer") then
        Engine.Platform.exploreFolder(zeit_rcMain.profilePath..name..".profile.json")
    end
    im.SameLine()

    im.SetCursorPosX(size.x-48)
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
            im.SetTooltip("Load Utah, USA before use.")
        else
            im.SetTooltip("Click to generate image.\nWARNING: This will not return your game to the previous state.")
            if im.IsMouseClicked(0) then
                toggleUI()
                zeit_rcMain.currentProfile = name
                zeit_rcMain.loadSettings(true)
                extensions.load("zeit_rcTool_takePreview")
                zeit_rcTool_takePreview.start(zeit_rcMain.profilePath..name..".preview")
            end
        end
    end

    im.EndChild()
    im.Separator()
end

local function renderLoading(dt)
    im.PushFont3("cairo_semibold_large")
    textCentered(dotdotdotTimer < 1 and "Loading." or
                 dotdotdotTimer < 2 and "Loading.." or
                 dotdotdotTimer < 3 and "Loading..." or
                 "Loading"
                )
    im.PopFont()
    textCentered("This could take a while.")
    dotdotdotTimer = (dotdotdotTimer + dt*3)%4
    im.Text("")
end

local function checkIfHasTag(ffitags, tag)
    local tags = {}
    for k,v in ipairs(ffitags) do
        tags[k] = ffi.string(v)
    end
    return tableContains(tags, ffi.string(tag))
end

local function renderInstalled(dt)
    for _,v in ipairs(searchkeys) do
        if profiles[v] then
            if setBgAlpha then
                im.SetNextWindowBgAlpha(0.6)
            end
            if not currentTag or checkIfHasTag(profiles[v].info.tags, currentTag) then
                if im.GetCursorPosY() < (im.GetWindowHeight()+im.GetScrollY()) then
                    profiles[v].timeOffset = math.max(profiles[v].timeOffset-dt,0)
                end

                local animProgress = profiles[v].timeOffset == 0 and profiles[v].smoothIn:get(1, dt) or 0
                im.PushStyleVar1(im.StyleVar_Alpha, animProgress)
                im.SetCursorPosX(im.GetWindowWidth()*(1-animProgress))
                renderChild(v, profiles[v])
                im.PopStyleVar()
            end
        end
    end
end

--[[
local function renderOnline()
    for k,v in pairs(onlineProfiles[1].texHandlers) do
        im.Image(v.texId, v.size)
        if im.IsItemHovered() then
            im.SetTooltip("Open: "..v.url)
            if im.IsMouseClicked(1) then
                openWebBrowser(v.url)
            elseif im.IsMouseClicked(0) then
                be:queueJS("open('"..v.url.."')")
            end
        end
    end
    im.Text(onlineProfiles[1].data)
end
]]

local function onUpdate(dt)
    if M.showUI == false then return end
    style.push()

    setBgAlpha = getCurrentLevelIdentifier() ~= nil
    if setBgAlpha then
        im.SetNextWindowBgAlpha(0.6)
    end

    im.SetNextWindowSize(size)
    im.Begin("zeitRenderSettingsProfileManager", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + im.WindowFlags_NoScrollWithMouse)

    local pos1 = im.GetWindowPos()
    local deskRes = getDesktopResolution()
    local data = {pos1.x/deskRes.x, pos1.y/deskRes.y, size.x/deskRes.x, size.y/deskRes.y, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", {["1"] = data})

    im.BeginMenuBar()
    renderTopBar()
    im.EndMenuBar()

    --if M.tab == 0 then
        if refreshInProgress then
            renderLoading(dt)
        else
            renderInstalled(dt)
        end
    --else
    --    if onlineRefreshInProgress then
    --        renderLoading(dt)
    --    else
    --        renderOnline(dt)
    --    end
    --end
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
        im.SetScrollY(scrollSmoother:get(totalScroll, dt)*im.GetScrollMaxY())
    end
    im.End()

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

return M