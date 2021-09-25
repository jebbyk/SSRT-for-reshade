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
> = 2.5;

uniform int RAYS_AMOUNT <
	ui_type = "drag";
	ui_min = 1; ui_max = 256;
    ui_step = 1;
    ui_label = "Rays amount";
	ui_tooltip = "Decreases noise amount";
    ui_category = "Ray Tracing";
> = 4;

uniform int STEPS_PER_RAY <
	ui_type = "drag";
	ui_min = 1; ui_max = 256;
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

uniform float TEMPORAL_FACTOR <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 0.9;
    ui_step = 0.1;
    ui_label = "Temporal factor";
	ui_tooltip = "Less noise but more ghosting";
    ui_category = "Filtering";
> = 0.8;

uniform float BLURING_AMOUNT <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 8.0;
    ui_step = 1.0;
    ui_label = "Bluring amount";
	ui_tooltip = "Less noise but less details";
    ui_category = "Filtering";
> = 1.0;




uniform int FRAME_COUNT < source = "framecount"; >;

texture fGiTexture0	            					{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA16F; };
sampler giTexture0	            					{ Texture = fGiTexture0;	    };

texture fGiTexture1	            					{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA16F; };
sampler giTexture1	            					{ Texture = fGiTexture1;	    };

texture fBlurTexture0	            					{ Width = BUFFER_WIDTH >> 1;   Height = BUFFER_HEIGHT >> 1;   Format = RGBA16F; };
sampler blurTexture0	            					{ Texture = fBlurTexture0;	    };

texture fBlurTexture1	            					{ Width = BUFFER_WIDTH >> 2;   Height = BUFFER_HEIGHT >> 2;   Format = RGBA16F; };
sampler blurTexture1	            					{ Texture = fBlurTexture1;	    };

texture fBlurTexture2	            					{ Width = BUFFER_WIDTH >> 3;   Height = BUFFER_HEIGHT >> 3;   Format = RGBA16F; };
sampler blurTexture2	            					{ Texture = fBlurTexture2;	    };

texture fNoiseTexture < source = "bluenoise.png"; > { Width = 32; 			  Height = 32; 				Format = RGBA8; };
sampler	noiseTexture          					{ Texture = fNoiseTexture; AddressU = WRAP; AddressV = WRAP;};


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

	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast));
}

float nrand(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

float3 rand3d(float2 uv)
{
	return tex2D(noiseTexture, float4(uv, 0, 0)).xyz;
}

float2 getPixelSize() 	
{ 
	return float2( 1.0 / 1366.0, 1.0 / 768.0); 
}


void Trace(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	

	float perspectiveCoeff = 1.0;

	float3 depth = GetLinearizedDepth(texcoord).xxx;
	float3 normal = GetScreenSpaceNormal(texcoord);

	float2 centredTexCoord = texcoord - float2(0.5, 0.5);


	[loop]
	for(int j = 0; j < RAYS_AMOUNT; j++){
		float j1 = j + 1;
		float3 selfPosition = float3(centredTexCoord.x * depth.z * perspectiveCoeff, centredTexCoord.y * depth.z * perspectiveCoeff, depth.z);
		
		float3 rand = rand3d(texcoord * 32.0 * j1 + (frac(FRAME_COUNT / 256.0))) - float3(0.5, 0.5, 0.5);

		rand = normalize(rand);
		
		float3 rayDir = -normal - rand;

		float3 step = rayDir * 0.01 * BASE_RAYS_LENGTH / STEPS_PER_RAY;

		[loop]
		for(int i = 0; i < STEPS_PER_RAY; i++)
		{
			float3 newPosition = selfPosition + step;

			float2 newTexCoord = float2(newPosition.x / (newPosition.z * perspectiveCoeff), newPosition.y / (newPosition.z * perspectiveCoeff));

			float2 newTexCoordCentred = newTexCoord + float2(0.5, 0.5);
			
			if(newTexCoordCentred.x > 0.0 && newTexCoordCentred.x < 1.0 && newTexCoordCentred.y > 0.0 && newTexCoordCentred.y < 1.0){
				float3 newDepth =  GetLinearizedDepth(newTexCoordCentred).xxx;
				float3 newNormal = GetScreenSpaceNormal(newTexCoordCentred);

				float dot = dot(newNormal, rayDir);

				if(newPosition.z > newDepth.x && newPosition.z < newDepth.x + DEPTH_THRESHOLD ){
					if(dot > NORMAL_THRESHOLD){
						float3 photon = tex2D(ReShade::BackBuffer, float4(newTexCoordCentred, 0, 0)).xyz;
					
						color += photon / (RAYS_AMOUNT + 1);
					}
					
					i = STEPS_PER_RAY;
				}
			}

			selfPosition = newPosition;
		}
	}
	color = color * (1.0 - TEMPORAL_FACTOR) + tex2D(giTexture1, float4(texcoord, 0, 0)).xyz * TEMPORAL_FACTOR;
}

void Combine(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	color = tex2D(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;
	color += tex2D(blurTexture2, float4(texcoord, 0, 0)).xyz * EFFECT_INTENSITY;
}

void SaveGI(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	color = tex2D(giTexture0, float4(texcoord, 0, 0)).xyz;
}

void Downsample0(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	float2 ps = getPixelSize() * BLURING_AMOUNT;
	color = tex2D(giTexture0, float4(texcoord + float2(-ps.x,-ps.x), 0, 0)).xyz;
	color += tex2D(giTexture0, float4(texcoord + float2(ps.x, -ps.y), 0, 0)).xyz;
	color += tex2D(giTexture0, float4(texcoord + float2(-ps.x, ps.y), 0, 0)).xyz;
	color += tex2D(giTexture0, float4(texcoord + float2(ps.x, ps.y), 0, 0)).xyz;
	color *= 0.25;
}

void Downsample1(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	float2 ps = getPixelSize() * 2 * BLURING_AMOUNT;
	color = tex2D(blurTexture0, float4(texcoord + float2(-ps.x,-ps.x), 0, 0)).xyz;
	color += tex2D(blurTexture0, float4(texcoord + float2(ps.x, -ps.y), 0, 0)).xyz;
	color += tex2D(blurTexture0, float4(texcoord + float2(-ps.x, ps.y), 0, 0)).xyz;
	color += tex2D(blurTexture0, float4(texcoord + float2(ps.x, ps.y), 0, 0)).xyz;
	color *= 0.25;
}

void Downsample2(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target)
{
	float2 ps = getPixelSize() * 4 * BLURING_AMOUNT;
	color = tex2D(blurTexture1, float4(texcoord + float2(-ps.x,-ps.x), 0, 0)).xyz;
	color += tex2D(blurTexture1, float4(texcoord + float2(ps.x, -ps.y), 0, 0)).xyz;
	color += tex2D(blurTexture1, float4(texcoord + float2(-ps.x, ps.y), 0, 0)).xyz;
	color += tex2D(blurTexture1, float4(texcoord + float2(ps.x, ps.y), 0, 0)).xyz;
	color *= 0.25;
}






technique SSRT <
	ui_tooltip = "Open source screen space ray tracing shader for reshade.\n";
>

{

	pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = Trace;
        RenderTarget0 = fGiTexture0;
	}

	pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = Downsample0;
        RenderTarget0 = fBlurTexture0;
	}

	pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = Downsample1;
        RenderTarget0 = fBlurTexture1;
	}

	pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = Downsample2;
        RenderTarget0 = fBlurTexture2;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Combine;
	}

	pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = SaveGI;
        RenderTarget0 = fGiTexture1;
	}
}
