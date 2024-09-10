// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#ifndef SHARPENPOSTFX_H_HLSL
#define SHARPENPOSTFX_H_HLSL

#include "postFx.h.hlsl"

uniform_sampler2D( inputTex, 0 );

cbuffer perDraw
{
    uniform float sharpness;
    uniform float2 targetSize;

    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //SHARPENPOSTFX_H_HLSL
