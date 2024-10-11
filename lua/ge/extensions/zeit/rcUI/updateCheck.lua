-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.dependencies = {"zeit_rcMain", "ui_imgui"}
M.running = false

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
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
local onlineFeaturesEnabled = false
local isAutoCheck = false

local function renderChangelog(str)
    im.BeginChild1("zeitRenderSettingsUpdateChangelog", im.ImVec2(im.GetContentRegionAvailWidth(), 200))
    im.PushTextWrapPos(im.GetContentRegionAvailWidth())
    im.Text(str)
    if im.BeginPopupContextWindow() then
        if im.Selectable1("Copy", false) then
            setClipboard(str)
        end
        im.EndPopup()
    end
    im.PopTextWrapPos()
    im.EndChild()
end

local function updateAvailable()
    im.PushFont3("cairo_semibold_large")
    im.Text("An update is available for \"Zeit's graphics settings utils\"")
    im.PopFont()
    im.Text("Version "..newVersion.." Available.")
    im.Text("Changelog:")
    renderChangelog(changelog)

    if downloadLink ~= "" then
        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Download").x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x*4-style.WindowPadding.x-style.FramePadding.x*4)
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
    if zeit_rcMain.currentChangelog then
        im.Text("Changelog for this version:")
        renderChangelog(zeit_rcMain.currentChangelog)
    end
    im.Text("")

    if downloadLink ~= "" then
        im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Download").x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x*4-style.WindowPadding.x-style.FramePadding.x*4)
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
    if onlineFeaturesEnabled then
        im.Text("Timed out connecting to the repository. Unable to perform version check.")
        im.Text("Verify your internet connection and try again later.")
    else
        im.Text("Unable to perform version check with online features disabled.")
        im.Text("Enable online features below and try again.")

        local temp = im.BoolPtr(settings.getValue("onlineFeatures") == "enable")
        widgets.tooltipButton({
            desc = "Affects online features like the repository, mod subscriptions, achievements, leaderboards, chat features, content sharing features as well as the update check.",
            default = "true",
            key = "onlineFeatures"
        })
        im.SameLine()
        if im.Checkbox("Online Features", temp) then
            settings.setValue("onlineFeatures", temp[0] and "enable" or "disable")
        end
    end
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

    im.SetCursorPosX(style.WindowPadding.x)
    widgets.tooltipButton({
        desc = "Check for updates every time the game starts up.",
        default = "true",
        key = "zeit_graphics_auto_update_check"
    })
    im.SameLine()
    local temp = im.BoolPtr(settingsManager.get("auto_update_check"))
    if im.Checkbox("Automatic Update Check", temp) then
        settings.setValue("zeit_graphics_auto_update_check", temp[0])
    end
    im.SameLine()

    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x*2-style.WindowPadding.x-style.FramePadding.x*2)
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
        if timoutTimer > 15 or not onlineFeaturesEnabled then
            timeout = 1
            timoutTimer = 0
            showUI = not isAutoCheck
            M.running = false
        end
    end

    if showUI == false then return end

    style.push()

    -- don't want to mess up the imgui style.
    local success, err = pcall(render)
    if not success and err then
        zeit_rcMain.log("E", "onUpdate", err..debug.traceback())
    end

    style.pop()
end

local function getUpdateAvailable(isAuto)
    onlineFeaturesEnabled = settings.getValue("onlineFeatures") == "enable"
    isAutoCheck = isAuto
    if isAutoCheck and not onlineFeaturesEnabled then return end

    -- M1OVT74SQ = https://www.beamng.com/resources/unsupported-partially-outdated-daddelzeits-pack-of-stuff.16782/

    timeout = 0
    M.running = true
    core_online.apiCall("s1/v4/getMod/M1OVT74SQ", function(request)
        if timeout == 1 or request.responseData == nil then return end
        timeout = -1

        local rspData = request.responseData.data or {}

        if rspData.message then
            local ver = rspData.message:match("renderComponentsVersion=+[%d%.]+"):gsub("renderComponentsVersion=", "")
            local changelogB64 = (rspData.message:match("renderComponentsChangelog=.+==renderComponentsChangelogEnd") or "unavailable"):gsub("renderComponentsChangelog=", ""):gsub("renderComponentsChangelogEnd", "")

            downloadLink = (rspData.message:match("renderComponentsLink=.+==renderComponentsLinkEnd") or ""):gsub("renderComponentsLink=", ""):gsub("==renderComponentsLinkEnd", "")
            changelog = changelogB64 ~= "unavailable" and mime.unb64(changelogB64) or "unavailable"

            newVersion = tonumber(ver) or 0
            local verMismatch = newVersion > (currentVersion or 0)

            showUI = verMismatch or not isAutoCheck
        end
        M.running = false
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