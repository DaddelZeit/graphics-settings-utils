-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settingsManager = require("/lua/ge/extensions/zeit/rcTool/settingsManager")
local lpackDupe = require("/lua/ge/extensions/zeit/rcTool/lpackDupe")
local im = ui_imgui

local mapper = require("/lua/ge/extensions/zeit/rcTool/mapper")
local infoMapper = require("/lua/ge/extensions/zeit/rcTool/infoMapper")
local lualzw = require("/lua/ge/extensions/zeit/rcTool/lualzw")

M.exportInfo = im.BoolPtr(settingsManager.get("export_info"))
M.exportFormat = settingsManager.get("export_option")
M.exportFormats = {
    "Default",
    "BeamNG Forums",
    "Discord"
}

local function formatSelector()
    im.Text("Format:")
    im.SameLine()
    if im.BeginCombo("##ExportFormatSelector", M.exportFormats[M.exportFormat]) then
        for k,v in pairs(M.exportFormats) do
            if im.Selectable1(v, k == M.exportFormat) then
                M.exportFormat = k
                settingsManager.set("export_option", k)
            end
        end
        im.EndCombo()
    end
end

local function infoCheckbox()
    im.Checkbox("Export Info", M.exportInfo)
    settingsManager.set("export_info", M.exportInfo[0])
end

local mime = require("mime")
local function exportProfileAsMod(name)
    local files = {
        zeit_rcMain.profilePath..name..".profile.json",
        zeit_rcMain.profilePath..name..".info.json",
        zeit_rcMain.profilePath..name..".preview.png",
        zeit_rcMain.profilePath..name..".preview.jpg"
    }

    if not FS:fileExists(files[1]) then
       zeit_rcMain.log("E", "exportProfileAsMod", "Export failed: profile json doesn't exist or is empty.")
        return false
    end

    local archiveName = string.format("/mods/%s_rc_export_%d.zip", name, os.time())
    local zip = ZipArchive()
    local zipSuccess = true
    zip:openArchiveName("/temp"..archiveName, 'w')
    for k,v in ipairs(files) do
        if FS:fileExists(v) then
            local success = zip:addFile(v, v:sub(2))
            if not success then
               zeit_rcMain.log("E", "exportProfileAsMod", "Export failed: failed adding file: "..v)
                if zipSuccess then
                    zipSuccess = false
                end
            end
        end
    end
    zip:close()

    if not zipSuccess then
        FS:deleteFile("/temp"..archiveName)
       zeit_rcMain.log("E", "exportProfileAsMod", "Export failed: Zip failed to create correctly.")
        return false
    else
        return FS:renameFile("/temp"..archiveName, archiveName), archiveName
    end
end

local function exportProfileToClipboard(name, format, exportInfo)
    format = format or M.exportFormat
    exportInfo = exportInfo or M.exportInfo[0]
    local formats = {
        function(s)
            return s
        end,
        function(s)
            return string.format("[CODE]%s[/CODE]", s)
        end,
        function(s)
            return string.format("```%s```", s)
        end
    }

    local file = zeit_rcMain.profilePath..name..".profile.json"
    local info = zeit_rcMain.profilePath..name..".info.json"

    local jsonProfile = jsonReadFile(file) or {}
    if not next(jsonProfile) then
        zeit_rcMain.log("E", "exportProfileToClipboard", "Export failed: profile doesn't exist or is empty.")
        return false
    end
    local jsonInfo = jsonReadFile(info) or {}
    if exportInfo and not next(jsonInfo) then
        zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: attempted exporting profile info, but it doesn't exist or is empty.")
        exportInfo = false
    end

    local data = {name, mapper.compress(jsonProfile), exportInfo and infoMapper.compress(jsonInfo) or nil}

    local success, strData = nil, nil

    local tryLpack = not bpackEncode
    if bpackEncode then
        success, strData = pcall(bpackEncode, data)
        if not success then
            zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: bpack error: "..data)
            zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: see above for more info.")
            zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: attempting lpack encode...")
            tryLpack = true
        end
    else
        zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: bpack unavailable. Incompatible game version?")
    end

    if tryLpack then
        zeit_rcMain.log("W", "importProfileFromClipboard", "Export warning: attempting lpack encode...")
        success, strData = pcall(lpackDupe.encode, data)

        if not success then
            zeit_rcMain.log("E", "importProfileFromClipboard", "Export failed: lpack encode failed.")
            return false
        end
    end

    if not success or not strData then
        zeit_rcMain.log("E", "exportProfileToClipboard", "Export failed: encoding failed.")
        return false
    end

    local compressRes, compressErr = lualzw.compress(strData)
    if not compressRes then
        zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: failed to compress clipboard. Error: "..compressErr)
        zeit_rcMain.log("W", "exportProfileToClipboard", "Export warning: continuing without decompress...")
        compressRes = strData
    end

    strData = mime.b64(compressRes)
    if not strData or strData == "" then
        zeit_rcMain.log("E", "exportProfileToClipboard", "Export failed: b64 encoding failed.")
        return false
    end

    local res = setClipboard(formats[format or 1](strData))
    if not res then
        zeit_rcMain.log("E", "exportProfileToClipboard", "Export failed: failed to set clipboard.")
    end
    return res
end

local function importProfileFromClipboard()
    local strData = getClipboard()
    if not strData then
        zeit_rcMain.log("E", "importProfileFromClipboard", "Import failed: failed to get clipboard.")
        return false
    end

    local success, data = nil, nil
    local unb64 = mime.unb64(strData)
    local decompressRes, decompressErr = lualzw.decompress(unb64)
    if not decompressRes then
        zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: failed to decompress clipboard. Incomplete/incorrect? Error: "..decompressErr)
        zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: attempting decode without decompress...")
        decompressRes = unb64
    end

    local tryLpack = not bpackDecode
    if bpackDecode then
        success, data = pcall(bpackDecode, decompressRes)
        if not success or type(data) ~= "table" then
            zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: bpack error: "..data)
            zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: see above for more info.")
            tryLpack = true
        end
    else
        zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: bpack unavailable. Incompatible game version?")
    end

    if tryLpack then
        zeit_rcMain.log("W", "importProfileFromClipboard", "Import warning: attempting lpack decode...")
        success, data = pcall(lpackDupe.decode, decompressRes)

        if not success then
            zeit_rcMain.log("E", "importProfileFromClipboard", "Import failed: lpack decode failed. Incompatible game version?")
            return false
        end
    end

    data = data or {}

    if type(data) ~= "table" or type(data[1]) ~= "string" or type(data[2]) ~= "table" then
        zeit_rcMain.log("E", "importProfileFromClipboard", "Import failed: unsupported/incorrect format. Incomplete?")
        return false
    end

    local name, i = zeit_rcMain.getUniqueName(data[1])
    success = zeit_rcMain.saveProfile(name, mapper.decompress(data[2]))
    if not success then
        zeit_rcMain.log("E", "importProfileFromClipboard", "Import failed: failed to write profile json.")
        return false
    end

    if data[3] then
        local info = infoMapper.decompress(data[3])
        if i ~= 0 then
            info.name = string.format("%s (%d)", info.name, i)
        end
        success = zeit_rcMain.saveInfo(info, name)
        if not success then
            zeit_rcMain.log("E", "importProfileFromClipboard", "Import failed: failed to write profile info json.")
            return false
        end
    end

    return success
end

M.infoCheckbox = infoCheckbox
M.formatSelector = formatSelector
M.exportProfileAsMod = exportProfileAsMod
M.exportProfileToClipboard = exportProfileToClipboard
M.importProfileFromClipboard = importProfileFromClipboard

return M