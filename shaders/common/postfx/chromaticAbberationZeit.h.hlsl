#ifndef CHROMATIC_ABBERATION_ZEIT_H_HLSL
#define CHROMATIC_ABBERATION_ZEIT_H_HLSL

#include "postFx.h.hlsl"
#include "shaders/common/hlsl.h"

uniform_sampler2D( backBuffer, 0 );

cbuffer perDraw
{
    uniform float3 colorDistort;
    uniform float distCoeff;
    uniform float cubeDistort;

    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //CHROMATIC_ABBERATION_ZEIT_H_HLSL
