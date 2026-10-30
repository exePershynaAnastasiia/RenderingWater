
Shader "Custom/Waves"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        
        _Wave1 ("Wave 1: Amplitude, Wavelength, Speed", Vector) = (0.25, 4, 1, 0)
        _Wave2 ("Wave 2: Amplitude, Wavelength, Speed", Vector) = (0.12, 2, 0.7, 0)
        _Wave3 ("Wave 3: Amplitude, Wavelength, Speed", Vector) = (0.06, 1, 1.3, 0)

        _Direction1 ("Wave 1 Direction", Vector) = (1, 0, 0, 0)
        _Direction2 ("Wave 2 Direction", Vector) = (0.5, 1, 0, 0)
        _Direction3 ("Wave 3 Direction", Vector) = (-1, 0.3, 0, 0)

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

                float4 _Wave1;
                float4 _Wave2;
                float4 _Wave3;

                float4 _Direction1;
                float4 _Direction2;
                float4 _Direction3;
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

            float CalculateWave(
                float3 positionOS,
                float4 wave,
                float2 direction,
                out float2 gradient)
            {
                float amplitude = wave.x;
                float wavelength = max(wave.y, 0.001);
                float speed = wave.z;

                float2 dir = normalize(direction);

                float k = 2.0 * PI / wavelength;

                float phase = k * (dot(dir, positionOS.xz) - speed * _Time.y);

                float height = amplitude * sin(phase);

                gradient = amplitude * k * cos(phase) * dir;

                return height;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 position = IN.positionOS.xyz;

                float2 gradient1;
                float2 gradient2;
                float2 gradient3;

                // Calculate individual waves
                float wave1 = CalculateWave(
                    position, _Wave1, _Direction1.xy, gradient1
                );

                float wave2 = CalculateWave(
                    position, _Wave2, _Direction2.xy, gradient2
                );

                float wave3 = CalculateWave(
                    position, _Wave3, _Direction3.xy, gradient3
                );

                // Combine wave heights
                position.y += wave1 + wave2 + wave3;

                // Combine gradients to calculate the surface normal
                float2 totalGradient = gradient1 + gradient2 + gradient3;

                float3 normalOS = normalize(
                    float3(-totalGradient.x, 1.0, -totalGradient.y)
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
