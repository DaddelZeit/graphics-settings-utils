// written by DaddelZeit
// DO NOT USE WITHOUT PERMISSION

#include "letterBox.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else
	#define mainP main
#endif

float4 mainP( PFXVertToPix IN ) : SV_Target
{
	if (IN.uv0.x < uvX1 || IN.uv0.x > uvX2
	|| IN.uv0.y < uvY1 || IN.uv0.y > uvY2) {
		return Color;
	} else {
		return tex2D(backBuffer, IN.uv0);
	}
}

PFXVertToPix mainV( PFXVert IN )
{
   return processPostFxVert(IN);
}