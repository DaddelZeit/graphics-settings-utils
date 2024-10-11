// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#ifndef FILMGRAIN_H_HLSL
#define FILMGRAIN_H_HLSL

#include "postFx.h.hlsl"

uniform_sampler2D( backBuffer, 0 );

cbuffer perDraw
{
    uniform float Intensity = 0.5; // 0.5 [0.0 to 1.0] How visible the grain is. Higher is more visible.
    uniform float Variance = 0.4; // 0.4 [0.0 to 1.0] Controls the variance of the Gaussian noise. Lower values look smoother.
    uniform float Mean = 0.5; // 0.5 [0.0 to 1.0] Affects the brightness of the noise.
    uniform float SignalToNoiseRatio = 6.0; // 6.[0.0 to 16] Higher Signal-to-Noise Ratio values give less grain to brighter pixels. 0 disables this feature.

    uniform float accumTime;
    POSTFX_UNIFORMS
};

#include "postFx.hlsl"

#endif //FILMGRAIN_H_HLSL
