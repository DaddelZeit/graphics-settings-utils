-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local LetterboxPostFX = {}

local pfxLetterboxStateBlock = scenetree.findObject("PFX_LetterboxStateBlock")
if not pfxLetterboxStateBlock then
  pfxLetterboxStateBlock = createObject("GFXStateBlockData")
  pfxLetterboxStateBlock.zDefined = true
  pfxLetterboxStateBlock.zEnable = false
  pfxLetterboxStateBlock.zWriteEnable = false
  pfxLetterboxStateBlock.samplersDefined = true
  pfxLetterboxStateBlock:setField("samplerStates", 0, "SamplerClampLinear")
  pfxLetterboxStateBlock:registerObject("PFX_LetterboxStateBlock")
end

local pfxLetterboxShader = scenetree.findObject("PFX_LetterboxShader")
if not pfxLetterboxShader then
  pfxLetterboxShader = createObject("ShaderData")
  pfxLetterboxShader.DXVertexShaderFile    = "shaders/common/postFx/LetterboxP.hlsl"
  pfxLetterboxShader.DXPixelShaderFile     = "shaders/common/postFx/LetterboxP.hlsl"
  pfxLetterboxShader.pixVersion = 5.0
  pfxLetterboxShader:registerObject("PFX_LetterboxShader")
end

local LetterboxFx = scenetree.findObject("LetterboxFx")
if not LetterboxFx then
  LetterboxFx = createObject("PostEffect")
  LetterboxFx.isEnabled = false
  LetterboxFx.allowReflectPass = false
  LetterboxFx:setField("renderTime", 0, "PFXAfterDiffuse")
  LetterboxFx:setField("shader", 0, "PFX_LetterboxShader")
  LetterboxFx:setField("stateBlock", 0, "PFX_LetterboxStateBlock")
  LetterboxFx:setField("texture", 0, "$backBuffer")
  LetterboxFx.renderPriority = 0.999

  LetterboxFx:registerObject("LetterboxFx")
end

LetterboxPostFX.uvY1 = 0
LetterboxPostFX.uvY2 = 1
LetterboxPostFX.uvX1 = 0
LetterboxPostFX.uvX2 = 1
LetterboxPostFX.Color = {0, 0, 0}

local function shaderConstsActual()
  if scenetree.LetterboxFx then
    scenetree.LetterboxFx:setShaderConst("$uvY1", LetterboxPostFX.uvY1 )
    scenetree.LetterboxFx:setShaderConst("$uvY2", LetterboxPostFX.uvY2 )
    scenetree.LetterboxFx:setShaderConst("$uvX1", LetterboxPostFX.uvX1 )
    scenetree.LetterboxFx:setShaderConst("$uvX2", LetterboxPostFX.uvX2 )
    scenetree.LetterboxFx:setShaderConst("$Color", string.format("%f %f %f 1", LetterboxPostFX.Color[1], LetterboxPostFX.Color[2], LetterboxPostFX.Color[3]) )
  end
end

LetterboxPostFX.setShaderConsts = function (uvY1, uvY2, uvX1, uvX2, Color)
  --zeit_rcMain.log('I','postfx','Calling setShaderConsts from LetterboxFx')
  LetterboxPostFX.uvY1 = uvY1 or LetterboxPostFX.uvY1 or 0
  LetterboxPostFX.uvY2 = uvY2 or LetterboxPostFX.uvY2 or 0
  LetterboxPostFX.uvX1 = uvX1 or LetterboxPostFX.uvX1 or 0
  LetterboxPostFX.uvX2 = uvX2 or LetterboxPostFX.uvX2 or 0
  LetterboxPostFX.Color = Color or LetterboxPostFX.Color or {0, 0, 0}

  shaderConstsActual()
end

LetterboxPostFX.setEnabled = function (enabled)
  if scenetree.LetterboxFx then
    if enabled then
      scenetree.LetterboxFx:enable()
    else
      scenetree.LetterboxFx:disable()
    end
  end
end

shaderConstsActual() -- Execute once

rawset(_G, "LetterboxPostFX", LetterboxPostFX)
return LetterboxPostFX