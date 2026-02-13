Shader "Fade"
{
    Properties
    {
        StrengthFade("", Float) = 1.0
        ColorFormat("", Integer) = 14 // RenderTextureFormat.RFloat
        GraphicsFormat("", Integer) = 5 // GraphicsFormat.R8_UNorm
    }

    HLSLINCLUDE
    #include "ShaderIncludes.hlsl"

    uniform float StrengthFade;

    TEX(Pos);

    float ContourFade(float3 cPos, float3 cNorm)
    {
#ifndef UNITY_STEREO_INSTANCING_ENABLED
        return 0.f;
#endif

        float3 SourceCameraPos = SOURCE_CAMERA_POS;
        float3 CenterCameraPos = CENTER_CAMERA_POS;
        float3 TargetCameraPos = TARGET_CAMERA_POS;

        // Second, the soft contour fade.
        float3 cPosToCenterCam = normalize(CenterCameraPos - cPos);
        //float3 cPosCamPlane = cross(cPosToCenterCam, cNorm);
        float3 cPosToCenterCamOrtho = normalize(Orthogonalize(cPosToCenterCam, cNorm));
        float maxCamDist = length(SourceCameraPos - CenterCameraPos);

        // We want to find where cPosToCenterCamOrtho intersects the plane containing all cameras.
        // Intersect: ((cPos + a * cPosToCenterCamOrtho) - CenterCameraPos) . Forward = 0
        // (cPos - CenterCameraPos + a * cPosToCenterCamOrtho) . Forward = 0
        // a * cPosToCenterCamOrtho . Forward = (CenterCameraPos - cPos) . Forward
        // a = ((CenterCameraPos - cPos) . Forward) / (cPosToCenterCamOrtho . Forward)
        float3 cAtPlane;
        if (dot(cPosToCenterCamOrtho, CameraForward.xyz) > EPS)
        {
            float a = dot(CenterCameraPos - cPos, CameraForward.xyz) / dot(cPosToCenterCamOrtho, CameraForward.xyz);
            cAtPlane = cPos + a * cPosToCenterCamOrtho;

            if (length(cAtPlane - CenterCameraPos) > maxCamDist)
            {
                // If the intersection is outside the circle bounds, translate it to exactly the bounds.
                cAtPlane = CenterCameraPos + maxCamDist * normalize(cAtPlane - CenterCameraPos);
            }
        }
        else
        {
            // Our normal is perpendicular to the plane, so walk along normal.
            cAtPlane = CenterCameraPos + maxCamDist * cPosToCenterCamOrtho;
        }

        // When angleNormCameraRing is 1, there is a camera angle where this point is either a contour or back-face.
        // That means that this point should always be black if and only if angleNormCameraRing is 1.
        // An angleNormCameraRing close to 1 means there is a camera where this point is almost a contour.
        float angleNormCameraRing = acos(clampui(dot(cNorm, normalize(cAtPlane - cPos)))) / (0.5f * PI);

        // Guess the angle between viewpoints by making simplification of infinitely small object.
        float cameraRingAngle = acos(clampui(dot(normalize(SourceCameraPos - cPos), normalize(TargetCameraPos - cPos)))) / (0.5f * PI);
        
        // Artificially increase the effect by 75%, so we have 175% fade coverage compared to 100% between two contours.
        const float cameraRingAngleMult = 1.75f;
        cameraRingAngle = cameraRingAngleMult * cameraRingAngle;
        
        // Upper bound the angle to 30deg.
        const float cameraRingAngleMax = 30.f / 90.f;
        cameraRingAngle = min(cameraRingAngle, cameraRingAngleMax);

        // Adaptively vary the threshold based on the relative angle to the camera ring sides.
        float angleNormCameraRingZero = 1.f - cameraRingAngle;
        float angleNormCameraRingOne = 1.f - 0.25f * cameraRingAngle;
        float res = clampui(linmapui(angleNormCameraRing, angleNormCameraRingZero, angleNormCameraRingOne));

        // Smoothly fade.
        res = smoothmapui(res);

        // Finally, return.
        return res;
    }

    float4 Main()
    {
        if (StrengthFade == 0.f || IsSpecular(ZERO_I2))
        {
            return ZERO_F4;
        }

        float3 cPos = PosOffset(ZERO_I2).xyz;
        float fadeMax = 0.f;
        if (!IsNaN(cPos.x))
        {
            float fadeInt = 0.f;

            FOR(COMPASS_HALF, i)
            {
                int2 mvi = COMPASS_HALF[i];

                float3 lNorm = NormOffset(-mvi);
                float3 rNorm = NormOffset(+mvi);

                fadeInt = max(fadeInt, length(lNorm - rNorm));
            }

            if (fadeInt > 0.f)
            {
                fadeMax = clampui(linmapui(fadeInt, 0.f, EPS))
                    * ContourFade(cPos, NormOffset(ZERO_I2));
            }
        }

        return float4(StrengthFade * saturate(fadeMax), 0.f, 0.f, 0.f);
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
