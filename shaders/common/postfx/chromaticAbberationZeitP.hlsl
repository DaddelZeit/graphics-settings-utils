// Based on 'Cubic Lens Distortion HLSL Shader' by Francois Tarlier
// www.francois-tarlier.com/blog/index.php/2009/11/cubic-lens-distortion-shader

#include "chromaticAbberationZeit.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else
	#define mainP main
#endif

float4 mainP( PFXVertToPix IN ) : SV_TARGET0
{
    float2 tex = IN.uv0;

    float f = 0;
    float r2 = (tex.x - 0.5) * (tex.x - 0.5) + (tex.y - 0.5) * (tex.y - 0.5);

    // Only compute the cubic distortion if necessary.
    if ( cubeDistort == 0.0 ) {
        f = 1 + r2 * distCoeff;
    } else {
        f = 1 + r2 * (distCoeff + cubeDistort * sqrt(r2));
    }

    // Distort each color channel seperately to get a chromatic distortion effect.
    float4 outColor;

    float3 distort = f.xxx + colorDistort;

    for ( int i=0; i < 3; i++ ) {
        float x = distort[i] * (tex.x - 0.5) + 0.5;
        float y = distort[i] * (tex.y - 0.5) + 0.5;
        outColor[i] = tex2D(backBuffer, float2(
            x > 1 ? 1-(x%1) : abs(x),
            y > 1 ? 1-(y%1) : abs(y)
        ))[i];
    }

    return float4( outColor.rgb, 1 );
}

PFXVertToPix mainV( PFXVert IN )
{
   return processPostFxVert(IN);
}
