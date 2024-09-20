-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local currentVer = 8

M.dependencies = {"ui_imgui"}
local im = ui_imgui
local mime = require("mime")
local showUI = false
local changelog = ""

local function onUpdate()
    if showUI == false then return end

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))
    im.Begin("zeitRenderSettingsLoaderUpdate", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.SetCursorPosX(im.GetWindowSize().x-27)
    if im.Button("X") then
        showUI = false
    end
    im.SetCursorPosX(0)

    im.Separator()
    im.PushFont3("cairo_semibold_large")
    im.Text("An update is available for \"Zeit's graphics settings utils\"")
    im.PopFont()
    im.Text("Changelog:")
    im.Text(changelog or "not available")
    im.Text("")
    if im.Button("Open Download Page") then
        openWebBrowser("https://beamng.com/threads/85768/")
    end
    im.Separator()
    im.Text("")
    im.End()
end

local function getUpdateAvailable()
    if not settings.getValue('onlineFeatures') == 'enable' then return false, "" end

    -- M1OVT74SQ = https://www.beamng.com/resources/unsupported-partially-outdated-daddelzeits-pack-of-stuff.16782/

    core_online.apiCall("s1/v4/getMod/M1OVT74SQ", function(request)
        if request.responseData == nil then return end

        local rspData = request.responseData.data

        local ver = rspData.message:match("renderComponentsVersion=+%d+"):gsub("renderComponentsVersion=", "")
        local changelogB64 = (rspData.message:match("renderComponentsChangelog=.+==renderComponentsChangelogEnd") or "unavailable"):gsub("renderComponentsChangelog=", ""):gsub("renderComponentsChangelogEnd", "")

        showUI = tonumber(ver) and tonumber(ver) > currentVer or false
        changelog = changelogB64 ~= "unavailable" and mime.unb64(changelogB64) or "unavailable"
    end)
end

M.onUpdate = onUpdate
M.getUpdateAvailable = getUpdateAvailable

return M