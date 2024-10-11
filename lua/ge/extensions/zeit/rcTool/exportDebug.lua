-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local function numTableToString(tbl)
    for k,v in pairs(tbl) do
        if type(v) == "number" then
            tbl[k] = tostring(v)
        end
    end
    return tbl
end

local function getPlatform()
    local platformInfo = {
        gamefolder = {FS:getGamePath(), FS:isGamePathCaseSensitive()},
        userfolder = {FS:getUserPath(), FS:isUserPathCaseSensitive()},
        cpu = numTableToString(Engine.Platform.getCPUInfo()),
        diskSpace = numTableToString(Engine.Platform.getDiskFreeSpace()),
        gpu = numTableToString(Engine.Platform.getGPUInfo()),
        memory = numTableToString(Engine.Platform.getMemoryInfo()),
        monitor = Engine.Platform.getMonitorInfo(),
        os = numTableToString(Engine.Platform.getOSInfo()),
        power = numTableToString(Engine.Platform.getPowerInfo()),
        time = Engine.Platform.getSystemTimeMS(),
        steam = Steam and {
            accountID = Steam.accountID,
            accountLoggedIn = Steam.accountLoggedIn,
            --authTicket = Steam.authTicket,
            --authTicketValidated = Steam.authTicketValidated,
            branch = Steam.branch,
            isWorking = Steam.isWorking,
            language = Steam.language,
            playerName = Steam.playerName,
            useSteam = Steam.useSteam,
            --friends = numTableToString(Steam.getFriendsList()),
        } or nil
    }

    jsonWriteFile(zeit_rcMain.cachePath.."debug/platform.json", platformInfo, true)
    zeit_rcMain.log("I", "exportDebug", "Platform info collected.")
end

local function export()
    local vulkan = Engine.getVulkanEnabled()
    if vulkan == false then --double check because of command argument
        for _,adapter in pairs(GFXInit.getAdapters()) do
            if adapter.gfx == "VK" then
                vulkan = true
                break
            end
        end
    end
    jsonWriteFile(zeit_rcMain.cachePath.."debug/modinfo.json", {
        version = zeit_rcMain.currentVersion,
        changelog = zeit_rcMain.currentChangelog,
        profilePath = zeit_rcMain.profilePath,
        currentProfile = zeit_rcMain.currentProfile,
        cachePath = zeit_rcMain.cachePath,
        historyPath = zeit_rcMain.historyPath,
        maxRollBack = zeit_rcMain.maxRollBack,
        currentRollBack = zeit_rcMain.currentRollBack,
        vulkan = vulkan
    }, true)

    jsonWriteFile(zeit_rcMain.cachePath.."debug/time.json", {
        exportdate = os.date(),
        runtime = Engine.Platform.getRuntime(),
    }, true)

    local files = {"/beamng.log", "/beamng.1.log", "/beamng.2.log", "/beamng-dxDiag.txt", "/beamng-launcher.log", "/beamng-launcher.1.log", "/beamng-launcher.2.log", "/settings/settings.json", "/settings/game-settings.cs"}
    local userfolder = FS:getUserPath()
    for k,v in pairs(FS:findFiles(zeit_rcMain.profilePath, "*", -1)) do
        local overwrites = FS:findOverrides(v) or {}
        if overwrites[1] and overwrites[1] == userfolder then
            table.insert(files, v)
        end
    end

    arrayConcat(files, FS:findFiles(zeit_rcMain.cachePath, "*", -1))
    local archiveName = zeit_rcMain.cachePath.."debug_export.zip"
    FS:removeFile(archiveName)
    local zip = ZipArchive()
    local zipSuccess = zip:openArchiveName(archiveName, 'w')
    if zipSuccess then
        for _,v in ipairs(files) do
            if FS:fileExists(v) then
                if not zip:addFile(v, v:sub(2)) then
                    zeit_rcMain.log("E", "exportDebug", "Export failed: failed adding file: "..v)
                    zipSuccess = false
                    break
                end
            end
        end
    end
    zip:close()

    if not zipSuccess then
        zeit_rcMain.log("E", "exportDebug", "Export failed: Zip failed to create correctly.")
        return false
    else
        zeit_rcMain.log("I", "exportDebug", "Export successful.")
        Engine.Platform.exploreFolder(archiveName)
    end
end

M.getPlatform = getPlatform
M.export = export

return M