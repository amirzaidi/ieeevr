Shader "MonoAttenuate"
{
    Properties
    {
        ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        GraphicsFormat("", Integer) = 5 // GraphicsFormat.R8_UNorm
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    TEX(Fade);

    float4 Main()
    {
        float maxFade = FadeOffset(ZERO_I2).x;
        float maxLine = DFT4MaxVal(PrevOffset(ZERO_I2));
        float v = clampui(max(maxFade, maxLine));

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
