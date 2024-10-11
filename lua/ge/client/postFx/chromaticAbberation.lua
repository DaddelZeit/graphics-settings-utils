-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local ChromaticAbberationPostFX = {}

local pfxDefaultChromaticAbberationStateBlock = scenetree.findObject("PFX_DefaultChromaticAbberationStateBlock")
if not pfxDefaultChromaticAbberationStateBlock then
  pfxDefaultChromaticAbberationStateBlock = createObject("GFXStateBlockData")
  pfxDefaultChromaticAbberationStateBlock.zDefined = true;
  pfxDefaultChromaticAbberationStateBlock.zEnable = false;
  pfxDefaultChromaticAbberationStateBlock.zWriteEnable = false;
  pfxDefaultChromaticAbberationStateBlock.samplersDefined = false;
  pfxDefaultChromaticAbberationStateBlock:setField("samplerStates", 0, "SamplerClampPoint")
  pfxDefaultChromaticAbberationStateBlock:registerObject("PFX_DefaultChromaticAbberationStateBlock")
end

local pfxChromaticAbberationShader = scenetree.findObject("PFX_ChromaticAbberationShader")
if not pfxChromaticAbberationShader then
  pfxChromaticAbberationShader = createObject("ShaderData")
  pfxChromaticAbberationShader.DXVertexShaderFile = "shaders/common/postFx/ChromaticAbberationZeitP.hlsl"
  pfxChromaticAbberationShader.DXPixelShaderFile  = "shaders/common/postFx/ChromaticAbberationZeitP.hlsl"
  pfxChromaticAbberationShader.pixVersion = 5.0;
  pfxChromaticAbberationShader:registerObject("PFX_ChromaticAbberationShader")
end

local ChromaticAbberationFX = scenetree.findObject("ChromaticAbberationFX")
if not ChromaticAbberationFX then
  ChromaticAbberationFX = createObject("PostEffect")
  ChromaticAbberationFX:setField("renderTime", 0, "PFXAfterDiffuse")
  ChromaticAbberationFX.renderPriority = 0.9
  ChromaticAbberationFX.isEnabled = false
  ChromaticAbberationFX.allowReflectPass = false
  ChromaticAbberationFX:setField("shader", 0, "PFX_ChromaticAbberationShader")
  ChromaticAbberationFX:setField("stateBlock", 0, "PFX_DefaultChromaticAbberationStateBlock")
  ChromaticAbberationFX:setField("texture", 0, "$backBuffer")
  ChromaticAbberationFX:setField("target", 0, "$backBuffer")
  ChromaticAbberationFX:registerObject("ChromaticAbberationFX")
end

ChromaticAbberationPostFX.DistCoefficient = 0
ChromaticAbberationPostFX.CubeDistortionFactor = 0
ChromaticAbberationPostFX.ColorDistortionFactor = {0,0,0}

local function shaderConstsActual()
  if scenetree.ChromaticAbberationFX then
    scenetree.ChromaticAbberationFX:setShaderConst("$distCoeff", ChromaticAbberationPostFX.DistCoefficient );
    scenetree.ChromaticAbberationFX:setShaderConst("$cubeDistort", ChromaticAbberationPostFX.CubeDistortionFactor );
    scenetree.ChromaticAbberationFX:setShaderConst("$colorDistort", string.format('%f %f %f', ChromaticAbberationPostFX.ColorDistortionFactor[1], ChromaticAbberationPostFX.ColorDistortionFactor[2], ChromaticAbberationPostFX.ColorDistortionFactor[3]) );
  end
end

ChromaticAbberationPostFX.setShaderConsts = function (DistCoefficient, CubeDistortionFactor, ColorDistortionFactor)
  --zeit_rcMain.log('I','postfx','Calling setShaderConsts from ChromaticAbberationFX')
  ChromaticAbberationPostFX.DistCoefficient = DistCoefficient or ChromaticAbberationPostFX.DistCoefficient or 0
  ChromaticAbberationPostFX.CubeDistortionFactor = CubeDistortionFactor or ChromaticAbberationPostFX.CubeDistortionFactor or 0
  ChromaticAbberationPostFX.ColorDistortionFactor = ColorDistortionFactor or ChromaticAbberationPostFX.ColorDistortionFactor or {0,0,0}

  shaderConstsActual()
end

ChromaticAbberationPostFX.setEnabled = function (enabled)
  if scenetree.ChromaticAbberationFX then
    if enabled then
      scenetree.ChromaticAbberationFX:enable()
    else
      scenetree.ChromaticAbberationFX:disable()
    end
  end
end

shaderConstsActual() -- Execute once

rawset(_G, "ChromaticAbberationPostFX", ChromaticAbberationPostFX)
return ChromaticAbberationPostFX