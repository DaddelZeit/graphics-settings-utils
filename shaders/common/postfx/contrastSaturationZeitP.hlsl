// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#include "contrastSaturationZeit.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else
	#define mainP main
#endif

float4 mainP( PFXVertToPix IN ) : SV_Target
{
    float4 outputColor = hdrDecode( tex2D( backBuffer, IN.uv0 ) );
    outputColor.rgb = ( outputColor.rgb - 0.5f ) * contrast + 0.5f;

    float3 coefLuma = float3(0.212656, 0.715158, 0.072186);
	float luma = dot(coefLuma, outputColor);
	float maxColor = max(outputColor.r, max(outputColor.g, outputColor.b));
	float minColor = min(outputColor.r, min(outputColor.g, outputColor.b));

    float3 coeffVibrance = float3(vibranceBalance * vibrance);
	outputColor.rgb = lerp(luma, outputColor, 1.0 + (coeffVibrance * (1.0 - (sign(coeffVibrance) * (maxColor - minColor)))));

    float3 intensity = float( dot( outputColor.rgb, float3( 0.2125, 0.7154, 0.0721 ) ) );
    outputColor.rgb = lerp( intensity, outputColor.rgb, saturation );

    return hdrEncode( outputColor );
}

PFXVertToPix mainV( PFXVert IN )
{
   return processPostFxVert(IN);
}
