-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local mapper = require("/lua/ge/extensions/zeit/rcTool/mapper")
local infoMapper = require("/lua/ge/extensions/zeit/rcTool/infoMapper")

local mime = require("mime")
local function exportProfileAsMod(name)
    local files = {
        zeit_rcMain.profilePath..name..".profile.json",
        zeit_rcMain.profilePath..name..".info.json",
        zeit_rcMain.profilePath..name..".preview.png",
        zeit_rcMain.profilePath..name..".preview.jpg"
    }

    if not FS:fileExists(files[1]) then
        log("E", "exportProfileAsMod", "Export failed: profile json doesn't exist or is empty.")
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
                log("E", "exportProfileAsMod", "Export failed: failed adding file: "..v)
                if zipSuccess then
                    zipSuccess = false
                end
            end
        end
    end
    zip:close()

    if not zipSuccess then
        FS:deleteFile("/temp"..archiveName)
        log("E", "exportProfileAsMod", "Export failed: Zip failed to create correctly.")
        return false
    else
        return FS:renameFile("/temp"..archiveName, archiveName), archiveName
    end
end

local function exportProfileToClipboard(name, format, exportInfo)
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
        log("E", "exportProfileToClipboard", "Export failed: profile doesn't exist or is empty.")
        return false
    end
    local jsonInfo = jsonReadFile(info) or {}
    if exportInfo and not next(jsonInfo) then
        log("W", "exportProfileToClipboard", "Export: attempted exporting profile info, but it doesn't exist or is empty.")
        exportInfo = false
    end

    local data = {name, mapper.compress(jsonProfile), exportInfo and infoMapper.compress(jsonInfo) or nil}
    local strData = bpackEncode and bpackEncode(data) or lpack.encodeBin(data)
    if strData == "" then
        log("E", "exportProfileToClipboard", "Export failed: encoding failed.")
        return false
    end
    strData = mime.b64(strData)

    local res = setClipboard(formats[format](strData))
    if not res then
        log("E", "exportProfileToClipboard", "Export failed: failed to set clipboard.")
    end
    return res
end

local function importProfileFromClipboard()
    local strData = getClipboard()
    if not strData then
        log("E", "importProfileFromClipboard", "Import failed: failed to get clipboard.")
        return false
    end

    local success, data = nil, nil
    if bpackDecode then
        success, data = pcall(bpackDecode, mime.unb64(strData))
    else
        success, data = pcall(lpack.decode, mime.unb64(strData))
    end
    data = data or {}
    if not success then
        log("E", "importProfileFromClipboard", "Import failed: failed to decode clipboard. Incomplete/incorrect?")
        return false
    else
        if type(data[1]) ~= "string" then
            log("E", "importProfileFromClipboard", "Import failed: unsupported/incorrect format. Incomplete?")
            return false
        end
        if type(data[2]) ~= "table" then
            log("E", "importProfileFromClipboard", "Import failed: unsupported/incorrect format. Incomplete?")
            return false
        end
        if data[3] and type(data[3]) ~= "table" then
            log("E", "importProfileFromClipboard", "Import failed: unsupported/incorrect format. Incomplete?")
            return false
        end

        success = jsonWriteFile(zeit_rcMain.profilePath..data[1]..".profile.json", mapper.decompress(data[2]), true)
        if not success then
            log("E", "importProfileFromClipboard", "Import failed: failed to write profile json.")
            return false
        end

        if data[3] then
            success = jsonWriteFile(zeit_rcMain.profilePath..data[1]..".info.json", infoMapper.decompress(data[3]), true)
            if not success then
                log("E", "importProfileFromClipboard", "Import failed: failed to write profile info json.")
                return false
            end
        end
    end
    return success
end

M.exportProfileAsMod = exportProfileAsMod
M.exportProfileToClipboard = exportProfileToClipboard
M.importProfileFromClipboard = importProfileFromClipboard

return M