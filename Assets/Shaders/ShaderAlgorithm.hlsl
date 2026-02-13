#define NR_DOUBLE_NONE 0
#define NR_DOUBLE_CONTROL 1
#define NR_DOUBLE_CHECK 2

#define PLANE_MIN 50.f
#define PLANE_MAX 150.f

// Symmetric up to sign flip.
float Curvature(float3 controlPos, float3 controlNorm, float3 cPos, float3 cNorm)
{
    /*
    // Find the osculating circle that fits both L and R at the right position and gives those 
    // positions approximately the normal difference they already have.
    float dAngle = acos(clampui(dot(cNorm, controlNorm))); // This is a perfect integration into 2Pi regardless of rasterization.

    // If this were a (discretized) unit-size circle, what should dPos be based on dAngle?
    // Instead of perfectly tracing the circle, draw a straight line between the two positions on the circle.
    float expectedSinValue = 2.f * sin(0.5f * dAngle);

    // Curvature is the rate of change of the angle.
    // Integrating (sum: dPos * dAngle) this over any curve around a manifold should give 2Pi.
    float dPos = length(controlPos - cPos); // Use this to normalize value based on pixel grid size. Loses pixel-based integration property.

    // Compare that with the dPos we found to find the actual circle size.
    // The circle radius is the inverse of the curvature.
    float cv = expectedSinValue / max(EPS, dPos);
    */
    
    // Speed-up by working out formula.
    float cv = length(controlNorm - cNorm) / max(EPS, length(controlPos - cPos));
    
    // Sign is positive for convex surfaces.
    return sign(dot(controlNorm - cNorm, controlPos - cPos)) * cv;
}

#define ABSDOT(a, b) abs(dot(a, b))
float HighestDot(float3 v, float3 a, float3 b)
{
    // Do the cross products point into the same direction?
    // If yes, v falls outside of the arc between a, b.
    // If no, v is inside the arc between a, b, and the dot product is 1.
    return all(a == b) || dot(cross(v, a), cross(v, b)) > 0.f
        ? max(ABSDOT(v, a), ABSDOT(v, b))
        : 1.f;
}

float LowestDot(float3 v, float3 a, float3 b)
{
    // Do the cross products point into the same direction?
    // If yes, ab falls outside of the arc between a, b, so v cannot be 0.
    // If no, ab is inside the arc between a, b, v is outside, and the dot product is 0.
    float3 ab = cross(v, cross(a, b)); // 90deg rotation in-plane.
    return all(a == b) || dot(cross(ab, a), cross(ab, b)) > 0.f
        ? min(ABSDOT(v, a), ABSDOT(v, b))
        : 0.f;
}

float PlanarDeviation(float3 controlPos, float3 controlNorm, float3 cPos, float3 cNorm, float3 checkPos, float3 checkNorm, int nrMode)
{
    float3 dControlPos = controlPos - cPos;
    float3 dCheckPos = checkPos - cPos;
    
    // In case these are not equal distances in screen-space.
    if (nrMode == NR_DOUBLE_CONTROL)
    {
        dControlPos *= 0.5f;
    }
    else if (nrMode == NR_DOUBLE_CHECK)
    {
        dCheckPos *= 0.5f;
    }
    
    float a = LowestDot(dCheckPos, cNorm, checkNorm);
    float b = HighestDot(dControlPos, cNorm, controlNorm);
    float diffPos = a / max(b, EPS);
    return max(0.f, linmapui(diffPos, PLANE_MIN, PLANE_MAX));
}

float CircleDeviation(/* float3 controlPos, float3 controlNorm, */float3 cPos, float3 cNorm, float cCurv, float3 checkPos, float3 checkNorm)
{    
    /*
    // Normal code to handle curves.
    // Unfortunately, breaks at cCurv = 0.
    float circleRadius = 1.f / cCurv;
    float circleRadiusAbs = abs(circleRadius);

    // Implicitly, this is a sphere placed at position circleCenter.
    float3 circleCenter1 = cPos - circleRadius * cNorm;
    float3 circleCenter2 = controlPos - circleRadius * controlNorm;
    float3 circleCenter = 0.5f * (circleCenter1 + circleCenter2);

    // Where should the position be based on the normal?
    float3 checkPosEstimate = circleCenter + circleRadius * checkNorm;

    // Scale deviation by circle radius.
    float diffPosCurv = length(checkPos - checkPosEstimate) / circleRadiusAbs;
    */
    
    // Optimized version that works at cCurv = 0.
    float diffPosCurv = length(cCurv * (checkPos - cPos) - (checkNorm - cNorm));

    // Return this value.
    return diffPosCurv;
}

float2 Contourness(float3 controlPos, float3 controlNorm, float3 cPos, float3 cNorm, float3 checkPos, float3 checkNorm, int nrMode)
{
    // Necessary for shifts between aligned planes.
    float vp = PlanarDeviation(controlPos, controlNorm, cPos, cNorm, checkPos, checkNorm, nrMode);
    
    // Most important one that handles all situations except parallel planes.
    float cCurv = Curvature(controlPos, controlNorm, cPos, cNorm);
    float vc = CircleDeviation(cPos, cNorm, cCurv, checkPos, checkNorm);
    
    // Planar, Curvature.
    return float2(vp, vc);
}
