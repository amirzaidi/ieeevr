Shader "LocalMax"
{
    Properties
    {
        StrengthLM("", Float) = 1.0
        GraphicsFormat("", Integer) = 48 // GraphicsFormat.R16G16B16A16_SFloat
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"
    
    uniform float StrengthLM;

    float4 Main()
    {
        if (IsBoundary(xy, 2))
        {
            return 0.f * ONE_f4;
        }

        float cLine[4];
        FOR(COMPASS_HALF, i)
        {
            int2 mvi = COMPASS_HALF[i];
            
            float a = PrevOffset(-2 * mvi)[i];
            float b = PrevOffset(-mvi)[i];
            float c = PrevOffset(ZERO_I2)[i];
            float d = PrevOffset(+mvi)[i];
            float e = PrevOffset(+2 * mvi)[i];

            cLine[i] = clampui(c - 2.f * StrengthLM * min(min(a, b), min(d, e)));
        }

        return ArrayToVec(cLine);
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
