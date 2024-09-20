-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}
M.currentSettings = {
    autofocus={
        isEnabled=false
    },
    contrastsaturation={
        contrast=1,
        saturation=1
    },
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
    },
    shadowsettings={
        attenuationRatio="0 1 1",
        cookie="",
        fadeStartDistance="1000",
        logWeight="0.980000019",
        numSplits="4",
        overDarkFactor="40000 8000 5000 650",
        shadowDistance="1600",
        shadowSoftness="0.200000003",
        shadowType="PSSM",
        texSize="1024"
    },
    ssao={
      contrast=2,
      radius=1.5,
      samples=16
    },
    uifps={
      fps=30
    }
}
local modules = FS:findFiles("/lua/ge/extensions/zeit/rc", "*.lua", 1)
M.profilePath = "/settings/zeit/rendercomponents/"
M.currentProfile = "vanilla"
local lastPhotoMode = false
local initStarted = false

local function loadSettings()
    local settings = jsonReadFile(M.profilePath..M.currentProfile..".profile.json")
    if not settings then settings = M.currentSettings end
    for _,v in ipairs(modules) do
        if settings[v:gsub("zeit_rc_", "")] then
            extensions[v].loadSettings(settings[v:gsub("zeit_rc_", "")])
        end
    end
    jsonWriteFile(M.profilePath.."main.json", {M.currentProfile}, false)
    M.currentSettings = deepcopy(settings)
    zeit_rcUI.initSettings()
    log("I", "", "settings loaded")
end

local function updateSettings(ext, data)
    local settings = jsonReadFile(M.profilePath..M.currentProfile..".profile.json")
    settings[ext] = data
    jsonWriteFile(M.profilePath..M.currentProfile..".profile.json", settings, true)
    log("I", "", "settings saved")
    loadSettings()
end

local function saveInfo(tbl, profile)
    jsonWriteFile(M.profilePath..(profile and profile or M.currentProfile)..".info.json", tbl, true)
end

local function checkForOldSettingsType()
    local dir = "/settings/zeit/rendercomponents/"
    local filesInFolder = FS:findFiles(dir, "save.*.json", 0)
    if #filesInFolder ~= 0 then
        guihooks.trigger('toastrMsg', {
            type = "warning",
            title = "Zeit's graphics settings utils",
            msg = "Old settings structure detected. A backup was created and the files were updated. Hover here or restart your game to make this message disappear.",
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
    zeit_rcSaveOpenDialog.saveDialog(function(name) jsonWriteFile(constructProfilePath(name), deepcopy(M.currentSettings), true) end, autoEnterName and M.currentProfile or "")
end

local function loadProfile()
    zeit_rcSaveOpenDialog.loadDialog(function(name) M.currentProfile = name loadSettings() end)
end

local function deleteProfile(newname)
    zeit_rcSaveOpenDialog.deleteDialog(newname)
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

        extensions.reload("zeit_rcSaveOpenDialog")
        extensions.reload("zeit_rcUI")
        extensions.reload("zeit_rcProfileManager")
        extensions.reload("zeit_rcUpdateCheck")
        zeit_rcUpdateCheck.getUpdateAvailable()
        reloadModules()
        loadSettings()

        initStarted = false
    end

    M.uiActive = worldReadyState == 2 and (zeit_rcUI.showUI or zeit_rcProfileManager.showUI)
    if not scenetree.sunsky then return end
    if not M.uiActive then
        if tonumber(M.currentSettings.shadowsettings.shadowDistance) ~= tonumber(scenetree.sunsky.shadowDistance) then
            loadSettings() -- load settings again because they might be changed
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
M.onPreRender = onPreRender
M.onClientPostStartMission = onClientPostStartMission
M.onExtensionLoaded = onExtensionLoaded
M.updateSettings = updateSettings
M.saveCurrentProfile = saveCurrentProfile
M.loadProfile = loadProfile
M.deleteProfile = deleteProfile
M.loadSettings = loadSettings
M.saveInfo = saveInfo

return M