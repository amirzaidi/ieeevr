Shader "Pos"
{
    Properties
    {
        //ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        //GraphicsFormat("", Integer) = 51 // GraphicsFormat.R32G32B32_SFloat
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    float4 Main()
    {
        float depth = DepthOffset(ZERO_I2);

        float flag = 0.f;
        if (depth < EPS || depth > 1.f - EPS)
        {
            flag = FLAG_OUT_OF_BOUNDS;
        }
        else if (IsSpecular(ZERO_I2))
        {
            flag = FLAG_EXCLUDED;
        }

        float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
        return float4(worldPos, flag);
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
