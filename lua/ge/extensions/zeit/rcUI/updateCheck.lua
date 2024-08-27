-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

--[[
- Updated general UI style
- Updated Profile Manager design
- Updated Edit window design
- Updated "General Effects" inputs to include numbers, checkboxes when possible

- Added export compression for variables
- Implemented other serialization algorithm (smaller results)
- Added most variables from "General Effects" as actual fields and sliders
- Added a drop-down containing the available "General Effects" variables
- Added info hover windows to all recognized variables

- Fixed graphic settings not entirely resetting when switching profiles
- Made auto focus use game's calculation
]]

--[[
- Added PostFX: Vignette, Sharpness
- Changed General Effects edit layout (clearer to use)
- Updated profiles to use new settings

- Added PostFX main header, moved contrast & saturation here
- Some sections are now optionally saved: reduced export size
- Auto Focus can now focus on cars, improved performance

- Fixed thumnbnail tool being broken when started from main menu
- Removed skipLoadDLs setting: causes crashes on map load
- Future-proofed code with support from Car_Killer
- Internally re-arranged code
- Fixed constant-reloading causing flickering for some people
- Fixed error on level load or level unload
]]

--[[
- Added PostFX: Film Grain, Letterbox
- Added Edit History (Undo/Redo)
- Moved shadow settings from world editor to actual fields
- Combined both export options under one header
- Renamed "Save Renderer Components" button to be clearer

- Fixed edit UI expanding indefintely whenever the scroll bar appears
- Fixed custom PostFX unloading between level changes
- Fixed more settings not properly resetting
- Fixed texture reduction & lighting manager not applying on profile change
- Fixed some incorrect descriptions
- Fixed some more apply-loops
]]

local currentVer = 14

M.dependencies = {"ui_imgui"}
local im = ui_imgui
local mime = require("mime")
local style = require("zeit/rcTool/style")
local showUI = false
local changelog = ""
local downloadLink

local function onUpdate()
    if showUI == false then return end

    style.push()

    local mainPort = im.GetMainViewport()
    local pos = im.ImVec2(
        mainPort.Pos.x + (mainPort.Size.x/2),
        mainPort.Pos.y + (mainPort.Size.y/2))

    im.SetNextWindowPos(pos, im.Cond_Appearing, im.ImVec2(0.5, 0.5))
    im.Begin("zeitRenderSettingsLoaderUpdate", nil, im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_AlwaysAutoResize)

    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("X").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
    if im.Button("X") then
        showUI = false
    end
    im.SetCursorPosX(0)

    im.Separator()
    im.PushFont3("cairo_semibold_large")
    im.Text("An update is available for \"Zeit's graphics settings utils\"")
    im.PopFont()
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
        if im.Button("Download") then
            openWebBrowser(downloadLink)
        end
        im.SameLine()
    end
    im.SetCursorPosX(im.GetWindowSize().x-im.CalcTextSize("Open Download Page").x-style.ItemSpacing.x-style.ItemInnerSpacing.x*2-style.WindowPadding.x)
    if im.Button("Open Download Page") then
        openWebBrowser("https://beamng.com/threads/85768/")
    end
    im.Separator()
    im.Text("")
    im.End()

    style.pop()
end

local function getUpdateAvailable()
    if not settings.getValue('onlineFeatures') == 'enable' then return false, "" end

    -- M1OVT74SQ = https://www.beamng.com/resources/unsupported-partially-outdated-daddelzeits-pack-of-stuff.16782/

    core_online.apiCall("s1/v4/getMod/M1OVT74SQ", function(request)
        if request.responseData == nil then return end

        local rspData = request.responseData.data

        local ver = rspData.message:match("renderComponentsVersion=+%d+"):gsub("renderComponentsVersion=", "")
        local changelogB64 = (rspData.message:match("renderComponentsChangelog=.+==renderComponentsChangelogEnd") or "unavailable"):gsub("renderComponentsChangelog=", ""):gsub("renderComponentsChangelogEnd", "")

        downloadLink = (rspData.message:match("renderComponentsLink=.+==renderComponentsLinkEnd") or ""):gsub("renderComponentsLink=", ""):gsub("==renderComponentsLinkEnd", "")
        showUI = tonumber(ver) and tonumber(ver) > currentVer or false
        changelog = changelogB64 ~= "unavailable" and mime.unb64(changelogB64) or "unavailable"
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