#ifndef UNIVERSAL_SG_SUBSURFACE_LIGHTING_INCLUDED
#define UNIVERSAL_SG_SUBSURFACE_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// G( v; u,L,a ) = a * exp( L * (dot(u,v) - 1) )
struct SphericalGaussian
{
    half3	Axis;		// u
    half	Sharpness;	// L
    half	Amplitude;	// a
};

struct SubsurfaceNormal
{
    half3 NormalR;
    half3 NormalG;
    half3 NormalB;
};

#define EPS 1e-4f

SphericalGaussian MakeNormalizedSG(half3 lightDir, half sharpness)
{
    SphericalGaussian sg;
    sg.Axis = lightDir;
    sg.Sharpness = sharpness;
    sg.Amplitude = sg.Sharpness / ((2 * PI) * (1 - exp(-2 * sg.Sharpness)));
    return sg;
}

float SGIrradianceFitted(SphericalGaussian G, float3 N)
{
    const float muDotN = dot( G.Axis, N );

    const float c0 = 0.36;
    const float c1 = 0.25 / c0;

    float eml  = exp( -G.Sharpness );
    float em2l = eml * eml;
    float rl   = rcp( G.Sharpness );

    float scale = 1.0f + 2.0f * em2l - rl;
    float bias  = (eml - em2l) * rl - em2l;

    float x = sqrt( 1.0 - scale );
    float x0 = c0 * muDotN;
    float x1 = c1 * x;

    float n = x0 + x1;
    float y = ( abs( x0 ) <= x1 ) ? n*n / x : saturate( muDotN );

    return scale * y + bias;
}

SubsurfaceNormal CalculateSubsurfaceNormal(half3 normalFactor, half3 shadeNormal, half3 blurredNormal)
{
    SubsurfaceNormal subsurfaceNormal;
    subsurfaceNormal.NormalR = normalize(lerp(shadeNormal, blurredNormal, normalFactor.x));
    subsurfaceNormal.NormalG = normalize(lerp(shadeNormal, blurredNormal, normalFactor.y));
    subsurfaceNormal.NormalB = normalize(lerp(shadeNormal, blurredNormal, normalFactor.z));
    return subsurfaceNormal;
}

half3 SphericalGaussianSubsurfaceRadiance(half3 shadeNormal, half3 blurredNormal, half3 L, half3 falloffColor, half3 scatterColor)
{
    SubsurfaceNormal subsurfaceNormal = CalculateSubsurfaceNormal(falloffColor, shadeNormal, blurredNormal);

    SphericalGaussian kernelR = MakeNormalizedSG(L, rcp(max(scatterColor.r, EPS)));
    SphericalGaussian kernelG = MakeNormalizedSG(L, rcp(max(scatterColor.g, EPS)));
    SphericalGaussian kernelB = MakeNormalizedSG(L, rcp(max(scatterColor.b, EPS)));
    half3 diffuse = half3(SGIrradianceFitted(kernelR, subsurfaceNormal.NormalR),
                          SGIrradianceFitted(kernelG, subsurfaceNormal.NormalG),
                          SGIrradianceFitted(kernelB, subsurfaceNormal.NormalB));

    half NdotL = dot(blurredNormal, L);
    return diffuse * max(0, (NdotL + 0.5) / (1 + 0.5));
}

#endif  // UNIVERSAL_SG_SUBSURFACE_LIGHTING_INCLUDED
