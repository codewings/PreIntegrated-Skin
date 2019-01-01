Shader "Custom/PreIntegratedSkinLUT"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _ScatteringLUT("Scattering Lookup Table", 2D) = "black" {}
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
        sampler2D _ScatteringLUT;

        struct Input
        {
            float2 uv_MainTex;
        };

        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        inline half4 LightingStandardWithPreIntegratedSkin(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
        {
            half4 lighting = LightingStandard(s, viewDir, gi);
            half wrappedNdL = (dot(gi.light.dir, s.Normal) * 0.5 + 0.5);

            half4 scatteringColor = tex2D(_ScatteringLUT, float2(wrappedNdL, 1.0 / s.Alpha));
            lighting.rgb += (1 - wrappedNdL) * gi.light.color * s.Albedo * scatteringColor.rgb * 2;
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

            // Metallic and smoothness come
            o.Metallic = 0;
            o.Smoothness = 0.5;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
