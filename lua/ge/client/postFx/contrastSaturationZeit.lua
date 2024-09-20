-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local ContrastSaturationPostFX = {}

local pfxContrastSaturationShader = scenetree.findObject("PFX_ContrastSaturationShader")
if not pfxContrastSaturationShader then
  pfxContrastSaturationShader = createObject("ShaderData")
  pfxContrastSaturationShader.DXVertexShaderFile    = "shaders/common/postFx/contrastSaturationZeitP.hlsl"
  pfxContrastSaturationShader.DXPixelShaderFile     = "shaders/common/postFx/contrastSaturationZeitP.hlsl"
  pfxContrastSaturationShader.pixVersion = 5.0
  pfxContrastSaturationShader:registerObject("PFX_ContrastSaturationShader")
end

local ContrastSaturationFx = scenetree.findObject("ContrastSaturationFx")
if not ContrastSaturationFx then
  ContrastSaturationFx = createObject("PostEffect")
  ContrastSaturationFx.isEnabled = true
  ContrastSaturationFx.allowReflectPass = false
  ContrastSaturationFx:setField("renderTime", 0, "PFXAfterDiffuse")
  ContrastSaturationFx:setField("shader", 0, "PFX_ContrastSaturationShader")
  ContrastSaturationFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
  ContrastSaturationFx:setField("texture", 0, "$backBuffer")
  ContrastSaturationFx.renderPriority = 10

  ContrastSaturationFx:registerObject("ContrastSaturationFx")
end

ContrastSaturationPostFX.Contrast = 1
ContrastSaturationPostFX.Saturation = 1

local function shaderConstsActual()
  if scenetree.ContrastSaturationFx then
    scenetree.ContrastSaturationFx:setShaderConst("$contrast", ContrastSaturationPostFX.Contrast )
    scenetree.ContrastSaturationFx:setShaderConst("$saturation", ContrastSaturationPostFX.Saturation )
  end
end

ContrastSaturationPostFX.setShaderConsts = function (Contrast, Saturation)
  -- log('I','postfx','Calling setShaderConsts from ContrastSaturationFx')
  ContrastSaturationPostFX.Contrast = Contrast or ContrastSaturationPostFX.Contrast or 0
  ContrastSaturationPostFX.Saturation = Saturation or ContrastSaturationPostFX.Saturation or 1

  shaderConstsActual()
end

shaderConstsActual() -- Execute once

rawset(_G, "ContrastSaturationPostFX", ContrastSaturationPostFX)
return ContrastSaturationPostFX