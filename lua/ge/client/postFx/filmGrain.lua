-- written by DaddelZeit
-- DO NOT USE WITHOUT PERMISSION

local FilmGrainPostFX = {}

local pfxFilmGrainShader = scenetree.findObject("PFX_FilmGrainShader")
if not pfxFilmGrainShader then
  pfxFilmGrainShader = createObject("ShaderData")
  pfxFilmGrainShader.DXVertexShaderFile    = "shaders/common/postFx/filmGrainP.hlsl"
  pfxFilmGrainShader.DXPixelShaderFile     = "shaders/common/postFx/filmGrainP.hlsl"
  pfxFilmGrainShader.pixVersion = 5.0
  pfxFilmGrainShader:registerObject("PFX_FilmGrainShader")
end

local FilmGrainFx = scenetree.findObject("FilmGrainFx")
if not FilmGrainFx then
  FilmGrainFx = createObject("PostEffect")
  FilmGrainFx.isEnabled = true
  FilmGrainFx.allowReflectPass = false
  FilmGrainFx:setField("renderTime", 0, "PFXAfterDiffuse")
  FilmGrainFx:setField("shader", 0, "PFX_FilmGrainShader")
  FilmGrainFx:setField("stateBlock", 0, "PFX_DefaultStateBlock")
  FilmGrainFx:setField("texture", 0, "$backBuffer")
  FilmGrainFx.renderPriority = 0.997

  FilmGrainFx:registerObject("FilmGrainFx")
end

FilmGrainPostFX.Intensity = 0.5
FilmGrainPostFX.Variance = 0.4
FilmGrainPostFX.Mean = 0.5
FilmGrainPostFX.SignalToNoiseRatio = 6

local function shaderConstsActual()
  if scenetree.FilmGrainFx then
    scenetree.FilmGrainFx:setShaderConst("$Intensity", FilmGrainPostFX.Intensity )
    scenetree.FilmGrainFx:setShaderConst("$Variance", FilmGrainPostFX.Variance )
    scenetree.FilmGrainFx:setShaderConst("$Mean", FilmGrainPostFX.Mean )
    scenetree.FilmGrainFx:setShaderConst("$SignalToNoiseRatio", FilmGrainPostFX.SignalToNoiseRatio )
  end
end

FilmGrainPostFX.setShaderConsts = function (Intensity, Variance, Mean, SignalToNoiseRatio)
  -- log('I','postfx','Calling setShaderConsts from FilmGrainFx')
  FilmGrainPostFX.Intensity = Intensity or FilmGrainPostFX.Intensity or 0.5
  FilmGrainPostFX.Variance = Variance or FilmGrainPostFX.Variance or 0.4
  FilmGrainPostFX.Mean = Mean or FilmGrainPostFX.Mean or 0.5
  FilmGrainPostFX.SignalToNoiseRatio = SignalToNoiseRatio or FilmGrainPostFX.SignalToNoiseRatio or 6

  shaderConstsActual()
end

FilmGrainPostFX.setEnabled = function (enabled)
  if scenetree.FilmGrainFx then
    if enabled then
      scenetree.FilmGrainFx:enable()
    else
      scenetree.FilmGrainFx:disable()
    end
  end
end

shaderConstsActual() -- Execute once

rawset(_G, "FilmGrainPostFX", FilmGrainPostFX)
return FilmGrainPostFX