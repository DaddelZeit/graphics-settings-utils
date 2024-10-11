// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#ifndef VIGNETTEPOSTFX_H_HLSL
#define VIGNETTEPOSTFX_H_HLSL

#include "postFx.h.hlsl"

uniform_sampler2D( backBuffer, 0 );

cbuffer perDraw
{
    uniform float Vmax;
    uniform float Vmin;
    uniform float4 Color;

    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //VIGNETTEPOSTFX_H_HLSL
