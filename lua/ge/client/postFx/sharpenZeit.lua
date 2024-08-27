-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local SharpenPostFX = {}

local pfxSharpenStateBlock = scenetree.findObject("PFX_SharpenStateBlock")
if not pfxSharpenStateBlock then
  pfxSharpenStateBlock = createObject("GFXStateBlockData")
  pfxSharpenStateBlock.zDefined = true
  pfxSharpenStateBlock.zEnable = false
  pfxSharpenStateBlock.zWriteEnable = false

  pfxSharpenStateBlock.blendDefined = true;
  pfxSharpenStateBlock:setField("blendDest", 0, "GFXBlendOne")
  pfxSharpenStateBlock:setField("blendSrc", 0, "GFXBlendZero")

  pfxSharpenStateBlock.cullDefined = true;
  pfxSharpenStateBlock:setField("cullMode", 0, "GFXCullNone")

  pfxSharpenStateBlock.samplersDefined = true
  pfxSharpenStateBlock:setField("samplerStates", 0, "SamplerClampLinear")
  pfxSharpenStateBlock:setField("samplerStates", 1, "SamplerClampLinear")
  pfxSharpenStateBlock:setField("samplerStates", 2, "SamplerClampLinear")
  pfxSharpenStateBlock:setField("samplerStates", 3, "SamplerClampLinear")
  pfxSharpenStateBlock:registerObject("PFX_SharpenStateBlock")
end

local pfxSharpenShader = scenetree.findObject("PFX_SharpenShader")
if not pfxSharpenShader then
  pfxSharpenShader = createObject("ShaderData")
  pfxSharpenShader.DXVertexShaderFile    = "shaders/common/postFx/sharpenPostFXP.hlsl"
  pfxSharpenShader.DXPixelShaderFile     = "shaders/common/postFx/sharpenPostFXP.hlsl"
  pfxSharpenShader.pixVersion = 5.0
  pfxSharpenShader:registerObject("PFX_SharpenShader")
end

local SharpenFx = scenetree.findObject("SharpenFx")
if not SharpenFx then
  SharpenFx = createObject("PostEffect")
  SharpenFx.isEnabled = true
  SharpenFx.allowReflectPass = false
  SharpenFx:setField("renderTime", 0, "PFXBeforeBin")
  SharpenFx:setField("renderBin", 0, "EditorBin")

  SharpenFx:setField("shader", 0, "PFX_SharpenShader")
  SharpenFx:setField("stateBlock", 0, "PFX_SharpenStateBlock")
  SharpenFx:setField("texture", 0, "$backBuffer")
  SharpenFx.renderPriority = 0.996

  SharpenFx:registerObject("SharpenFx")
end

SharpenPostFX.Sharpness = 0

local function shaderConstsActual()
  if scenetree.SharpenFx then
    scenetree.SharpenFx:setShaderConst("$sharpness", SharpenPostFX.Sharpness )
  end
end

SharpenPostFX.setShaderConsts = function (Sharpness)
  -- log('I','postfx','Calling setShaderConsts from SharpenFx')
  SharpenPostFX.Sharpness = Sharpness or SharpenPostFX.Sharpness or 0

  shaderConstsActual()
end

SharpenPostFX.setEnabled = function (enabled)
  if scenetree.VignetteFx then
    if enabled then
      scenetree.SharpenFx:enable()
    else
      scenetree.SharpenFx:disable()
    end
  end
end

shaderConstsActual() -- Execute once

rawset(_G, "SharpenPostFX", SharpenPostFX)
return SharpenPostFX