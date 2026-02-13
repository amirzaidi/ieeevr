Shader "Reproj"
{
    Properties
    {
        ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        GraphicsFormat("", Integer) = 5 // GraphicsFormat.R8_UNorm
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    TEX(Map);
    TEX(Occlusion);

    float4 Main()
    {
        // From Source to Target.
        float2 cMap = MapOffset(ZERO_I2).xy;
        int2 xyReproj = int2(cMap.x, cMap.y);

        float v = PrevOffset(ZERO_I2).x;
        float w = OcclusionOffset(ZERO_I2).x;
        v = min(v, w + (1.f - w) * PrevGlobalOpposite(xyReproj));

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
