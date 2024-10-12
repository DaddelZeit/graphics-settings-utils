-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local lpackDupe = require("/lua/ge/extensions/zeit/rcTool/lpackDupe")

local min = math.min
local max = math.max

local prevlog = log
local function log(...)
    if settingsManager.get("collect_logs") then
        prevlog(...)
    end
end

local sendMessage = nop
do
    local queueHookJS = nop
    if obj then
        queueHookJS = function(...) obj:queueHookJS(...) end
    elseif be then
        queueHookJS = function(...) be:queueHookJS(...) end
    end

    sendMessage = function(message)
        local onTap = message.config.onTap and "function() { bngApi.engineLua('"..message.config.onTap.."') }"
        if onTap then
            message.config.onTap = "<REPLACETHIS>"
        end
        message = jsonEncode(message)
        if onTap then
            message = message:gsub("\"<REPLACETHIS>\"", onTap)
        end
        queueHookJS("toastrMsg", "["..message.."]", 0)
    end
end

local modules = FS:findFiles("/lua/ge/extensions/zeit/rc", "*.lua", 1, false, false)
M.profilePath = "/settings/zeit/rendercomponents/"
M.currentProfile = "vanilla"
local mainPath = M.profilePath.."default.txt"
M.cachePath = "/temp/zeit/rendercomponents/"
M.historyPath = M.cachePath.."history/"..M.currentProfile.."/"

do
    local f = io.open(M.profilePath.."info.txt", "r")
    if f == nil then
        M.currentVersion = 0
        M.currentChangelog = ""
    else
        M.currentVersion = tonumber(f:read("l"))
        M.currentChangelog = f:read("*all")
        f:close()
    end

    local filepath = FS:findOverrides("lua/ge/extensions/zeit/rcMain.lua")
    if filepath and filepath[1] then
        filepath = filepath[1]:gsub("\\", "/"):match("/mods.+")
        M.modInstallPath = filepath

        local modname = string.lower(filepath)
        modname = modname:gsub('dir:/', '')
        modname = modname:gsub('/mods/', '')
        modname = modname:gsub('repo/', '')
        modname = modname:gsub('unpacked/', '')
        modname = modname:gsub('/', '')
        modname = modname:gsub('.zip$', '')
        log("I", "", "Mod installed in: "..filepath.." | Name result: "..modname)
        M.modInstallName = modname
    else
        sendMessage({
            type = "error",
            title = "Zeit's Graphics Utils",
            msg = "Install validation failed! File not found.",
            config = {
                timeOut = 0,
                progressBar = false,
                closeButton = true,

                positionClass = 'toast-top-right',
                preventDuplicates = true,
                preventOpenDuplicates = true,
            }
        })
        log("E", "", "Install validation failed! File not found.")
    end
end

M.isApplying = true
M.currentSettings = {}

M.maxRollBack = 0
M.currentRollBack = 1

local initStarted = false
local lastPhotoMode = false

local historyCommitTimer = 0
local historyJobRunning = false

local autoApply = true
local autoApplyFrameCooldown = 0
local autoApplyCounter = 0
local autoApplyCounterMax = 0

local ignoreCefStates = {"menu.options.display", "menu.options.graphics", "menu.options.userInterface", "menu.options.audio", "menu.options.controls", "menu.options.gameplay", "menu.options.camera", "menu.bigmap"}
local currentCefStateAllows = true
local uiActive = false
do
    local i = 0
    M.toggleUI = function(bool)
        i = max(i + (bool and 1 or -1))
        uiActive = i > 0
    end
end

local profilePathCache = {}
local function constructProfilePath(name)
    if not profilePathCache[name] then
        profilePathCache[name] = string.format("%s%s.profile.json", M.profilePath, name)
    end
    return profilePathCache[name]
end

local deleteInProgress = false
local loadRequested = false
local function _loadSettings(settings, extension)
    if extension then
        if extensions["zeit_rc_"..extension] then
            extensions["zeit_rc_"..extension].loadSettings(settings[extension])
        end
        log("I", "", "settings loaded for extension \""..extension.."\"")
    else
        for i = 1, #modules do
            local v = modules[i]
            if extensions[v] then
                extensions[v].loadSettings(settings[v:gsub("zeit_rc_", "")])
            end
        end
        log("I", "", "settings loaded")
    end

    M.currentSettings = deepcopy(settings)
    extensions.hook("onZeitGraphicsSettingsChange", settings)
end

local function loadSettings(applyGameFirst)
    if applyGameFirst then
        if not loadRequested then
            M.isApplying = true
            log("I", "", "safe loading profile: "..M.currentProfile)
            -- messes with fullscreen
            --core_settings_graphic.applyGraphicsState()

            settings.requestSave()
            core_settings_graphic.appliedChanges = true
            core_environment.setState(core_environment.getState())

            loadRequested = true
        end
        return
    else
        loadRequested = false
    end

    M.historyPath = M.cachePath.."history/"..M.currentProfile.."/"
    M.maxRollBack = #FS:findFiles(M.historyPath, "*", 0)
    M.currentRollBack = 1
    M.currentSettings = jsonReadFile(M.profilePath..M.currentProfile..".profile.json") or M.currentSettings

    _loadSettings(M.currentSettings)
    writeFile(mainPath, M.currentProfile)

    log("I", "", "profile loaded: "..M.currentProfile)
    M.isApplying = false
end

local function addHistory(data)
    log("I", "", "edit history save queued")
    historyCommitTimer = settingsManager.get("history_cooldown")

    if historyJobRunning then return end
    historyJobRunning = true

    core_jobsystem.wrap(function(job)
        while historyCommitTimer > 0 do
            job.sleep(0)
        end

        local path = M.cachePath.."history/"..M.currentProfile.."/"
        writeFile(path.."0", lpackDupe.encode(data))

        local historyFiles = #FS:findFiles(path, "*", 0)
        local maxHistory = settingsManager.get("max_history")
        local wrapLimit = max(math.ceil(maxHistory*0.025), 10)
        for i = historyFiles, 1, -1 do
            local file = path..tostring(i-1)
            if i > maxHistory then
                FS:removeFile(file)
            else
                FS:renameFile(file, path..tostring(i))
            end

            -- spread out load
            if i%wrapLimit == 0 then
                job.sleep(0)
            end
        end
        M.currentRollBack = 1
        M.maxRollBack = #FS:findFiles(M.historyPath, "*", 0)

        log("I", "", "edit history saved")
        extensions.hook("onZeitGraphicsHistoryCommit", data)
        historyJobRunning = false
    end, 0.1)()
end

local function undo()
    M.currentRollBack = min(M.currentRollBack+1, M.maxRollBack)
    local path = M.cachePath.."history/"..M.currentProfile.."/"
    local data = readFile(path..tostring(M.currentRollBack))

    local success = false
    success, data = pcall(lpackDupe.decode, data)
    if not success then
        if settingsManager.get("send_warnings") then
            sendMessage({
                type = "warning",
                title = "Zeit's Graphics Utils",
                msg = "History loading failed. This can happen after a game update. Click here to clear Mod Cache.",
                config = {
                    timeOut = 0,
                    progressBar = true,
                    closeButton = true,

                    positionClass = 'toast-top-right',
                    preventDuplicates = true,
                    preventOpenDuplicates = true,

                    onTap = "zeit_rcMain.clearTemp(1);"
                }
            })
        end
    elseif type(data) == "table" then
        _loadSettings(data)
        log("I", "", "settings loaded from history (undo): "..M.currentProfile.." ("..M.currentRollBack.." / "..M.maxRollBack..")")
    end
end

local function redo()
    M.currentRollBack = max(M.currentRollBack-1, 0)
    local path = M.cachePath.."history/"..M.currentProfile.."/"
    local data = readFile(path..tostring(M.currentRollBack))

    local success = false
    success, data = pcall(lpackDupe.decode, data)
    if not success then
        if settingsManager.get("send_warnings") then
            sendMessage({
                type = "warning",
                title = "Zeit's Graphics Utils",
                msg = "History loading failed. This can happen after a game update. Click here to clear Mod Cache.",
                config = {
                    timeOut = 0,
                    progressBar = false,
                    closeButton = true,

                    positionClass = 'toast-top-right',
                    preventDuplicates = true,
                    preventOpenDuplicates = true,

                    onTap = "zeit_rcMain.clearTemp(1);"
                }
            })
        end
    elseif type(data) == "table" then
        _loadSettings(data)
        log("I", "", "settings loaded from history (redo): "..M.currentProfile.." ("..M.currentRollBack.." / "..M.maxRollBack..")")
    end
end

local function saveProfile(profileName, data)
    local path = constructProfilePath(profileName)
    local didExist = FS:fileExists(path)
    local success = jsonWriteFile(path, data, true)
    log("I", "", "profile saved: "..profileName)
    extensions.hook("onZeitGraphicsProfileChange", didExist, data)
    return success
end

local function saveInfo(tbl, profile)
    local success = jsonWriteFile(M.profilePath..(profile and profile or M.currentProfile)..".info.json", tbl, true)
    log("I", "", "profile info saved: "..profile)
    return success
end

local function updateSettings(ext, data)
    local settings = deepcopy(M.currentSettings)
    settings[ext] = data
    addHistory(settings)
    saveProfile(M.currentProfile, settings)
    _loadSettings(settings, ext)
end

local function gameSettingsChange()
    loadSettings(false)
    autoApplyFrameCooldown = 2
    autoApply = settingsManager.get("auto_apply")
    autoApplyCounterMax = settingsManager.get("max_apply_loops")
end

local function onSettingsChanged(...)
    -- redirect, we need this for the removal dialog below
    if loadRequested or deleteInProgress then
        gameSettingsChange()
    end
end

local function loadInfo(name)
    return jsonReadFile(string.format("%s%s.info.json", M.profilePath, name))
end

local function loadProfile(name)
    M.currentProfile = name or "vanilla"
    loadSettings(true)
end

local function deleteProfile(name)
    local path = constructProfilePath(name)
    FS:removeFile(path:gsub(".profile.json", ".info.json"))
    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".info.json"))
    FS:removeFile(path:gsub(".profile.json", ".preview.png"))
    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".preview.png"))
    FS:removeFile(path:gsub(".profile.json", ".preview.jpg"))
    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".preview.jpg"))
    FS:removeFile(path)
    log("I", "", "profile deleted: "..path)

    extensions.hook("onZeitGraphicsProfileChange")
end

local function saveCurrentProfileDialog(autoEnterName)
    zeit_rcUI_saveOpenDialog.saveDialog(function(name)
        saveProfile(name, M.currentSettings)
    end, autoEnterName and M.currentProfile or "")
end

local function loadProfileDialog()
    zeit_rcUI_saveOpenDialog.loadDialog(function(name)
        loadProfile(name)
    end)
end

local function deleteProfileDialog(newname)
    zeit_rcUI_saveOpenDialog.deleteDialog(function(name)
        deleteProfile(name)
    end, newname)
end

local function getUniqueName(profileName)
    local i = 0
    local newFileName = profileName
    while FS:fileExists(constructProfilePath(newFileName)) do
        i = i + 1
        newFileName = profileName..string.format(" (%d)", i)
    end
    return newFileName, i
end

local function duplicateProfile(profileName)
    local oldpath = constructProfilePath(profileName)
    local data = jsonReadFile(oldpath)
    if data then
        local newFileName, i = getUniqueName(profileName)

        zeit_rcUI_saveOpenDialog.saveDialog(function(name)
            local path = constructProfilePath(name)

            local info = loadInfo(profileName)
            if info then
                info.name = string.format("%s (%d)", info.name, i)
                saveInfo(info, name)
            end
            FS:copyFile(oldpath:gsub(".profile.json", ".preview.png"), path:gsub(".profile.json", ".preview.png"))
            FS:copyFile(oldpath:gsub(".profile.json", ".preview.jpg"), path:gsub(".profile.json", ".preview.jpg"))

            saveProfile(name, data)
        end, newFileName)
    end
end

local function getAllProfiles()
    return FS:findFiles(M.profilePath, "*.profile.json", 0)
end

local function reloadModules(func)
    func = func or extensions.reload
    for i = 1, #modules do
        if modules[i]:match("/") then
            local cleanName = modules[i]:gsub("/lua/ge/extensions/", ""):gsub(".lua", ""):gsub("_","__"):gsub("/","_")
            modules[i] = cleanName
        end
        func(modules[i])
    end
end

local function validateSettingsApply()
    local shadowSettingsChanged = false
    local shadowSettings = M.currentSettings.shadowsettings
    if shadowSettings ~= nil and shadowSettings.shadowDistance ~= nil and scenetree.sunsky then
        shadowSettingsChanged = tonumber(shadowSettings.shadowDistance) ~= tonumber(scenetree.sunsky.shadowDistance)
    end

    if photoModeOpen ~= lastPhotoMode or shadowSettingsChanged and not (freeroam_bigMapMode and freeroam_bigMapMode.bigMapActive()) then
        if not loadRequested then
            gameSettingsChange() -- load settings again because they might be changed
            autoApplyCounter = autoApplyCounter + 1
            lastPhotoMode = photoModeOpen
        end
    else
        autoApplyCounter = 0
    end
end

local function checkForOldSettingsType()
    local oldMainPath = M.profilePath.."main.json"
    if FS:fileExists(oldMainPath) then
        local defaultProfile = jsonReadFile(oldMainPath) or {}
        writeFile(mainPath, defaultProfile[1] or "vanilla")
        FS:removeFile(oldMainPath)
    end
    local oldDefaultPath = M.profilePath.."default.meta"
    if FS:fileExists(oldDefaultPath) then
        FS:renameFile(oldDefaultPath, mainPath)
    end

    local dir = "/settings/zeit/rendercomponents/"
    local filesInFolder = FS:findFiles(dir, "save.*.json", 0)
    if #filesInFolder ~= 0 then
        -- make backup
        local backupdir = "/settings/zeit/rendercomponents_backup"
        FS:directoryCreate(backupdir)
        for i = 1, #filesInFolder do
            FS:copyFile(filesInFolder[i], backupdir)
        end

        -- convert to new profile
        local newSave = {}
        for i = 1, #filesInFolder do
            local v = filesInFolder[i]
            newSave[v:gsub(".+save.", ""):gsub(".json", "")] = jsonReadFile(v)
        end
        jsonWriteFile(dir.."generated.profile.json", newSave, true)

        -- also add desc
        saveInfo({
            name = "Auto-Generated User Profile",
            desc = "This profile was converted from the user's old settings.\n(Automatically generated)",
            author = Steam.playerName ~= "" and Steam.playerName or "Unknown",
            date = os.date()
        })
        log("I", "", "old settings migrated")

        -- remove old files
        for i = 1, #filesInFolder do
            FS:removeFile(filesInFolder[i])
        end

        sendMessage({
            type = "info",
            title = "Zeit's Graphics Utils",
            msg = "Old settings structure detected. A backup was created and the files were updated.",
            config = {

                timeOut = 7500,
                progressBar = false,
                closeButton = true,


                positionClass = 'toast-top-right',
                preventDuplicates = true,
                preventOpenDuplicates = true,
            }
        })

        M.currentProfile = "generated"
        writeFile(mainPath, M.currentProfile)
    end
end

-- The init is delayed to avoid conflicts with the game itself
local function mainInit()
    log("I", "", "main init started")
    checkForOldSettingsType()
    settingsManager.validate()

    autoApply = settingsManager.get("auto_apply")
    autoApplyCounterMax = settingsManager.get("max_apply_loops")

    local mainSettings = readFile(mainPath)
    if mainSettings and FS:fileExists(constructProfilePath(mainSettings)) then
        M.currentProfile = mainSettings
    end

    extensions.load("zeit_rcUI_saveOpenDialog")
    extensions.load("zeit_rcUI_edit")
    extensions.load("zeit_rcUI_colorCorrectionEditor")

    extensions.load("zeit_rcUI_profileManager")
    extensions.load("zeit_rcUI_settings")
    extensions.load("zeit_rcUI_screenshot")
    extensions.load("zeit_rcUI_miscWindows")

    extensions.load("zeit_rcUI_select")
    extensions.load("zeit_rcUI_loadingSpinner")

    extensions.load("zeit_rcUI_deleteAll")
    extensions.load("zeit_rcUI_updateCheck")

    if worldReadyState == -1 and zeit_rcUI_updateCheck and settingsManager.get("auto_update_check") then zeit_rcUI_updateCheck.getUpdateAvailable(true) end

    reloadModules(extensions.load)
    loadSettings(true)

    if core_ckgraphics and settingsManager.get("send_warnings") then
        sendMessage({
            type = "warning",
            title = "Zeit's Graphics Utils",
            msg = "CK Graphics Mod detected. These two mods may conflict. Hover here to make this message disappear.",
            config = {
                timeOut = 6500,
                progressBar = true,
                closeButton = true,

                positionClass = 'toast-top-right',
                preventDuplicates = true,
                preventOpenDuplicates = true,
            }
        })
    end

    if core_input_categories then
        core_input_categories.rcZeit = {
            desc = "Keybind Controls for Zeit's Graphics Utils",
            order = 1.75,
            title = "Zeit's Graphics Utils",
            icon = "photo_filter"
        }
    end

    extensions.hook("onZeitGraphicsLoaded")
end

local function onPreRender(dt)
    if initStarted then
        mainInit()
        initStarted = false
    end

    historyCommitTimer = max(historyCommitTimer - dt, 0)
    if not autoApply or not currentCefStateAllows or (worldReadyState == 2 and uiActive) then return end
    autoApplyFrameCooldown = max(autoApplyFrameCooldown - 1, 0)
    if autoApplyFrameCooldown == 0 then
        if autoApplyCounter < autoApplyCounterMax then
            validateSettingsApply()
        elseif autoApplyCounter == autoApplyCounterMax then
            if settingsManager.get("send_warnings") then
                sendMessage({
                    type = "warning",
                    title = "Zeit's Graphics Utils",
                    msg = "Auto-Apply maximum was reached. If this happens often, click here to disable this feature. Ignoring this can result in diminished performance.",
                    config = {
                        timeOut = 0,
                        progressBar = false,
                        closeButton = true,

                        positionClass = 'toast-top-right',
                        preventDuplicates = true,
                        preventOpenDuplicates = true,

                        onTap = [[if zeit_rcUI_settings then
                            if not zeit_rcUI_settings.showUI then
                                zeit_rcUI_settings.toggleUI()
                            end
                            zeit_rcUI_settings.setScrollTo("Auto-Apply")
                        end]]
                    }
                })
            end
            autoApplyCounter = autoApplyCounterMax + 1
        end
    end
end

local function onExtensionLoaded()
    initStarted = true
end

local function onExtensionUnloaded()
    extensions.unload("zeit_rcUI_saveOpenDialog")
    extensions.unload("zeit_rcUI_edit")
    extensions.unload("zeit_rcUI_colorCorrectionEditor")
    extensions.unload("zeit_rcUI_profileManager")
    extensions.unload("zeit_rcUI_settings")
    extensions.unload("zeit_rcUI_screenshot")
    extensions.unload("zeit_rcUI_miscWindows")
    extensions.unload("zeit_rcUI_select")
    extensions.unload("zeit_rcUI_loadingSpinner")
    extensions.unload("zeit_rcUI_updateCheck")
    reloadModules(extensions.unload)
end

local function onClientPostStartMission()
    initStarted = true
end

local function onUiChangedState(new)
    local lastCefStateAllows = currentCefStateAllows
    currentCefStateAllows = arrayFindValueIndex(ignoreCefStates, new) == false
    if not lastCefStateAllows and currentCefStateAllows then
        gameSettingsChange()
    end
end

local function clearTemp(type)
    if type == 1 then
        FS:directoryRemove(M.cachePath)
    elseif type == 2 then
        FS:directoryRemove("/temp/shaders/")
    else
        FS:directoryRemove(M.cachePath)
        FS:directoryRemove("/temp/shaders/")
    end
end

local function removeMod(automatically)
    log("I", "", "Removal UI activated for: "..M.modInstallName)
    if automatically then
        log("I", "", "Removal UI activated automatically")
    end

    zeit_rcUI_deleteAll.toggleUI(true, not automatically, function(callbacks, job)
        deleteInProgress = true
        local step = 1/6
        -- job.sleep is used here to give the user some feedback.
        -- It's not required at all outside of the while loop,
        -- but it's good to let people know what's being done to their game.

        log("I", "", "Removal: Resetting Graphics")
        callbacks.progress(step, "Resetting Graphics...")
        M.currentProfile = "vanilla"
        _loadSettings({}) -- load empty settings, resets everything to absolute default
        job.sleep(step)

        log("I", "", "Removal: Clearing From Userfolder")
        callbacks.progress(step*2, "Clearing From Userfolder...")
        FS:directoryRemove(M.profilePath)
        job.sleep(step)

        log("I", "", "Removal: Clearing Settings")
        callbacks.progress(step*3, "Clearing Settings Hive...")

        -- overwrite this function
        -- (we no longer need the original one)
        local waitForSettings = true
        gameSettingsChange = function()
            waitForSettings = false
        end
        settingsManager.remove()
        settings.requestSave()
        while waitForSettings do
            job.sleep(step)
        end

        log("I", "", "Removal: Clearing Cache")
        callbacks.progress(step*4, "Clearing Cache...")
        clearTemp()
        job.sleep(step)

        log("I", "", "Removal: Unloading Lua")
        callbacks.progress(step*5, "Unloading Lua...")
        extensions.unload(M.__extensionName__)
        job.sleep(step)

        log("I", "", "Removal done")
        callbacks.progress(step*6, "Finished.")
        callbacks.finished()
    end)
end

local function onFilesChanged()
    if not zeit_rcUI_deleteAll or not M.modInstallName then return end
    local entry = core_modmanager.getModDB(M.modInstallName)
    if entry == nil then
        if settingsManager.get("delete_dialog_show") then
            removeMod(true)
        end
    elseif zeit_rcUI_deleteAll.showUI then
        log("I", "", "Removal UI recalled")
        zeit_rcUI_deleteAll.toggleUI(false)
    end
end

M.log = log
M.sendMessage = sendMessage

M.getUniqueName = getUniqueName
M.getAllProfiles = getAllProfiles
M.constructProfilePath = constructProfilePath

M.saveProfile = saveProfile
M.saveInfo = saveInfo
M.saveCurrentProfileDialog = saveCurrentProfileDialog
M.updateSettings = updateSettings

M.loadProfile = loadProfile
M.loadInfo = loadInfo
M.loadProfileDialog = loadProfileDialog
M.loadSettings = loadSettings

M.deleteProfileDialog = deleteProfileDialog
M.duplicateProfile = duplicateProfile
M.removeMod = removeMod

M.undo = undo
M.redo = redo
M.clearTemp = clearTemp

M.onPreRender = onPreRender
M.onClientPostStartMission = onClientPostStartMission
M.onSettingsChanged = onSettingsChanged
M.onFilesChanged = onFilesChanged
M.onUiChangedState = onUiChangedState

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M