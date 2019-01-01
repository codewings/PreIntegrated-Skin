Shader "Custom/PreIntegratedSkinCurveApprox"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf StandardWithPreIntegratedSkin fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #include "UnityPBSLighting.cginc"

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        half3 PreIntegratedSkinWithCurveApprox(half NdotL, half Curvature)
        {
            float curva = (1.0/mad(Curvature, 0.5 - 0.0625, 0.0625) - 2.0) / (16.0 - 2.0);
            float oneMinusCurva = 1.0 - curva;
            float3 curve0;
            {
                float3 rangeMin = float3(0.0, 0.3, 0.3);
                float3 rangeMax = float3(1.0, 0.7, 0.7);
                float3 offset = float3(0.0, 0.06, 0.06);
                float3 t = saturate( mad(NdotL, 1.0 / (rangeMax - rangeMin), (offset + rangeMin) / (rangeMin - rangeMax)  ) );
                float3 lowerLine = (t * t) * float3(0.65, 0.5, 0.9);
                lowerLine.r += 0.045;
                lowerLine.b *= t.b;
                float3 m = float3(1.75, 2.0, 1.97);
                float3 upperLine = mad(NdotL, m, float3(0.99, 0.99, 0.99) -m );
                upperLine = saturate(upperLine);
                float3 lerpMin = float3(0.0, 0.35, 0.35);
                float3 lerpMax = float3(1.0, 0.7 , 0.6 );
                float3 lerpT = saturate( mad(NdotL, 1.0/(lerpMax-lerpMin), lerpMin/ (lerpMin - lerpMax) ));
                curve0 = lerp(lowerLine, upperLine, lerpT * lerpT);
            }
            float3 curve1;
            {
                float3 m = float3(1.95, 2.0, 2.0);
                float3 upperLine = mad( NdotL, m, float3(0.99, 0.99, 1.0) - m);
                curve1 = saturate(upperLine);
            }
            float oneMinusCurva2 = oneMinusCurva * oneMinusCurva;
            return lerp(curve0, curve1, mad(oneMinusCurva2, -1.0 * oneMinusCurva2, 1.0) );
        }

        inline half4 LightingStandardWithPreIntegratedSkin(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
            half4 lighting = LightingStandard(s, viewDir, gi);
            half wrappedNdL = (dot(gi.light.dir, s.Normal) * 0.5 + 0.5);
            lighting.rgb += (1 - wrappedNdL) * gi.light.color * PreIntegratedSkinWithCurveApprox(wrappedNdL, 8 * s.Alpha) * 2 * s.Albedo;
            return lighting;
        }

        inline void LightingStandardWithPreIntegratedSkin_GI(inout SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
        {
            half shadow = data.atten;
            LightingStandard_GI(s, data, gi);
            gi.light.ndotl = shadow;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
            o.Albedo = c.rgb;

            // Metallic and smoothness
            o.Metallic = 0;
            o.Smoothness = 0.5;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
