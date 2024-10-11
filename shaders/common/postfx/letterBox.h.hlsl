// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#ifndef LETTERBOX_H_HLSL
#define LETTERBOX_H_HLSL

#include "postFx.h.hlsl"

uniform_sampler2D( backBuffer, 0 );

cbuffer perDraw
{
    uniform float uvY1 = 0;
    uniform float uvY2 = 1;
    uniform float uvX1 = 0;
    uniform float uvX2 = 1;
    uniform float4 Color;

    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //LETTERBOX_H_HLSL
