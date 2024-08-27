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
    float3 intensity = float( dot( outputColor.rgb, float3( 0.2125, 0.7154, 0.0721 ) ) );

    outputColor.rgb = ( outputColor.rgb - 0.5f ) * contrast + 0.5f;
    outputColor.rgb = lerp( intensity, outputColor.rgb, saturation );

    return hdrEncode( outputColor );
}

PFXVertToPix mainV( PFXVert IN )
{
   return processPostFxVert(IN);
}
