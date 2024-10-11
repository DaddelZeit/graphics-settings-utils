-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local M = {}

local im = ui_imgui

local style = im.ImGuiStyle()
local size_t = ffi.sizeof("ImGuiStyle")
ffi.copy(style, im.GetStyle(), size_t)
style.WindowRounding = 0
style.ScrollbarRounding = 0
style.ChildRounding = 0
style.WindowTitleAlign = im.ImVec2(0.5,0)
style.WindowMenuButtonPosition = im.Dir_Right
style.ColorButtonPosition = im.Dir_Left
style.AntiAliasedFill = true
style.AntiAliasedLines = true
style.AntiAliasedLinesUseTex = true
style.Alpha = 1
style.Colors[im.Col_WindowBg] = im.ImVec4(36/255, 42/255, 46/255, 1) --rgb(36, 42, 46)
style.Colors[im.Col_MenuBarBg] = im.ImVec4(74/255, 78/255, 81/255, 1) --rgb(74, 78, 81)
style.Colors[im.Col_TitleBg] = im.ImVec4(94/255, 98/255, 101/255, 1) --rgb(94, 98, 101)
style.Colors[im.Col_TitleBgActive] = im.ImVec4(109/255, 115/255, 119/255, 1) --rgb(109, 115, 119)
style.Colors[im.Col_ChildBg] = im.ImVec4(29/255, 30/255, 31/255, 1) --#1d1e1f
style.Colors[im.Col_PopupBg] = im.ImVec4(29/255, 30/255, 31/255, 1) --#1d1e1f
style.Colors[im.Col_Border] = im.ImVec4(74/255, 78/255, 81/255, 1) --#1d1e1f
style.Colors[im.Col_Text] = im.ImVec4(252/255, 248/255, 244/255, 1) --#fcf8f4
style.Colors[im.Col_TextSelectedBg] = im.ImVec4(6/255, 9/255, 200/255, 1) --#065ec8
style.Colors[im.Col_Button] = im.ImVec4(124/255, 181/255, 220/255, 0.5) --rgb(124, 181, 220)
style.Colors[im.Col_ButtonHovered] = im.ImVec4(181/255, 181/255, 181/255, 0.7) --rgb(181, 181, 220)
style.Colors[im.Col_ButtonActive] = im.ImVec4(181/255, 181/255, 181/255, 0.8) --rgb(181, 181, 220)
style.Colors[im.Col_SliderGrab] = im.ImVec4(124/255, 181/255, 220/255, 0.8) --rgb(124, 181, 220)
style.Colors[im.Col_SliderGrabActive] = im.ImVec4(124/255, 181/255, 220/255, 0.8) --rgb(124, 181, 220)
style.Colors[im.Col_CheckMark] = im.ImVec4(124/255, 181/255, 220/255, 0.8) --rgb(124, 181, 220)
style.Colors[im.Col_Separator] = im.ImVec4(71/255, 76/255, 77/255, 1) --rgb(71, 76, 77)
style.Colors[im.Col_ScrollbarBg] = im.ImVec4(36/255, 42/255, 46/255, 1) --rgb(36, 42, 46)
style.Colors[im.Col_ScrollbarGrab] = im.ImVec4(86/255, 90/255, 93/255, 1) --#565a5d
style.Colors[im.Col_SliderGrab] = im.ImVec4(86/255, 90/255, 93/255, 1) --#565a5d
style.Colors[im.Col_FrameBg] = im.ImVec4(44/255, 46/255, 47/255, 1) --#2c2e2f

local origStyle = im.ImGuiStyle()
M.push = function()
    ffi.copy(origStyle, im.GetStyle(), size_t)
    ffi.copy(im.GetStyle(), style, size_t)
end
M.pop = function()
    ffi.copy(im.GetStyle(), origStyle, size_t)
end

setmetatable(M, {
    __index = function(self, index)
        local success, res = pcall(function() return style[index] end)
        return success and res or nil
    end,
    __metatable = false
})
return M