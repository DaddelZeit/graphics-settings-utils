-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.currentSettings = {
    dof={
        farBlurMax=0.15,
        farSlope=10,
        focalDist=0,
        isEnabled="1",
        lerpBias="1.0 1.666667 2.000000 -1.000000",
        lerpScale="-5.000000 -3.333333 -2.000000 2.000000",
        maxRange=100,
        nearBlurMax=0,
        nearSlope=-20
    },
    generaleffects={},
    rendercomponents={
        HSL="1 1 1 1",
        bloomScale="0",
        blueShiftColor="1.04999995 0.970000029 1.26999998",
        blueShiftLumVal="0.100000001",
        colorCorrectionRampPath="",
        colorCorrectionStrength="1",
        enableBlueShift="0",
        enabled="1",
        knee=0.1000000015,
        maxAdaptedLum="1",
        middleGray="0.5",
        oneOverGamma="1",
        threshHold=3.5
    }
}

local modules = FS:findFiles("/lua/ge/extensions/zeit/rc", "*.lua", 1, false, false)
M.profilePath = "/settings/zeit/rendercomponents/"
M.currentProfile = "vanilla"
M.cachePath = "/temp/zeit/rendercomponents/"
M.historyPath = M.cachePath..M.currentProfile.."/"
local initStarted = false
local lastPhotoMode = false
local historyCommitTimer = 0
local historyJobRunning = false

M.maxRollBack = 0
M.currentRollBack = 1

local loadRequested = false
local function _loadSettings(settings)
    for _,v in ipairs(modules) do
        extensions[v].loadSettings(settings[v:gsub("zeit_rc_", "")])
    end
    zeit_rcUI_edit.initSettings(settings)
    M.currentSettings = deepcopy(settings)
end

local function loadSettings(applyGameFirst)
    if applyGameFirst then
        if not loadRequested then
            core_settings_graphic.applyGraphicsState()
            loadRequested = true
        end
        return
    else
        loadRequested = false
    end

    M.historyPath = M.cachePath..M.currentProfile.."/"
    M.maxRollBack = #FS:findFiles(M.historyPath, "*", 0)
    M.currentRollBack = 1
    M.currentSettings = jsonReadFile(M.profilePath..M.currentProfile..".profile.json") or M.currentSettings

    _loadSettings(M.currentSettings)
    jsonWriteFile(M.profilePath.."main.json", {M.currentProfile}, false)

    log("I", "", "settings loaded")
end

local function addHistory(settings)
    historyCommitTimer = 1

    if historyJobRunning then return end
    historyJobRunning = true

    core_jobsystem.wrap(function(job)
        while historyCommitTimer > 0 do
            job.sleep(1)
        end

        local path = M.cachePath..M.currentProfile.."/"
        writeFile(path.."0", lpack.encode(settings))

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
        zeit_rcUI_edit.historySaveTime = 2
        historyJobRunning = false
    end, 0.1)()
end

local function undo()
    M.currentRollBack = math.min(M.currentRollBack+1, M.maxRollBack)
    local path = M.cachePath..M.currentProfile.."/"
    local data = readFile(path..tostring(M.currentRollBack))

    data = lpack.decode(data)
    if data then
        _loadSettings(data)
        zeit_rcUI_edit.initSettings(data)
    end
end

local function redo()
    M.currentRollBack = math.max(M.currentRollBack-1, 0)
    local path = M.cachePath..M.currentProfile.."/"
    local data = readFile(path..tostring(M.currentRollBack))

    data = lpack.decode(data)
    if data then
        _loadSettings(data)
        zeit_rcUI_edit.initSettings(data)
    end
end

local function saveSettings(settings)
    jsonWriteFile(M.profilePath..M.currentProfile..".profile.json", settings, true)
    log("I", "", "settings saved")
    loadSettings()
end

local function updateSettings(ext, data)
    local settings = jsonReadFile(M.profilePath..M.currentProfile..".profile.json")
    settings[ext] = data
    addHistory(deepcopy(settings))
    saveSettings(settings)
end

local function saveInfo(tbl, profile)
    jsonWriteFile(M.profilePath..(profile and profile or M.currentProfile)..".info.json", tbl, true)
end

local function onSettingsChanged(...)
    loadSettings(false)
end

local function checkForOldSettingsType()
    local dir = "/settings/zeit/rendercomponents/"
    local filesInFolder = FS:findFiles(dir, "save.*.json", 0)
    if #filesInFolder ~= 0 then
        guihooks.trigger('toastrMsg', {
            type = "warning",
            title = "Zeit's graphics settings utils",
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

        -- make backup
        local backupdir = "/settings/zeit/rendercomponents_backup"
        FS:directoryCreate(backupdir)
        for _,v in ipairs(filesInFolder) do
            FS:copyFile(v, backupdir)
        end

        -- convert to new profile
        local newSave = {}
        for _,v in ipairs(filesInFolder) do
            newSave[v:gsub(".+save.", ""):gsub(".json", "")] = jsonReadFile(v)
        end
        jsonWriteFile(dir.."generated.profile.json", newSave, true)
        for _,v in ipairs(filesInFolder) do
            FS:removeFile(v)
        end

        -- also add desc
        saveInfo({
            name = "Auto-Generated User Profile",
            desc = "This profile was converted from the user's old settings.\n(Automatically generated)",
            author = Steam.playerName ~= "" and Steam.playerName or "Unknown",
            date = os.date()
        })

        M.currentProfile = "generated"
    end
end

local function constructProfilePath(name)
    return M.profilePath..name..".profile.json"
end

local function saveCurrentProfile(autoEnterName)
    zeit_rcUI_saveOpenDialog.saveDialog(function(name) jsonWriteFile(constructProfilePath(name), deepcopy(M.currentSettings), true) end, autoEnterName and M.currentProfile or "")
end

local function loadProfile()
    zeit_rcUI_saveOpenDialog.loadDialog(function(name) M.currentProfile = name; loadSettings(true) end)
end

local function deleteProfile(newname)
    zeit_rcUI_saveOpenDialog.deleteDialog(newname)
end

local function reloadModules()
    for k,v in ipairs(modules) do
        if modules[k]:match("/") then
            local cleanName = v:gsub("/lua/ge/extensions/", ""):gsub(".lua", ""):gsub("_","__"):gsub("/","_")
            modules[k] = cleanName
        end
        extensions.reload(modules[k])
    end
end

local function getAllProfiles()
    return FS:findFiles("/settings/zeit/rendercomponents/", "*.profile.json", 0)
end

local function onPreRender(dt)
    if initStarted then
        checkForOldSettingsType()

        local mainSettings = jsonReadFile(M.profilePath.."main.json")
        if mainSettings and mainSettings[1] and FS:fileExists(M.profilePath..mainSettings[1]..".profile.json") then
            M.currentProfile = mainSettings[1]
        end

        extensions.reload("zeit_rcUI_saveOpenDialog")
        extensions.reload("zeit_rcUI_edit")
        extensions.reload("zeit_rcUI_profileManager")
        extensions.reload("zeit_rcUI_updateCheck")
        zeit_rcUI_updateCheck.getUpdateAvailable()
        reloadModules()
        loadSettings(true)

        initStarted = false
    end

    historyCommitTimer = math.max(historyCommitTimer - dt, 0)
    M.uiActive = worldReadyState == 2 and (zeit_rcUI_edit.showUI or zeit_rcUI_profileManager.showUI)
    if not scenetree.sunsky then return end
    if not M.uiActive then
        local shadowSettingsChanged = false
        if M.currentSettings.shadowsettings ~= nil then
            if M.currentSettings.shadowsettings.shadowDistance ~= nil then
                shadowSettingsChanged = tonumber(M.currentSettings.shadowsettings.shadowDistance) ~= tonumber(scenetree.sunsky.shadowDistance)
            end
        end

        if photoModeOpen ~= lastPhotoMode or shadowSettingsChanged and not (freeroam_bigMapMode and freeroam_bigMapMode.bigMapActive()) then
            loadSettings(true) -- load settings again because they might be changed
            lastPhotoMode = photoModeOpen
        end
    end
end

local function onExtensionLoaded()
    initStarted = true
end

local function onClientPostStartMission()
    initStarted = true
end

M.getAllProfiles = getAllProfiles
M.constructProfilePath = constructProfilePath
M.updateSettings = updateSettings
M.saveSettings = saveSettings
M.saveCurrentProfile = saveCurrentProfile
M.loadProfile = loadProfile
M.deleteProfile = deleteProfile
M.loadSettings = loadSettings
M.saveInfo = saveInfo
M.undo = undo
M.redo = redo

M.onPreRender = onPreRender
M.onClientPostStartMission = onClientPostStartMission
M.onExtensionLoaded = onExtensionLoaded
M.onSettingsChanged = onSettingsChanged

return M