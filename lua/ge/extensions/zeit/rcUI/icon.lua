-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local C = {}
C.__index = C

local im = ui_imgui
local widgets = require("zeit/rcUI/editWidgets")
function C:init(texPath, xSize, ySize)
    self.xTileSize = 1/xSize
    self.yTileSize = 1/ySize

    self.texHandler = im.ImTextureHandler(texPath)
    self.texId = self.texHandler:getID()
end

function C:get(x, y)
    return {
        im.ImVec2((x-1)*self.xTileSize, (y-1)*self.yTileSize),
        im.ImVec2(x*self.xTileSize, y*self.yTileSize)
    }
end

function C:image(size, x, y, ImVec4_tint_col, ImVec4_border_col)
    im.Image(self.texId, size, im.ImVec2((x-1)*self.xTileSize, (y-1)*self.yTileSize), im.ImVec2(x*self.xTileSize, y*self.yTileSize), ImVec4_tint_col, ImVec4_border_col)
end

function C:imageButton(size, x, y, ImVec4_bg_col, ImVec4_tint_col)
    return widgets.imageButton("##"..os.date(), self.texId, size, im.ImVec2((x-1)*self.xTileSize, (y-1)*self.yTileSize), im.ImVec2(x*self.xTileSize, y*self.yTileSize), ImVec4_bg_col, ImVec4_tint_col)
end

return {
    create = function(...)
        local o = {}
        setmetatable(o, C)
        o:init(...)
        return o
    end
}