#ifndef CONTRASTSATURATIONZEIT_H_HLSL
#define CONTRASTSATURATIONZEIT_H_HLSL

#include "postFx.h.hlsl"

uniform_sampler2D( backBuffer, 0 );

cbuffer perDraw
{
    uniform float contrast;
    uniform float saturation;
    uniform float vibrance;
    uniform float3 vibranceBalance;

    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //CONTRASTSATURATIONZEIT_H_HLSL
