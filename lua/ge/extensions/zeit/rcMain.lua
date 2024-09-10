-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local min = math.min
local max = math.max

local modules = FS:findFiles("/lua/ge/extensions/zeit/rc", "*.lua", 1, false, false)
M.profilePath = "/settings/zeit/rendercomponents/"
M.currentProfile = "vanilla"
local mainPath = M.profilePath.."default.meta"
M.cachePath = "/temp/zeit/rendercomponents/"
M.historyPath = M.cachePath.."history/"..M.currentProfile.."/"

local settingsDefaults = require("/lua/ge/extensions/zeit/rcTool/settingsDefaults")

do
    local f = io.open(M.profilePath.."info.meta", "r")
    if f == nil then
        M.currentVersion = 0
        M.currentChangelog = ""
    else
        M.currentVersion = tonumber(f:read("l"))
        M.currentChangelog = f:read("*all")
        f:close()
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

local prevlog = log
local function log(...)
    if settings.getValue("zeit_graphics_collect_logs") then
        prevlog(...)
    end
end

local function constructProfilePath(name)
    return string.format("%s%s.profile.json", M.profilePath, name)
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
    historyCommitTimer = settings.getValue("zeit_graphics_history_cooldown")

    if historyJobRunning then return end
    historyJobRunning = true

    core_jobsystem.wrap(function(job)
        while historyCommitTimer > 0 do
            job.sleep(1)
        end

        local path = M.cachePath.."history/"..M.currentProfile.."/"
        writeFile(path.."0", lpack.encode(data))

        local historyFiles = #FS:findFiles(path, "*", 0)
        for i = historyFiles, 1, -1 do
            local file = path..tostring(i-1)
            if i > 1000 then
                FS:removeFile(file)
            else
                FS:renameFile(file, path..tostring(i))
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
    success, data = pcall(lpack.decode, data)
    if not success then
        if settings.getValue("zeit_graphics_send_warnings") then
            guihooks.trigger('toastrMsg', {
                type = "warning",
                title = "Zeit's Graphics Utils",
                msg = "History loading failed. This can happen after a game update. Clear Mod Cache in the settings. Hover here to make this message disappear.",
                config = {
                    -- require user to acknowledge
                    timeOut = 0,
                    progressBar = false,
                    closeButton = true,

                    -- default stuffs
                    positionClass = 'toast-top-right',
                    preventDuplicates = true,
                    preventOpenDuplicates = true,
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
    success, data = pcall(lpack.decode, data)
    if not success then
        if settings.getValue("zeit_graphics_send_warnings") then
            guihooks.trigger('toastrMsg', {
                type = "warning",
                title = "Zeit's Graphics Utils",
                msg = "History loading failed. This can happen after a game update. Clear Mod Cache in the settings. Hover here to make this message disappear.",
                config = {
                    -- require user to acknowledge
                    timeOut = 0,
                    progressBar = false,
                    closeButton = true,

                    -- default stuffs
                    positionClass = 'toast-top-right',
                    preventDuplicates = true,
                    preventOpenDuplicates = true,
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
    autoApply = settings.getValue("zeit_graphics_auto_apply")
    autoApplyCounterMax = settings.getValue("zeit_graphics_max_apply_loops")
end

local function onSettingsChanged(...)
    -- redirect, we need this for the removal dialog below
    if loadRequested or deleteInProgress then
        gameSettingsChange()
    end
end

local function checkForOldSettingsType()
    local oldMainPath = M.profilePath.."main.json"
    if FS:fileExists(oldMainPath) then
        local defaultProfile = jsonReadFile(oldMainPath) or {}
        writeFile(mainPath, defaultProfile[1] or "vanilla")
        FS:removeFile(oldMainPath)
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

        guihooks.trigger('toastrMsg', {
            type = "warning",
            title = "Zeit's Graphics Utils",
            msg = "Old settings structure detected. A backup was created and the files were updated. Hover here to make this message disappear.",
            config = {
                -- require user to acknowledge
                timeOut = 0,
                progressBar = false,
                closeButton = true,

                -- default stuffs
                positionClass = 'toast-top-right',
                preventDuplicates = true,
                preventOpenDuplicates = true,
            }
        })

        M.currentProfile = "generated"
        writeFile(mainPath, M.currentProfile)
    end
end

local function loadInfo(name)
    return jsonReadFile(string.format("%s%s.info.json", M.profilePath, name)) or {}
end

local function loadProfile(name)
    M.currentProfile = name or "vanilla"
    loadSettings(true)
end

local function deleteProfile(name)
    local path = constructProfilePath(name)
    FS:removeFile(path:gsub(".profile.json", ".info.json"))
    FS:removeFile(path:gsub(".profile.json", ".preview.png"))
    FS:removeFile(path:gsub(".profile.json", ".preview.jpg"))
    FS:removeFile(path)

    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".info.json"))
    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".preview.png"))
    log("I", "", "profile deleted: "..path:gsub(".profile.json", ".preview.jpg"))
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
            if next(info) then
                info.name = string.format("%s (%d)", info.name, i)
                saveInfo(info, name)
            end
            FS:copyFile(oldpath:gsub(".profile.json", ".preview.png"), path:gsub(".profile.json", ".preview.png"))
            FS:copyFile(oldpath:gsub(".profile.json", ".preview.jpg"), path:gsub(".profile.json", ".preview.jpg"))

            saveProfile(name, data)
        end, newFileName)
    end
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

local function getAllProfiles()
    return FS:findFiles(M.profilePath, "*.profile.json", 0)
end

-- The init is delayed to avoid conflicts with the game itself
local function mainInit()
    log("I", "", "main init started")
    checkForOldSettingsType()
    settingsDefaults.validate()
    autoApply = settings.getValue("zeit_graphics_auto_apply")
    autoApplyCounterMax = settings.getValue("zeit_graphics_max_apply_loops")

    local mainSettings = readFile(mainPath)
    if mainSettings and FS:fileExists(constructProfilePath(mainSettings)) then
        M.currentProfile = mainSettings
    end

    extensions.load("zeit_rcUI_saveOpenDialog")
    extensions.load("zeit_rcUI_edit")

    extensions.load("zeit_rcUI_profileManager")
    extensions.load("zeit_rcUI_settings")
    extensions.load("zeit_rcUI_screenshot")

    extensions.load("zeit_rcUI_select")

    extensions.load("zeit_rcUI_loadingSpinner")

    extensions.load("zeit_rcUI_deleteAll")
    extensions.load("zeit_rcUI_updateCheck")

    if zeit_rcUI_updateCheck then zeit_rcUI_updateCheck.getUpdateAvailable(true) end

    reloadModules(extensions.load)
    loadSettings(true)

    if core_ckgraphics and settings.getValue("zeit_graphics_send_warnings") then
        guihooks.trigger('toastrMsg', {
            type = "warning",
            title = "Zeit's Graphics Utils",
            msg = "CK Graphics Mod detected. These two mods may conflict. Hover here to make this message disappear.",
            config = {
                -- require user to acknowledge
                timeOut = 6500,
                progressBar = true,
                closeButton = true,

                -- default stuffs
                positionClass = 'toast-top-right',
                preventDuplicates = true,
                preventOpenDuplicates = true,
            }
        })
    end
end

local function onPreRender(dt)
    if initStarted then
        mainInit()
        initStarted = false
    end

    historyCommitTimer = max(historyCommitTimer - dt, 0)
    if not autoApply or not currentCefStateAllows or not scenetree.sunsky or (worldReadyState == 2 and uiActive) then return end
    autoApplyFrameCooldown = max(autoApplyFrameCooldown - 1, 0)
    if autoApplyFrameCooldown == 0 then
        if autoApplyCounter < autoApplyCounterMax then
            local shadowSettingsChanged = false
            if M.currentSettings.shadowsettings ~= nil then
                if M.currentSettings.shadowsettings.shadowDistance ~= nil then
                    shadowSettingsChanged = tonumber(M.currentSettings.shadowsettings.shadowDistance) ~= tonumber(scenetree.sunsky.shadowDistance)
                end
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
        elseif autoApplyCounter == autoApplyCounterMax then
            if settings.getValue("zeit_graphics_send_warnings") then
                guihooks.trigger('toastrMsg', {
                    type = "warning",
                    title = "Zeit's Graphics Utils",
                    msg = "Auto-Apply maximum was reached. If this happens often, disable it in the settings. Ignoring this can result in diminished performance. Hover here to make this message disappear.",
                    config = {
                        -- require user to acknowledge
                        timeOut = 0,
                        progressBar = false,
                        closeButton = true,

                        -- default stuffs
                        positionClass = 'toast-top-right',
                        preventDuplicates = true,
                        preventOpenDuplicates = true,
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
    extensions.unload("zeit_rcUI_profileManager")
    extensions.unload("zeit_rcUI_settings")
    extensions.unload("zeit_rcUI_screenshot")
    extensions.unload("zeit_rcUI_select")
    extensions.unload("zeit_rcUI_loadingSpinner")
    extensions.unload("zeit_rcUI_updateCheck")
    reloadModules(extensions.unload)
end

local function onClientPostStartMission()
    initStarted = true
end

local function onUiChangedState(new)
    currentCefStateAllows = arrayFindValueIndex(ignoreCefStates, new) == false
end

local function clearTemp(type)
    if not type then
        FS:directoryRemove(M.cachePath)
        FS:directoryRemove("/temp/shaders/")
    elseif type == 1 then
        FS:directoryRemove(M.cachePath)
    elseif type == 2 then
        FS:directoryRemove("/temp/shaders/")
    end
end

local function onFilesChanged()
    if not zeit_rcUI_deleteAll then return end
    local entry = core_modmanager.getModDB("renderer_components_loadsave_zeit")
    if entry == nil then
        zeit_rcUI_deleteAll.toggleUI(true, function(callbacks, job)
            deleteInProgress = true
            local step = 1/6
            -- job.sleep is used here to give the user some feedback.
            -- It's not required at all outside the while loop,
            -- but it's good to let people know what's being done to their game.

            callbacks.progress(step, "Resetting Graphics...")
            M.currentProfile = "vanilla"
            _loadSettings({})
            job.sleep(step)

            callbacks.progress(step*2, "Clearing Userfolder...")
            FS:directoryRemove(M.profilePath)
            job.sleep(step)

            callbacks.progress(step*3, "Clearing Settings Hive...")

            -- overwrite this function
            -- (we no longer need the original one)
            local waitForSettings = true
            gameSettingsChange = function()
                waitForSettings = false
            end
            settingsDefaults.remove()
            settings.requestSave()
            while waitForSettings do
                job.sleep(step)
            end

            callbacks.progress(step*4, "Clearing Cache...")
            clearTemp()
            job.sleep(step)

            callbacks.progress(step*5, "Unloading Lua...")
            extensions.unload(M.__extensionName__)
            job.sleep(step)

            callbacks.progress(step*6, "Finished.")
            callbacks.finished()
        end)
    else
        zeit_rcUI_deleteAll.toggleUI(false)
    end
end

M.log = log

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