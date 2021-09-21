/*
  No one needs private RTGI, right :-)?
*/

#include "ReShade.fxh"


float GetLinearizedDepth(float2 texcoord)
{
	return ReShade::GetLinearizedDepth(texcoord);
}

float3 GetScreenSpaceNormal(float2 texcoord)
{
	float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
	float2 posCenter = texcoord.xy;
	float2 posNorth  = posCenter - offset.zy;
	float2 posEast   = posCenter + offset.xz;

	float3 vertCenter = float3(posCenter - 0.5, 1) * GetLinearizedDepth(posCenter);
	float3 vertNorth  = float3(posNorth - 0.5,  1) * GetLinearizedDepth(posNorth);
	float3 vertEast   = float3(posEast - 0.5,   1) * GetLinearizedDepth(posEast);

	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}

float nrand(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

void Trace(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	float3 depth = GetLinearizedDepth(texcoord).xxx;

	float2 centredTexCoord = texcoord - float2(0.5, 0.5);

	float perspectiveCoeff = 1.5;

	float3 selfPosition = float3(centredTexCoord.x * depth.z * perspectiveCoeff, centredTexCoord.y * depth.z * perspectiveCoeff, depth.z);

	float3 normal = GetScreenSpaceNormal(texcoord);

	color = tex2D(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;



	normal = normal - float3(0.5, 0.5, 0.5);


	
	float rayDirX = nrand(texcoord);
	float rayDirY = nrand(texcoord * 10.0);
	float rayDirZ = nrand(texcoord * 100.0);

	float3 rand = float3(rayDirX, rayDirY, rayDirZ) - float3(0.5, 0.5, 0.5);
	
	float3 rayDir = -normal + rand;
	
	rayDir = normalize(rayDir);



	for(int i = 0; i <= 32; i++)
	{
		float3 newPosition = selfPosition + rayDir * 0.001;

		float2 newTexCoord = float2(newPosition.x / (newPosition.z * perspectiveCoeff), newPosition.y / (newPosition.z * perspectiveCoeff));

		float2 newTexCoordCentred = newTexCoord + float2(0.5, 0.5);
		
		if(newTexCoordCentred.x > 0.0 && newTexCoordCentred.x < 1.0 && newTexCoordCentred.y > 0.0 && newTexCoordCentred.y < 1.0){
			float3 newDepth =  GetLinearizedDepth(newTexCoordCentred).xxx;
			float3 newNormal = GetScreenSpaceNormal(newTexCoordCentred);

			float dot = dot(newNormal, normal);

			if(newPosition.z > newDepth.x && newPosition.z < newDepth.x + 0.005 && dot < 2.0){
				float3 photon = tex2D(ReShade::BackBuffer, float4(newTexCoordCentred, 0, 0)).xyz;
				
				color = lerp(photon, color, 0.5);

				i = 64;
			}
		}

		selfPosition = newPosition;
	}

}



technique SSRT <
	ui_tooltip = "Open source screen space ray tracing shader for reshade.\n";
>

{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Trace;
	}
}
