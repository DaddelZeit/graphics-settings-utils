-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local im = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local profiles = {}
local keys = {}

local function getModNameFromPath(path)
    local modname = string.lower(path)
    modname = modname:gsub('dir:/', '') --should have been killed by now
    modname = modname:gsub('/mods/', '')
    modname = modname:gsub('repo/', '')
    modname = modname:gsub('unpacked/', '')
    modname = modname:gsub('/', '')
    modname = modname:gsub('.zip$', '')
    --log('I', 'getModNameFromPath', "getModNameFromPath path = "..path .."    name = "..dumps(modname) )
    return modname
end

local function sortAlphabetical(tbl, time)
    time = time or 0.025
    local a, b, c = {},{},{}
    for k,v in ipairs(tbl) do
        a[k] = ffi.string(profiles[v].info.name)
    end
    b = shallowcopy(a)
    table.sort(a)

    local index, id
    for k,v in ipairs(a) do
        index = arrayFindValueIndex(b, v)
        id = tbl[index]
        table.insert(c, id)
        if profiles[id].timeOffset == -1 then
            profiles[id].timeOffset = (k-1)*time
            profiles[id].smoothIn:set(0)
        end
    end

    for _,v in ipairs(keys) do
        if profiles[v].timeOffset ~= -1 and not arrayFindValueIndex(c, v) then
            profiles[v].timeOffset = -1
        end
    end
    return c
end
M.sortAlphabetical = sortAlphabetical

local function searchIn(profileKeys, queries)
    queries = ffi.string(queries)
    if queries == "" then return sortAlphabetical(profileKeys) end
    queries = split(queries, ' ')

    local a = {}
    for _,v in ipairs(profileKeys) do
        local profile = profiles[v]
        for k,query in ipairs(queries) do
            if query == "" then goto next end
            if ffi.string(profile.info.name):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) or ffi.string(profile.info.desc):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) or ffi.string(profile.info.author):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) then
                table.insert(a, v)
                goto next
            end

            for _,v2 in ipairs(profile.info.tags) do
                if ffi.string(v2):gsub("%s",""):lower():match(query:gsub("%s",""):lower()) then
                    table.insert(a, v)
                    goto next
                end
            end
        end

        ::next::
    end
    return sortAlphabetical(a)
end
M.searchIn = searchIn

local function searchTags(profileKeys, tag)
    local a = {}
    for k,v in ipairs(profileKeys) do
        local tags = {}
        for k2,v2 in ipairs(profiles[v].info.tags) do
            tags[k2] = ffi.string(v2)
        end

        if tableContains(tags, tag) then
            table.insert(a, v)
        end
    end
    return sortAlphabetical(a)
end
M.searchTags = searchTags

local previews = {}
local function prep(tbl, onFinish, ignoreCache)
    profiles = {}
    keys = {}

    core_jobsystem.wrap(function(job)
        local n = 0
        for _,v in ipairs(tbl) do
            local path = v:gsub(zeit_rcMain.profilePath, "")
            local internalName = split(path, ".")[1]
            local jsonInfo = zeit_rcMain.loadInfo(internalName)
            local info = {
                author = im.ArrayChar(256),
                date = im.ArrayChar(256),
                desc = im.ArrayChar(1024*16),
                name = im.ArrayChar(256),
                tags = {}
            }
            for k,v2 in ipairs(jsonInfo.tags or {}) do
                info.tags[k] = im.ArrayChar(128)
                ffi.copy(info.tags[k], v2)
            end
            ffi.copy(info.author, jsonInfo.author or "Unknown")
            ffi.copy(info.date, jsonInfo.date or "Unavailable")
            ffi.copy(info.desc, jsonInfo.desc or "No description available")
            ffi.copy(info.name, jsonInfo.name or internalName)

            local previewPath = zeit_rcMain.profilePath..internalName..".preview."
            previewPath = (FS:fileExists(previewPath.."png") and previewPath.."png") or (FS:fileExists(previewPath.."jpg") and previewPath.."jpg") or "/settings/zeit/rendercomponents/default.png"
            if ignoreCache or not previews[previewPath] then
                previews[previewPath] = imguiUtils.texObj(previewPath)
            end

            local overrides = FS:findOverrides(zeit_rcMain.profilePath..path)
            local filePath = overrides[1]

            local fileSource = 3
            if filePath:match("renderer_components_loadsave_zeit") then fileSource = 0 -- included
            elseif filePath:match("mods") then fileSource = 1 -- mod
            elseif filePath == FS:getUserPath() then fileSource = 2 -- userfolder
            end

            profiles[internalName] = {
                path = path,
                info = info,
                preview = previews[previewPath],
                fileSource = fileSource,
                smoothIn = newTemporalSigmoidSmoothing(20, 50, 50, 20, 0),
                timeOffset = -1, --n*0.075
                modPath = getModNameFromPath(FS:native2Virtual(filePath)),
                overwrite = #overrides > 1,
            }

            table.insert(keys, internalName)
            n = n + 1
            job.yield()
        end

        keys = sortAlphabetical(keys, 0.1)
        onFinish(profiles, keys)
    end, 0.005)()
end
M.prep = prep

return M