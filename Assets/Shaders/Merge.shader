Shader "Merge"
{
    Properties
    {
        BReproj("", Integer) = 1
        LineFog("", Integer) = 1
        StrengthToon("", Float) = 1.0
        StrengthLine("", Float) = 1.0
        Strength("", Float) = 1.0
        GraphicsFormat("", Integer) = 75 // GraphicsFormat.A2B10G10R10_UNormPack32
    }
    
    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"

    uniform bool BReproj;
    uniform bool LineFog;
    uniform float StrengthToon;
    uniform float StrengthLine;
    uniform float Strength;

    TEX(Pos);
    TEX(Fade);
    TEX(Occlusion);
    TEX(LocalMax);
    TEX(MonoAttenuate);

    float Attenuate()
    {
        float v = DFT4MaxVal(LocalMaxOffset(ZERO_I2));
    
        if (BReproj)
        {
            // Small 3x3 neighbourhood for post-reprojection culling.
            float reproj = 0.f;
            for (int dy = -1; dy <= 1; dy += 1)
            {
                for (int dx = -1; dx <= 1; dx += 1)
                {
                    reproj = max(reproj, PrevOffset(int2(dx, dy)).x);
                }
            }
            
            // Reduce to at most mask.
            float mask = OcclusionOffset(ZERO_I2).x;

            v = min(v, max(reproj, mask));
        }

        // Soft threshold for line/no-line.
        v = clampui(linmapui(v, THRES_LOW, THRES_HIGH));

        // Add fade back in if it was suppressed.
        v = clampui(max(v, FadeOffset(ZERO_I2).x));
    
        return v;
    }
    
    float3 Toon(float3 rgb)
    {
        const float levels = 3.f; // For input range [0, 1].
        const float shift = 0.55f;
        const float step = 0.15f;

        float brightnessInput = max(EPS, dot(float3(0.2126f, 0.7152f, 0.0722f), rgb));

        // Stretch shadow levels.
        brightnessInput = sqrt(brightnessInput);

        // Discrete step levels.
        float currLevel = floor(brightnessInput * (levels - EPS)) / levels;
        float nextLevel = currLevel + (1.f / levels);
        float brightnessOutput = currLevel;

        // Smooth boundary transitions.
        if (step > EPS)
        {
            float transition = (brightnessInput - currLevel) / (nextLevel - currLevel);
            transition = (transition - (1.f - step)) / step;

            if (transition > 0.f)
            {
                brightnessOutput += smoothmapui(transition) * (nextLevel - currLevel);
            }
        }

        // Add linear shift towards brighter output to show outlines better.
        brightnessOutput = (1.f - shift) * brightnessOutput + shift;

        // Final result.
        return (rgb + EPS) * (brightnessOutput / brightnessInput);
    }
    
    float4 Main()
    {
        float3 cBlit = BlitOffset(ZERO_I2).xyz;
        float3 cOut = PosOffset(ZERO_I2).w == FLAG_OUT_OF_BOUNDS
            ? cBlit
            : lerp(cBlit, Toon(cBlit), StrengthToon);

        // Fade to fog in the distance.
        float fogShift = 0.f;
        if (LineFog && FogStart < 0.1f * FLT_MAX)
        {
            float minDist = 0.f;
            const int RAD = 1;
            for (int dy = -RAD; dy <= RAD; dy += 1)
            {
                for (int dx = -RAD; dx <= RAD; dx += 1)
                {
                    minDist = max(minDist, DepthOffset(int2(dx, dy)).x);
                }
            }

            float minFog = saturate(linmapui(ComputeViewSpacePosition(uv, minDist, UNITY_MATRIX_I_P).z, FogStart, FogEnd));
            float cDist = DepthOffset(ZERO_I2).x;
            float cFog = saturate(linmapui(ComputeViewSpacePosition(uv, cDist, UNITY_MATRIX_I_P).z, FogStart, FogEnd));
            fogShift = lerp(minFog, cFog, 0.25f);
        }

        float cLine = StrengthLine * Attenuate();
        float3 cFogColor = lerp(unity_FogColor, Toon(unity_FogColor), StrengthToon);
        return padf3(lerp(cBlit, lerp(cOut, fogShift * cFogColor, cLine), Strength));
    }
    ENDHLSL
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            Cull Off
            Blend Off
            ZTest Off
            ZWrite Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}
