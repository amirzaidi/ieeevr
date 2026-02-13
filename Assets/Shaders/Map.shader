Shader "Map"
{
    Properties
    {
        ColorFormat("", Integer) = 12 // RenderTextureFormat.RGFloat
        GraphicsFormat("", Integer) = 50 // GraphicsFormat.R32G32_SFloat
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    #define FLT_BIG 9999999.f

    TEX(Pos);

    float4 Main()
    {
#ifdef UNITY_STEREO_INSTANCING_ENABLED
        float4 cPos = PosOffset(ZERO_I2);

        if (cPos.w == FLAG_OUT_OF_BOUNDS)
        {
            cPos.xyz = ComputeWorldSpacePosition(uv, 1.f, UNITY_MATRIX_I_VP);
        }
        cPos.w = 1.f;

        float4 repr = mul(TARGET_VP, cPos);
        float3 reprndc = repr.xyz / repr.w;
        float2 repruv = reprndc.xy * 0.5f + 0.5f;
        float2 reprxy = repruv * _ScreenSize.xy;

        return float4(reprxy.x, reprxy.y, 0.f, 0.f);
#else
        return float4(xy.x, xy.y, 0.f, 0.f);
#endif
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
