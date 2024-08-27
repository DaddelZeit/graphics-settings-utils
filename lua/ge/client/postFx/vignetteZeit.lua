-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local VignettePostFX = {}

local pfxVignetteStateBlock = scenetree.findObject("PFX_VignetteStateBlock")
if not pfxVignetteStateBlock then
  pfxVignetteStateBlock = createObject("GFXStateBlockData")
  pfxVignetteStateBlock.zDefined = true
  pfxVignetteStateBlock.zEnable = false
  pfxVignetteStateBlock.zWriteEnable = false
  pfxVignetteStateBlock.samplersDefined = true
  pfxVignetteStateBlock:setField("samplerStates", 0, "SamplerClampLinear")
  pfxVignetteStateBlock:registerObject("PFX_VignetteStateBlock")
end

local pfxVignetteShader = scenetree.findObject("PFX_VignetteShader")
if not pfxVignetteShader then
  pfxVignetteShader = createObject("ShaderData")
  pfxVignetteShader.DXVertexShaderFile    = "shaders/common/postFx/vignettePostFXP.hlsl"
  pfxVignetteShader.DXPixelShaderFile     = "shaders/common/postFx/vignettePostFXP.hlsl"
  pfxVignetteShader.pixVersion = 5.0
  pfxVignetteShader:registerObject("PFX_VignetteShader")
end

local VignetteFx = scenetree.findObject("VignetteFx")
if not VignetteFx then
  VignetteFx = createObject("PostEffect")
  VignetteFx.isEnabled = true
  VignetteFx.allowReflectPass = false
  VignetteFx:setField("renderTime", 0, "PFXBeforeBin")
  VignetteFx:setField("renderBin", 0, "EditorBin")

  VignetteFx:setField("shader", 0, "PFX_VignetteShader")
  VignetteFx:setField("stateBlock", 0, "PFX_VignetteStateBlock")
  VignetteFx:setField("texture", 0, "$backBuffer")
  VignetteFx.renderPriority = 0.998

  VignetteFx:registerObject("VignetteFx")
end

VignettePostFX.Vmax = 0
VignettePostFX.Vmin = 0
VignettePostFX.Color = {0, 0, 0}

local function shaderConstsActual()
  if scenetree.VignetteFx then
    scenetree.VignetteFx:setShaderConst("$Vmax", VignettePostFX.Vmax )
    scenetree.VignetteFx:setShaderConst("$Vmin", VignettePostFX.Vmin )
    scenetree.VignetteFx:setShaderConst("$Color", string.format("%f %f %f 1", VignettePostFX.Color[1], VignettePostFX.Color[2], VignettePostFX.Color[3]) )
  end
end

VignettePostFX.setShaderConsts = function (Vmax, Vmin, Color)
  -- log('I','postfx','Calling setShaderConsts from VignetteFx')
  VignettePostFX.Vmax = Vmax or VignettePostFX.Vmax or 0
  VignettePostFX.Vmin = Vmin or VignettePostFX.Vmin or 0
  VignettePostFX.Color = Color or VignettePostFX.Color or {0, 0, 0}

  shaderConstsActual()
end

VignettePostFX.setEnabled = function (enabled)
  if scenetree.VignetteFx then
    if enabled then
      scenetree.VignetteFx:enable()
    else
      scenetree.VignetteFx:disable()
    end
  end
end

shaderConstsActual() -- Execute once

rawset(_G, "VignettePostFX", VignettePostFX)
return VignettePostFX