Shader "Custom/RayMarching"
{
	Properties{
		 _MainTex("Albedo (RGB)", 2D) = "white" {}
		 [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

		SubShader{

			Tags{
				"Queue" = "Transparent"
				"IgnoreProjector" = "True"
				"RenderType" = "Transparent"
			}

			ColorMask RGB
			Cull Back
			ZWrite On
			ZTest On
			Blend SrcAlpha OneMinusSrcAlpha

			Pass{

				CGPROGRAM

				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "RayMarch.cginc"

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase // useful to have shadows 
				#pragma shader_feature ____ _DEBUG 

				#pragma target 3.0

				struct v2f {
					float4 pos : 		SV_POSITION;
					float3 worldPos : 	TEXCOORD0;
					float3 normal : 	TEXCOORD1;
					float3 viewDir: 	TEXCOORD3;
					float4 screenPos : 	TEXCOORD4;
					float4 color: 		COLOR;
				};

				sampler2D _Global_Noise_Lookup;


				float _RayMarchSmoothness;
				float _RayMarchShadowSoftness;
				uniform float4 RayMarchCube_0;
				uniform float4 RayMarchCube_0_Size;
				uniform float4 RayMarchCube_1;
				uniform float4 RayMarchCube_1_Size;
				uniform float4 RayMarchCube_1_Reps;
				uniform float4 RayMarchSphere_0;
				uniform float4 RayMarchSphere_0_Reps;
				uniform float4 RayMarchSphere_1;
				uniform float4 RayMarchSphere_1_Reps;
				uniform float4 RayMarchLight_0;

				uniform float4 _RayMarchLightColor;

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.pos = UnityObjectToClipPos(v.vertex);
					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
					o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
					o.screenPos = ComputeScreenPos(o.pos);
					o.color = v.color;
					return o;
				}


				inline float SphereDistance(float3 position, float4 posNsize, float4 reps) {

					return length(frac((position - posNsize.xyz + reps.y)* reps.z) * reps.x - reps.y) - posNsize.w;
				}

			

			



				inline float SceneSdf(float3 position) {

				
					float s0 = SphereDistance(position, RayMarchSphere_0, RayMarchSphere_0_Reps);
					float s1 = SphereDistance(position, RayMarchSphere_1, RayMarchSphere_1_Reps);

					float c0 = CubeDistance(position, RayMarchCube_0, RayMarchCube_0_Size.xyz, _RayMarchSmoothness);
					float c1 =	CubeDistance(position, RayMarchCube_1, RayMarchCube_1_Size.xyz, _RayMarchSmoothness);

					float dist = CubicSmin(s0, s1 , _RayMarchSmoothness);
					

					dist = OpSmoothSubtraction(dist, c1, _RayMarchSmoothness);

					dist = CubicSmin(dist, c0, _RayMarchSmoothness * 2);

					return dist;
				}


				inline float Softshadow(float3 start, float3 direction, float mint, float maxt, float k)
				{
					float res = 1.0;
					float ph = 1e20;
					for (float distance = mint; distance < maxt; )
					{
						float dist = SceneSdf(start + direction * distance);
				
						float dsq = dist * dist;
						
						float y = dsq / (2*ph);
						float d = sqrt(dsq - y * y);
						res = min(res, k*d / max(0.0000001, distance - y));
						ph = dist;
						distance += dist;

						if (dist < 0.01)
							return 0.0;

					}
					return res;
				}


				inline float Reflection(float3 start, float3 direction, float mint, float maxt, float k, out float t, out float3 pos)
				{

					float closest = mint;
					t = mint;
					pos = start;

					for ( int i=0; i<40; i++)
					{
						pos = start + direction * t;

						float h = SceneSdf(pos);
						
						closest = min(h/t, closest);

						//if (h < 0.01)
						//	return 0.0;

						t += h;
					}


					return  closest/ mint;
				}

	
				inline float3 EstimateNormal(float3 pos) {

					float EPSILON = 0.01f;

					return normalize(float3(
						SceneSdf(float3(pos.x + EPSILON, pos.y, pos.z)) - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z)),
						SceneSdf(float3(pos.x, pos.y + EPSILON, pos.z)) - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z)),
						SceneSdf(float3(pos.x, pos.y, pos.z + EPSILON)) - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON))
					));
				}


				float4 frag(v2f o) : COLOR{

					o.viewDir.xyz = normalize(o.viewDir.xyz + o.normal.xyz);

					float3 position = o.worldPos.xyz;
					float3 direction = -o.viewDir.xyz;

					float totalDistance = 0;

					float s0;
					float s1;
					float dist;
					float dott = 1;

					const float maxSteps = 40;

					const float maxDistance = 10000;

					bool gotSky = false;



					for (int i = 0; i < maxSteps; i++) {

						dist = SceneSdf(position);

						position += dist * direction;

						totalDistance += dist;
					
						if (dist < 0.01) {
							i = 999;
						}
						
					}

				

					float3 normal = EstimateNormal(position);

					dott = 1 - max(0, dot(-direction, normal));
			

					float3 lightSource = RayMarchLight_0.xyz; //_WorldSpaceLightPos0

					float3 toCenterVec = lightSource - position;

					float toCenter = length(toCenterVec); 

					float3 lightDir = normalize(toCenterVec);

					float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.screenPos.xy * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));


					float shadow = Softshadow(position, lightDir, 5, toCenter,  _RayMarchShadowSoftness);


					//	return shadow;

						float toview = max(0, dot(normal, o.viewDir.xyz));

						float3 reflected = normalize(o.viewDir.xyz - 2 * (toview)*normal);

						float reflectedDistance;

						float3 reflectionPos;

						float reflectedSky = Reflection(position, -reflected, 0.1, maxDistance, 1, reflectedDistance, reflectionPos);

						float3 toCenterVecRefl = lightSource - reflectionPos;

						float toCenterRefl = length(toCenterVecRefl);

						float3 lightDirRef = normalize(toCenterVecRefl);

						float reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2, toCenterRefl, _RayMarchShadowSoftness);

						//float reflectedShadow = 1;

					//	return reflectedShadow;

					
						float light = max(0, dot(lightDir, normal));

						float4 col = 1;

						float lightRange = RayMarchLight_0.w + 1;
						float deLightRange = 1 / lightRange;

						float lightBrightness = max(0, lightRange - toCenter) * deLightRange;

						float lightBrightnessReflected = max(0, lightRange - length (reflectionPos - position)) *deLightRange;

						col.rgb = (_RayMarchLightColor.rgb * light * shadow * lightBrightness + unity_AmbientEquator.rgb);

						float deFog = 1 - totalDistance / maxDistance;
						deFog *= deFog;

						float reflectedFog = max(0, 1 - reflectedDistance / maxDistance);

						float3 fogColor = float3(0.2, 0.2, 0.9);

						float reflAmount = pow(deFog * reflectedFog, 8);

						reflectedFog *= reflAmount;

						dott *= reflAmount;
						
						reflectedSky = reflectedSky * (reflAmount) +(1 - reflAmount);

						lightBrightnessReflected *= reflAmount;

						float3 reflCol = (_RayMarchLightColor.rgb * reflectedShadow * lightBrightnessReflected *(1 - reflectedSky));
						
						float edge = pow(dott , 4) * reflAmount * reflAmount;

						reflCol = reflCol * float3(1,4,1) * (1 - edge); // +edge * (_RayMarchLightColor.rgb + fogColor);
					
						col.rgb += dott * reflCol;

						col.rgb +=  (noise.rgb - 0.5)*col.rgb*0.2;

						col.rgb = col.rgb * deFog + fogColor*(1-deFog);
						return 	col;


				}
				ENDCG
			}
		}
	 Fallback "Legacy Shaders/Transparent/VertexLit"

					//CustomEditor "CircleDrawerGUI"
}