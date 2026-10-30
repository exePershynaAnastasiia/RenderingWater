
Shader "Custom/Waves"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        _WaveA ("Wave A (Direction XY, Steepness, Wavelength)", Vector) = (1, 0, 0.5, 10)
        _WaveB ("Wave B", Vector) = (0, 1, 0.25, 20)
        _WaveC ("Wave C", Vector) = (1, 1, 0.15, 10)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _Color;
                half _Glossiness;
                half _Metallic;

                float4 _WaveA;
                float4 _WaveB;
                float4 _WaveC;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                half fogFactor : TEXCOORD3;
            };

            // float CalculateWave(
            //     float3 positionOS,
            //     float4 wave,
            //     float2 direction,
            //     out float2 gradient)
            // {
            //     float amplitude = wave.x;
            //     float wavelength = max(wave.y, 0.001);
            //     float speed = wave.z;

            //     float2 dir = normalize(direction);

            //     float k = 2.0 * PI / wavelength;

            //     float phase = k * (dot(dir, positionOS.xz) - speed * _Time.y);

            //     float height = amplitude * sin(phase);

            //     gradient = amplitude * k * cos(phase) * dir;

            //     return height;
            // }
            
            float3 GerstnerWave(
                float4 wave,
                float3 position,
                inout float3 tangent,
                inout float3 binormal)
            {
                float steepness = wave.z;
                float wavelength = max(wave.w, 0.001);

                float k = 2.0 * PI / wavelength;
                float c = sqrt(9.8 / k);

                float2 direction = normalize(wave.xy);

                float phase = k * (
                    dot(direction, position.xz) - c * _Time.y
                );

                float amplitude = steepness / k;

                float s = sin(phase);
                float co = cos(phase);

                // Accumulate tangent
                tangent += float3(
                    -direction.x * direction.x * steepness * s,
                    direction.x * steepness * co,
                    -direction.x * direction.y * steepness * s
                );

                // Accumulate binormal
                binormal += float3(
                    -direction.x * direction.y * steepness * s,
                    direction.y * steepness * co,
                    -direction.y * direction.y * steepness * s
                );

                // Return Gerstner displacement
                return float3(
                    direction.x * amplitude * co,
                    amplitude * s,
                    direction.y * amplitude * co
                );
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 gridPoint = IN.positionOS.xyz;

                // Start with zero derivatives for wave accumulation
                float3 tangent = float3(0, 0, 0);
                float3 binormal = float3(0, 0, 0);

                float3 position = gridPoint;

                // Accumulate three Gerstner waves
                position += GerstnerWave(
                    _WaveA, gridPoint, tangent, binormal
                );

                position += GerstnerWave(
                    _WaveB, gridPoint, tangent, binormal
                );

                position += GerstnerWave(
                    _WaveC, gridPoint, tangent, binormal
                );

                // Add flat surface derivatives once
                tangent += float3(1, 0, 0);
                binormal += float3(0, 0, 1);

                // Calculate surface normal
                float3 normalOS = normalize(
                    cross(binormal, tangent)
                );

                VertexPositionInputs positionInputs =
                    GetVertexPositionInputs(position);

                VertexNormalInputs normalInputs =
                    GetVertexNormalInputs(normalOS);

                OUT.positionHCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalWS = normalInputs.normalWS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 c = SAMPLE_TEXTURE2D(
                    _MainTex,
                    sampler_MainTex,
                    IN.uv
                ) * _Color;

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = c.rgb;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = _Glossiness;
                surfaceData.alpha = 1.0;
                surfaceData.occlusion = 1.0;
                surfaceData.normalTS = half3(0, 0, 1);

                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.normalWS = normalize(IN.normalWS);
                inputData.viewDirectionWS =
                    GetWorldSpaceNormalizeViewDir(IN.positionWS);
                inputData.shadowCoord =
                    TransformWorldToShadowCoord(IN.positionWS);
                inputData.fogCoord = IN.fogFactor;
                inputData.bakedGI =
                    SampleSH(inputData.normalWS);
                inputData.normalizedScreenSpaceUV =
                    GetNormalizedScreenSpaceUV(IN.positionHCS);
                inputData.shadowMask = half4(1, 1, 1, 1);

                half4 color = UniversalFragmentPBR(
                    inputData,
                    surfaceData
                );

                color.rgb = MixFog(color.rgb, IN.fogFactor);

                return color;
            }

            ENDHLSL
        }
    }
}
