/*
  No one needs private RTGI, right :-)?
*/

#include "ReShade.fxh"

uniform float BASE_RAYS_LENGTH <
	ui_type = "drag";
	ui_min = 0.1; ui_max = 10.0;
    ui_step = 0.1;
    ui_label = "Base ray length";
	ui_tooltip = "Increases distance of light spreading, decreases intersections detection quality";
    ui_category = "Ray Tracing";
> = 2.0;

uniform int RAYS_AMOUNT <
	ui_type = "drag";
	ui_min = 1; ui_max = 32;
    ui_step = 1;
    ui_label = "Rays amount";
	ui_tooltip = "Decreases noise amount";
    ui_category = "Ray Tracing";
> = 9;

uniform int STEPS_PER_RAY <
	ui_type = "drag";
	ui_min = 1; ui_max = 32;
    ui_step = 1;
    ui_label = "Steps per ray";
	ui_tooltip = "Increases quality of intersections detection";
    ui_category = "Ray Tracing";
> = 32;


uniform float EFFECT_INTENSITY <
	ui_type = "drag";
	ui_min = 0.1; ui_max = 10.0;
    ui_step = 0.1;
    ui_label = "Effect intensity";
	ui_tooltip = "Power of effect";
    ui_category = "Ray Tracing";
> = 2.0;


uniform float DEPTH_THRESHOLD <
	ui_type = "drag";
	ui_min = 0.001; ui_max = 0.01;
    ui_step = 0.001;
    ui_label = "Depth Threshold";
	ui_tooltip = "Less accurate tracing but less noise at the same time";
    ui_category = "Ray Tracing";
> = 0.002;

uniform float NORMAL_THRESHOLD <
	ui_type = "drag";
	ui_min = -1.0; ui_max = 1.0;
    ui_step = 0.001;
    ui_label = "Normal Threshold";
	ui_tooltip = "More accurate tracing but more noise at the same time";
    ui_category = "Ray Tracing";
> = 0.0;

uniform float PERSPECTIVE_COEFFITIENT <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 10.0;
    ui_step = 0.1;
    ui_label = "Perspective coeff";
	ui_tooltip = "test";
    ui_category = "Ray Tracing";
> = 1.0;






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
	float perspectiveCoeff = PERSPECTIVE_COEFFITIENT;

	color = tex2D(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;
	float3 depth = GetLinearizedDepth(texcoord).xxx;
	float3 normal = GetScreenSpaceNormal(texcoord);

	float2 centredTexCoord = texcoord - float2(0.5, 0.5);


	normal = normal - float3(0.5, 0.5, 0.5);
	normal = normalize(normal);

	[loop]
	for(int j = 0; j < RAYS_AMOUNT; j++){
		float j1 = j + 1;
		float3 selfPosition = float3(centredTexCoord.x * depth.z * perspectiveCoeff, centredTexCoord.y * depth.z * perspectiveCoeff, depth.z);
		
		float rayDirX = nrand(texcoord * j1);
		float rayDirY = nrand(texcoord * 10.0 * j1);
		float rayDirZ = nrand(texcoord * 100.0 * j1);

		float3 rand = float3(rayDirX, rayDirY, rayDirZ) - float3(0.5, 0.5, 0.5);

		rand = normalize(rand);
		
		float3 rayDir = -normal + rand;
		
		rayDir = normalize(rayDir);

		[loop]
		for(int i = 0; i < STEPS_PER_RAY; i++)
		{
			float3 newPosition = selfPosition + rayDir * 0.01 * BASE_RAYS_LENGTH / STEPS_PER_RAY;

			float2 newTexCoord = float2(newPosition.x / (newPosition.z * perspectiveCoeff), newPosition.y / (newPosition.z * perspectiveCoeff));

			float2 newTexCoordCentred = newTexCoord + float2(0.5, 0.5);
			
			if(newTexCoordCentred.x > 0.0 && newTexCoordCentred.x < 1.0 && newTexCoordCentred.y > 0.0 && newTexCoordCentred.y < 1.0){
				float3 newDepth =  GetLinearizedDepth(newTexCoordCentred).xxx;
				float3 newNormal = GetScreenSpaceNormal(newTexCoordCentred);

				newNormal = newNormal - float3(0.5, 0.5, 0.5);
				newNormal = normalize(newNormal);

				float dot = dot(newNormal, rayDir);

				if(newPosition.z > newDepth.x && newPosition.z < newDepth.x + DEPTH_THRESHOLD ){
					if(dot > NORMAL_THRESHOLD){
						float3 photon = tex2D(ReShade::BackBuffer, float4(newTexCoordCentred, 0, 0)).xyz;
					
						color += (photon / RAYS_AMOUNT) * EFFECT_INTENSITY;
					}
					
					i = STEPS_PER_RAY;
				}
			}

			selfPosition = newPosition;
		}
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
