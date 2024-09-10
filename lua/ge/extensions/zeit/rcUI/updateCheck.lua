-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain"}

M.dependencies = {"ui_imgui"}
local im = ui_imgui
local mime = require("mime")
local style = require("zeit/rcTool/style")
local widgets = require("zeit/rcUI/editWidgets")
local showUI = false
local changelog = ""
local downloadLink
local currentVersion = zeit_rcMain and zeit_rcMain.currentVersion or 0
local newVersion = 0
local timeout = -1
local timoutTimer = 0

local function updateAvailable()
    im.PushFont3("cairo_semibold_large")
    im.Text("An update is available for \"Zeit's graphics settings utils\"")
    im.PopFont()
    im.Text("Version "..newVersion.." Available.")
    im.Text("Changelog:")
    im.Text(changelog)
    if im.BeginPopupContextWindow() then
        if im.Selectable1("Copy", false) then
            setClipboard("Changelog:\n"..changelog)
        end
        im.BeginDisabled()
        im.Selectable1("Paste", false)
        im.Selectable1("Cut", false)
        im.EndDisabled()
        im.EndPopup()
    end
    im.Text("")

    if downloadLink ~= "" then
        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Download").x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x*3-style.ItemInnerSpacing.x*4-style.WindowPadding.x)
        if widgets.button("Download") then
            openWebBrowser(downloadLink)
        end
        im.SameLine()
    end
end

local function noUpdateAvailable()
    im.PushFont3("cairo_semibold_large")
    im.Text("No updates are available for \"Zeit's graphics settings utils\"")
    im.PopFont()
    im.Text("Changelog for this version:")
    im.Text(zeit_rcMain.currentChangelog or "")
    if im.BeginPopupContextWindow() then
        if im.Selectable1("Copy", false) then
            setClipboard("Changelog for this version:\n"..(zeit_rcMain.currentChangelog or ""))
        end
        im.BeginDisabled()
        im.Selectable1("Paste", false)
        im.Selectable1("Cut", false)
        im.EndDisabled()
        im.EndPopup()
    end
    im.Text("")

    if downloadLink ~= "" then
        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Download").x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x*3-style.ItemInnerSpacing.x*4-style.WindowPadding.x)
        if widgets.button("Download") then
            openWebBrowser(downloadLink)
        end
        im.SameLine()
    end
end

local function timedOut()
    im.PushFont3("cairo_semibold_large")
    im.Text("Unable to establish connection for \"Zeit's graphics settings utils\"")
    im.PopFont()
    im.Text("Timed out connecting to the repository. Unable to perform version check.")
    im.Text("Make sure online features are enabled and verify your internet connection.")
    im.Text("")
end

local function render()
    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextWindowPos(pos, nil, im.ImVec2(0.5, 0.5))
    im.Begin("Zeit's Graphics Utils: Update", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.Text("Version "..(zeit_rcMain and zeit_rcMain.currentVersion or "--"))
    im.SameLine()

    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("X").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
    if widgets.button("X") then
        showUI = false
        timoutTimer = 0
        timeout = -1
    end
    im.SetCursorPosX(0)

    im.Separator()
    if timeout == 1 then
        timedOut()
    elseif timeout == -1 then
        if newVersion > (currentVersion or 0) then
            updateAvailable()
        else
            noUpdateAvailable()
        end
    end

    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
    if widgets.button("Open Download Page") then
        openWebBrowser("https://beamng.com/threads/85768/")
    end
    im.Separator()
    im.Text("")
    im.End()
end

local function onUpdate(dt)
    if timeout == 0 then
        timoutTimer = timoutTimer + dt
        if timoutTimer > 15 then
            timeout = 1
            showUI = true
        end
    end

    if showUI == false then return end

    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render)
    if not success and err then
       zeit_rcMain.log("E", "onUpdate", err)
    end

    style.pop()
end

local function getUpdateAvailable(isAuto)
    if isAuto and settings.getValue('onlineFeatures') ~= 'enable' then return end

    -- M1OVT74SQ = https://www.beamng.com/resources/unsupported-partially-outdated-daddelzeits-pack-of-stuff.16782/

    timeout = 0
    core_online.apiCall("s1/v4/getMod/M1OVT74SQ", function(request)
        if timeout == 1 or request.responseData == nil then return end
        timeout = -1

        local rspData = request.responseData.data

        local ver = rspData.message:match("renderComponentsVersion=+%d+"):gsub("renderComponentsVersion=", "")
        local changelogB64 = (rspData.message:match("renderComponentsChangelog=.+==renderComponentsChangelogEnd") or "unavailable"):gsub("renderComponentsChangelog=", ""):gsub("renderComponentsChangelogEnd", "")

        downloadLink = (rspData.message:match("renderComponentsLink=.+==renderComponentsLinkEnd") or ""):gsub("renderComponentsLink=", ""):gsub("==renderComponentsLinkEnd", "")
        changelog = changelogB64 ~= "unavailable" and mime.unb64(changelogB64) or "unavailable"

        local verMismatch = tonumber(ver) and tonumber(ver) > (currentVersion or 0) or false
        newVersion = tonumber(ver) or 0

        showUI = verMismatch or not isAuto
    end)
end

local function onSchemeCommand(command)
    if command == "zeit_rc_update" then
        getUpdateAvailable()
    end
end

M.onUpdate = onUpdate
M.getUpdateAvailable = getUpdateAvailable
M.onSchemeCommand = onSchemeCommand

return M