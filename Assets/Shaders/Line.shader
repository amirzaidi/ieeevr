Shader "Line"
{
    Properties
    {
        BPassthrough("", Integer) = 0
        BPassthroughImproved("", Integer) = 0
        BNoiseReduce("", Integer) = 1
        FSobel("", Float) = 1250.0
        FBackground("", Float) = 1.0
        FPlane("", Float) = 1.0
        FCurvature("", Float) = 1.0
        GraphicsFormat("", Integer) = 48 // GraphicsFormat.R16G16B16A16_SFloat
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"
    #include "ShaderAlgorithm.hlsl"

    //#define PRELOAD true
    
    uniform bool BPassthrough;
    uniform bool BPassthroughImproved;
    uniform bool BNoiseReduce;
    uniform float FSobel;
    uniform float FBackground;
    uniform float FPlane;
    uniform float FCurvature;

    TEX(Pos);

    float sobelCache;

    float LinDepth(int2 offset)
    {
        return length(PosOffset(offset).xyz - CENTER_CAMERA_POS);
    }

    float Sobel()
    {
        if (sobelCache < 0.f)
        {
            float d[3][3];
            for (int dy = 0; dy <= 2; dy += 1)
            {
                for (int dx = 0; dx <= 2; dx += 1)
                {
                    d[dy][dx] = DepthOffset(int2(dx, dy) - 1); // Non-linear.
                    //d[dy][dx] = LinDepth(int2(dx, dy)); // Linear.
                }
            }

            float gx = (d[0][0] - d[0][2]) + 2 * (d[1][0] - d[1][2]) + (d[2][0] - d[2][2]);
            float gy = (d[0][0] - d[2][0]) + 2 * (d[0][1] - d[2][1]) + (d[0][2] - d[2][2]);
            float g = sqrt(gx * gx + gy * gy);

            sobelCache = FSobel * g;
        }

        return sobelCache;
    }

    float DepthContour(float controlDepth, float centerDepth, float checkDepth)
    {
        return 0.005f * (abs(centerDepth - checkDepth) / max(100.f * EPS, abs(centerDepth - controlDepth)) - 1.f);
    }

    float NormContour(float3 controlNorm, float3 centerNorm, float3 checkNorm)
    {
        return (dot(centerNorm, checkNorm) / max(EPS, dot(centerNorm, controlNorm)) - 1.f);
    }

    // Source: https://github.com/IronWarrior/UnityOutlineShader/blob/master/Assets/Outline.shader
    float Raymond()
    {
        // Difference between depth values, scaled by the current depth, required to draw an edge.
        const float _DepthThreshold = 1.5f;

        // The value at which the dot product between the surface normal and the view direction will affect the depth threshold.
        const float _DepthNormalThreshold = 0.5f;

        // Scale the strength of how much the depthNormalThreshold affects the depth threshold.
        const float _DepthNormalThresholdScale = 7.f;

        // Larger values will require the difference between normals to be greater to draw an edge.
        const float _NormalThreshold = 0.4f;

        float3 normal0 = NormOffset(int2(-1, -1));
        float3 normal1 = NormOffset(int2(+1, +1));
        float3 normal2 = NormOffset(int2(+1, -1));
        float3 normal3 = NormOffset(int2(-1, +1));

        float3 depth0 = DepthOffset(int2(-1, -1));
        float3 depth1 = DepthOffset(int2(+1, +1));
        float3 depth2 = DepthOffset(int2(+1, -1));
        float3 depth3 = DepthOffset(int2(-1, +1));

		// Transform the view normal from the 0...1 range to the -1...1 range.
		float3 viewNormal = NormOffset(ZERO_I2);
		float NdotV = 1 - dot(viewNormal, PosOffset(ZERO_I2).xyz - CENTER_CAMERA_POS);

		// Return a value in the 0...1 range depending on where NdotV lies 
		// between _DepthNormalThreshold and 1.
		float normalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
		// Scale the threshold, and add 1 so that it is in the range of 1..._NormalThresholdScale + 1.
		float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1;

		// Modulate the threshold by the existing depth value;
		// pixels further from the screen will require smaller differences
		// to draw an edge.
		float depthThreshold = _DepthThreshold * depth0 * normalThreshold;

        float depthFiniteDifference0 = depth1 - depth0;
		float depthFiniteDifference1 = depth3 - depth2;
		// edgeDepth is calculated using the Roberts cross operator.
		// The same operation is applied to the normal below.
		// https://en.wikipedia.org/wiki/Roberts_cross
		float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
		edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

        float3 normalFiniteDifference0 = normal1 - normal0;
        float3 normalFiniteDifference1 = normal3 - normal2;
		// Dot the finite differences with themselves to transform the 
		// three-dimensional values to scalars.
        float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
        edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

        float edge = max(edgeDepth, edgeNormal);
        return edge;
    }

    // Unused.
    float4 Comparison()
    {
        float cDepth = DepthOffset(ZERO_I2);
        cDepth = LinDepth(ZERO_I2);
        float3 cNorm = NormOffset(ZERO_I2);

        float cLine[4];
        FOR(COMPASS_HALF, i)
        {
            int2 mvi = COMPASS_HALF[i];

            float lDepth = LinDepth(-mvi);
            float rDepth = LinDepth(+mvi);

            float3 lNorm = NormOffset(-mvi);
            float3 rNorm = NormOffset(+mvi);

            float lrCont = max(DepthContour(rDepth, cDepth, lDepth), NormContour(rNorm, cNorm, lNorm));
            float rlCont = max(DepthContour(lDepth, cDepth, rDepth), NormContour(lNorm, cNorm, rNorm));

            cLine[i] = clampui(max(lrCont, rlCont));
        }

        return ArrayToVec(cLine);
    }

    float DoubleContourness(float4 lPos, float3 lNorm, float4 cPos, float3 cNorm, float4 rPos, float3 rNorm, bool nr)
    {
        bool lNaN = lPos.w == FLAG_OUT_OF_BOUNDS;
        bool cNaN = cPos.w == FLAG_OUT_OF_BOUNDS;
        bool rNaN = rPos.w == FLAG_OUT_OF_BOUNDS;

        if (lNaN || cNaN || rNaN)
        {
            // Return line on transitions to background.
            return (lNaN && cNaN && rNaN)
                ? 0.f
                : FBackground;
        }
        
        float2 pc = float2(FPlane, FCurvature);
        return max(
            dot(pc, Contourness(
                lPos, lNorm,
                cPos, cNorm,
                rPos, rNorm,
                nr ? NR_DOUBLE_CONTROL : NR_DOUBLE_NONE
            )),
            dot(pc, Contourness(
                rPos, rNorm,
                cPos, cNorm,
                lPos, lNorm,
                nr ? NR_DOUBLE_CHECK : NR_DOUBLE_NONE
            ))
        );
    }

    float4 Main()
    {
        if (IsBoundary(xy, 2))
        {
            return ZERO_F4;
        }

        sobelCache = -1.f;
        if (BPassthrough)
        {
            return Sobel() * ONE_f4;
        }

        if (BPassthroughImproved)
        {
            return Raymond() * ONE_f4;
        }

        #ifdef PRELOAD
        static const bool enabledPixels[5][5] = {
            { true, false, true, false, true, },
            { false, true, true, true, false, },
            { true, true, true, true, true, },
            { false, true, true, true, false, },
            { true, false, true, false, true, },
        };

        float4 posArray[5][5];
        float3 normArray[5][5];
        for (int y = 0; y < 5; y += 1)
        {
            for (int x = 0; x < 5; x += 1)
            {
                if (enabledPixels[y][x])
                {
                    int2 xya = int2(x, y) - 2;
                    posArray[y][x] = PosOffset(xya);
                    normArray[y][x] = NormOffset(xya);
                }
            }
        }
        float4 cPos = posArray[2][2];
        float3 cNorm = normArray[2][2];
        #else
        float4 cPos = PosOffset(ZERO_I2);
        float3 cNorm = NormOffset(ZERO_I2);
        #endif

        bool cSpec = cPos.w == FLAG_EXCLUDED;

        float cLine[4];
        FOR(COMPASS_HALF, i)
        {
            int2 mvi = COMPASS_HALF[i];
            
            #ifdef PRELOAD
            int2 m = 2 - mvi;
            int2 p = 2 + mvi;
            float4 bPos = posArray[m.y][m.x];
            float4 dPos = posArray[p.y][p.x];
            #else
            float4 bPos = PosOffset(-mvi);
            float4 dPos = PosOffset(+mvi);
            #endif

            bool spec = bPos.w == FLAG_EXCLUDED && cSpec && dPos.w == FLAG_EXCLUDED;
            if (spec)
            {
                cLine[i] = FPlane * Sobel();
                continue;
            }

            float3 bNorm = NormOffset(-mvi);
            float3 dNorm = NormOffset(+mvi);
            float v = DoubleContourness(bPos, bNorm, cPos, cNorm, dPos, dNorm, false);
            
            // Sometimes, one pixel is noisy. This will reduce the impact of single-pixel noise.
            if (BNoiseReduce)
            {
                #ifdef PRELOAD
                int2 mm = m - mvi.x;
                int2 pp = p + mvi.x;
                float4 aPos = posArray[mm.y][mm.x];
                float3 aNorm = normArray[mm.y][mm.x];
                float4 ePos = posArray[pp.y][pp.x];
                float3 eNorm = normArray[pp.y][pp.x];
                #else
                float4 aPos = PosOffset(-2 * mvi);
                float3 aNorm = NormOffset(-2 * mvi);
                float4 ePos = PosOffset(+2 * mvi);
                float3 eNorm = NormOffset(+2 * mvi);
                #endif

                // Pixel b is noisy.
                float vacd = DoubleContourness(aPos, aNorm, cPos, cNorm, dPos, dNorm, true);
                    
                // Pixel d is noisy.
                float vbce = DoubleContourness(ePos, eNorm, cPos, cNorm, bPos, bNorm, true);

                // If this is single-pixel noise, set the line transparency to half.
                float vmin = min(vacd, vbce);
                if (vmin < v)
                {
                    // The noise passes the threshold but the denoised does not.
                    // This causes flickering when jumping from single-pixel to double-pixel noise.
                    // Instead, in this case, interpolate between the two across the soft threshold,
                    // by clamping to the threshold.
                    if (v > THRES_LOW && vmin < THRES_HIGH)
                    {
                        vmin = max(THRES_LOW, vmin);
                        v = min(THRES_HIGH, v);
                    }

                    v = 0.5f * (vmin + v);
                }
            }

            cLine[i] = v;
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
