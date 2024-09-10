-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local settings = {
    "author",
    "date",
    "desc",
    "name",
    "tags",
}

local function compress(data)
    local newdata = {}
    for k,v in pairs(data) do
        local numkey = arrayFindValueIndex(settings, k)
        if numkey then
            newdata[numkey] = v
        else
            newdata[k] = v
        end
    end
    return newdata
end

local function decompress(data)
    local newdata = {}
    for k,v in pairs(data) do
        newdata[settings[k]] = v
    end
    return newdata
end

M.compress = compress
M.decompress = decompress

return M