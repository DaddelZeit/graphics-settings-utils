-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local im = ui_imgui
M.showUI = false
--local tab = 1
local size = im.ImVec2(0,0)
local loading = true
local dotdotdotTimer = 0
local profiles = {}
local keys = {}
local searchkeys = {}
local search = im.ArrayChar(2048)
local currentTag
local iconsTex

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
    local imguiUtils = require("ui/imguiUtils")
    iconsTex = imguiUtils.texObj("/settings/zeit/rendercomponents/icons.png")
    profiles = {}
    keys = {}

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
            fileSource = fileSource
        }

        table.insert(keys, internalName)
    end

    -- sort key array
    -- TODO: implement ui options
    keys = getSortedAlphabeticalByDisplayName(keys)
    searchkeys = keys
end

local function toggleUI()
    if ui_gameBlur then ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", nil) end
    M.showUI = not M.showUI
    if M.showUI then
        refreshCache()
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
    if im.Button("Refresh") then
        refreshCache()
    end
    im.SameLine()
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

    im.SameLine()
    textCentered("Zeit's Graphics Utils: Profile Manager")
    im.SameLine()

    im.SetCursorPosX(im.GetWindowSize().x-90)
    if im.Button("Install") then
        Engine.Platform.exploreFolder("/mods/")
    end
    if im.IsItemHovered() then
        im.SetTooltip("Click to open your mods folder.\nInstall new profiles here.")
    end
    if im.Button("X") then
        toggleUI()
    end
    im.SetCursorPosX(0)

    im.Separator()
end

local function renderChild(name, data)
    im.BeginChild1("##"..name, im.ImVec2(size.x, size.y/4), false)
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
    im.BeginChild1("##descriptionwindow_"..name, im.ImVec2(size.x-data.preview.size.x*imgSizeMul*1.05, (size.y/4)-im.GetCursorPosY()-25))
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
    im.EndChild()

    im.SetCursorPosY((size.y/4)-26)
    im.Separator()
    im.SetCursorPosX(cursorPos.x+data.preview.size.x*imgSizeMul*1.025)
    if im.Button("View in Explorer") then
        Engine.Platform.exploreFolder(zeit_rcMain.profilePath..name..".profile.json")
    end
    im.SameLine()
    if im.Button("Delete") then
        zeit_rcMain.deleteProfile(name)
    end
    im.SameLine()

    local colOverwritten = zeit_rcMain.currentProfile == name
    if colOverwritten then
        im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    end
    if im.Button("Apply") then
        zeit_rcMain.currentProfile = name
        zeit_rcMain.loadSettings()
    end
    im.SameLine()
    if colOverwritten then
        im.PopStyleColor()
    end

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
        im.SetTooltip("Click to generate image.\nWARNING: This will not return your game to the previous state.")
        if im.IsMouseClicked(0) then
            toggleUI()
            zeit_rcMain.currentProfile = name
            zeit_rcMain.loadSettings()
            extensions.load("zeit_rcTakePreview")
            zeit_rcTakePreview.start(zeit_rcMain.profilePath..name..".preview")
        end
    end

    im.EndChild()
    im.Separator()
end

local function renderOnline(dt)
    if loading then
        im.PushFont3("cairo_semibold_large")
        textCentered(dotdotdotTimer < 1 and "Loading." or
                     dotdotdotTimer < 2 and "Loading.." or
                     dotdotdotTimer < 3 and "Loading..." or
                     "Loading"
                    )
        im.PopFont()
        textCentered("This could take a while.")
        dotdotdotTimer = (dotdotdotTimer + dt*2)%4
        im.Text("")
    end
end

local function checkIfHasTag(ffitags, tag)
    local tags = {}
    for k,v in ipairs(ffitags) do
        tags[k] = ffi.string(v)
    end
    return tableContains(tags, ffi.string(tag))
end

local function renderInstalled()
    for _,v in ipairs(searchkeys) do
        if not currentTag or checkIfHasTag(profiles[v].info.tags, currentTag) then
            renderChild(v, profiles[v])
        end
    end
end

local function onUpdate(dt)
    if M.showUI == false then return end

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))
    size = im.ImVec2(
        mainPort.Size.x/2,
        mainPort.Size.y/2)

    if getCurrentLevelIdentifier() then
        im.SetNextWindowBgAlpha(0.4)
    end
    im.SetNextWindowSize(size)
    im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))
    im.Begin("zeitRenderSettingsProfileManager", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_MenuBar)

    local pos1 = im.GetWindowPos()
    local deskRes = getDesktopResolution()
    local data = {pos1.x/deskRes.x, pos1.y/deskRes.y, size.x/deskRes.x, size.y/deskRes.y, 1}
    if not ui_gameBlur then extensions.load("ui_gameBlur") end
    ui_gameBlur.replaceGroup("zeitRenderSettingsProfileManager", {["1"] = data})

    im.BeginMenuBar()
    renderTopBar()
    im.EndMenuBar()
    --if tab == 0 then
    --    renderOnline(dt)
    --else
        renderInstalled()
    --end
    im.End()
end

local function onExtensionLoaded()
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.toggleUI = toggleUI
M.refreshCache = refreshCache

return M