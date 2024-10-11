//-----------------------------------------------------------------------------
// Copyright (c) 2012 GarageGames, LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//-----------------------------------------------------------------------------

#include "sharpenPostFX.h.hlsl"

#ifdef SHADER_STAGE_VS
	#define mainV main
#else
	#define mainP main
#endif

float4 mainP( PFXVertToPix IN ) : SV_Target
{
   float2 step = 1.0 / targetSize.xy;

   float3 texA = hdrDecode( tex2D( inputTex, IN.uv0 + float2(-step.x, -step.y) * 1.5 ) ).rgb;
   float3 texB = hdrDecode( tex2D( inputTex, IN.uv0 + float2( step.x, -step.y) * 1.5 ) ).rgb;
   float3 texC = hdrDecode( tex2D( inputTex, IN.uv0 + float2(-step.x,  step.y) * 1.5 ) ).rgb;
   float3 texD = hdrDecode( tex2D( inputTex, IN.uv0 + float2( step.x,  step.y) * 1.5 ) ).rgb;

   float3 around = 0.25 * (texA + texB + texC + texD);
   float3 center  = hdrDecode( tex2D( inputTex, IN.uv0 ) ).rgb;

   float3 col = center + (center - around) * sharpness;

   return hdrEncode( float4(col,1.0) );
}

PFXVertToPix mainV( PFXVert IN )
{
   return processPostFxVert(IN);
}
