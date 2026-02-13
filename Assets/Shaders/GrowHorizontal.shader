Shader "GrowHorizontal"
{
    Properties
    {
        ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        GraphicsFormat("", Integer) = 5 // GraphicsFormat.R8_UNorm
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    float4 Main()
    {
        if (IsBoundary(xy))
        {
            return PrevOffset(ZERO_I2);
        }

        const int R = 2;
        float v = 0.f;
        for (int i = -R; i <= R; i += 1)
        {
            v = max(v, PrevOffset(int2(i, 0)).x);
        }

        return float4(v, 0.f, 0.f, 0.f);

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
