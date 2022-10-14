#ifndef UNIVERSAL_PREINTEGRATED_LIGHTING_INCLUDED
#define UNIVERSAL_PREINTEGRATED_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#define PREINTEGRATED_HIGH_FIDELITY_MODE 1

#ifdef _PREINTEGRATED_WITH_CURVA_APPROX
#define PREINTEGRATED_FIT_FN FitWithCurveApprox
#else
#define PREINTEGRATED_FIT_FN FitWithLUT
#endif

TEXTURE2D(_ScatterLUT); SAMPLER(sampler_ScatterLUT);

half3 FitWithCurveApprox(half NdotL, half Curvature)
{
    half curva = (1.0/mad(Curvature, 0.5 - 0.0625, 0.0625) - 2.0) / (16.0 - 2.0);
    half oneMinusCurva = 1.0 - curva;
    half3 curve0;
    {
        half3 rangeMin = half3(0.0, 0.3, 0.3);
        half3 rangeMax = half3(1.0, 0.7, 0.7);
        half3 offset = half3(0.0, 0.06, 0.06);
        half3 t = saturate( mad(NdotL, 1.0 / (rangeMax - rangeMin), (offset + rangeMin) / (rangeMin - rangeMax)  ) );
        half3 lowerLine = (t * t) * half3(0.65, 0.5, 0.9);
        lowerLine.r += 0.045;
        lowerLine.b *= t.b;
        half3 m = half3(1.75, 2.0, 1.97);
        half3 upperLine = mad(NdotL, m, half3(0.99, 0.99, 0.99) -m );
        upperLine = saturate(upperLine);
        half3 lerpMin = half3(0.0, 0.35, 0.35);
        half3 lerpMax = half3(1.0, 0.7 , 0.6 );
        half3 lerpT = saturate( mad(NdotL, 1.0/(lerpMax-lerpMin), lerpMin/ (lerpMin - lerpMax) ));
        curve0 = lerp(lowerLine, upperLine, lerpT * lerpT);
    }
    half3 curve1;
    {
        half3 m = half3(1.95, 2.0, 2.0);
        half3 upperLine = mad( NdotL, m, half3(0.99, 0.99, 1.0) - m);
        curve1 = saturate(upperLine);
    }
    float oneMinusCurva2 = oneMinusCurva * oneMinusCurva;
    return lerp(curve0, curve1, mad(oneMinusCurva2, -1.0 * oneMinusCurva2, 1.0) );
}

half3 FitWithLUT(half NdotL, half Curvature)
{
    return saturate(SAMPLE_TEXTURE2D(_ScatterLUT, sampler_ScatterLUT, half2(NdotL, Curvature)).rgb);
}

half3 PreIntegratedRadianceWithLUT(half3 shadeNormal, half3 blurredNormal, half3 L, half attenuation, half curvature)
{
#if PREINTEGRATED_HIGH_FIDELITY_MODE == 0
    half3 N = normalize(lerp(blurredNormal, shadeNormal, 0.3)); // not physcial correct
    half NdotL = dot(N, L);
    half wrappedNdotL = max(0, (NdotL + 0.5) / (1 + 0.5));

    return PREINTEGRATED_FIT_FN(attenuation * wrappedNdotL, curvature);
#else
    half  blurredNdotL = dot(blurredNormal, L);
    half3 normalSmoothFactor = saturate(1.0 - blurredNdotL);
    normalSmoothFactor *= normalSmoothFactor;

    half3 shadeNormalG = normalize(lerp(shadeNormal, blurredNormal, 0.3 + 0.7 * normalSmoothFactor));
    half3 shadeNormalB = normalize(lerp(shadeNormal, blurredNormal, normalSmoothFactor));
    half3 shadeNdotL = half3(blurredNdotL, dot(shadeNormalG, L), dot(shadeNormalB, L));

    shadeNdotL = max(0, (shadeNdotL + 0.5) / (1 + 0.5));
    return half3(
        PREINTEGRATED_FIT_FN(attenuation * shadeNdotL.r, curvature).r,
        PREINTEGRATED_FIT_FN(attenuation * shadeNdotL.g, curvature).g,
        PREINTEGRATED_FIT_FN(attenuation * shadeNdotL.b, curvature).b
    );
#endif
}

#endif  // UNIVERSAL_PREINTEGRATED_LIGHTING_INCLUDED
