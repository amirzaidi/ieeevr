Shader "Occlusion"
{
    Properties
    {
        ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        GraphicsFormat("", Integer) = 5 // GraphicsFormat.R8_UNorm
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"
    #define TAA true

    TEX(Map);

    float4 Main()
    {
        // Step one: from Source to Target.
        float2 c = MapOffset(ZERO_I2).xy;
        int2 xyReproj = int2(c.x, c.y);

        // Step two: from Target to Source.
        float2 cOpp = MapGlobalOpposite(xyReproj).xy;

        // Step three: backcheck.
        float2 dxy = cOpp - (float2(xy.x, xy.y) + 0.5f);

        // Either significant stretching or occlusion happening.
        const float m = TAA ? 2.f : 1.f;
        const float MIN_OCC = m * sqrt(1.f + 1.f);
        const float MAX_OCC = m * sqrt(2.f + 2.f);
        float o = clampui(linmapui(length(dxy), MIN_OCC, MAX_OCC));

        // For each neighbouring pixel, check the jump distance.
        float j = 0.f;
        for (int dy = -1; dy <= 1; dy += 1)
        {
            for (int dx = -1; dx <= 1; dx += 1)
            {
                int2 d = int2(dx, dy);
                float2 df = float2(dx, dy);

                float2 cp = MapOffset(d).xy;
                float2 ji = (cp - c) - df;

                j = max(j, ji);
            }
        }
        const float n = TAA ? 2.f : 1.f;
        const float MIN_JMP = n * 3.0f;
        const float MAX_JMP = n * 6.0f;
        j = clampui(linmapui(j, MIN_JMP, MAX_JMP));

        return float4(max(o, j), 0.f, 0.f, 0.f);
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
