float4 padf3(float3 xyz)
{
    return float4(xyz.x, xyz.y, xyz.z, 0.f);
}

float3 ftof3(float v)
{
    return float3(v, v, v);
}

#define LERP(T) T lerp(T x, T y, float a) { return (1.f - a) * x + a * y; }
LERP(float);
LERP(float3);
LERP(float4);

uint2 unsign2(int2 xy)
{
    return uint2(xy.x, xy.y);
}

// Clamps on the unit interval [0, 1].
float clampui(float v)
{
    return saturate(v);
}

// Maps from [fromA, fromB] to the unit interval [0, 1].
float linmapui(float v, float fromA, float fromB)
{
    return (v - fromA) / (fromB - fromA);
}

// Maps from [fromA, fromB] to [toA, toB].
float linmap(float v, float fromA, float fromB, float toA, float toB)
{
    return toA + (toB - toA) * linmapui(v, fromA, fromB);
}

// Makes derivative 0 at v=0 and v=1.
float smoothmapui(float v)
{
    return 0.5f - 0.5f * cos(PI * v);
}

float Angle(float2 xy)
{
    return xy.x == 0.f
        ? sign(xy.y) * 0.5f * PI
        : atan2(xy.y, xy.x);
}

// Finds the best fit for [cos(pi/2 * a) + b].
float3 DFT4(float4 v)
{
    // DC, Cos, Sin.
    float DC = v[0] + v[1] + v[2] + v[3];
    float2 AC = float2(0.f, 0.f);
    FOR(DFT4V, i)
    {
        // We wind 180deg data around 360deg FFT due to circularity.
        AC += DFT4V[i] * v[i];
    }

    // x0.25 to compensate for 4 samples, second part x2 to add second conjugate (4th DFT4 coefficient).
    DC *= 0.25f;
    AC *= 0.5f;

    // Convert to DC, AC-Amp, AC-Phase.
    float ACAmp = length(AC);
    float ACPhase = Angle(AC);
    return float3(DC, ACAmp, ACPhase);
}

float DFTMaxVal(float3 curv)
{
    float DC = curv.x;
    float ACAmp = curv.y;
    return DC + ACAmp;
}

float DFT4MaxVal(float4 x)
{
    float v = max(max(x[0], x[1]), max(x[2], x[3]));
    //v = max(x, DFTMaxVal(DFT4(x)));
    return v;
}

bool IsBoundary(int2 xy, int bound)
{
    int x = xy.x;
    int y = xy.y;
    
    return x < bound
        || y < bound
        || x >= _ScreenSize.x - bound
        || y >= _ScreenSize.y - bound;
}

bool IsBoundary(int2 xy)
{
    return IsBoundary(xy, 1);
}

float MaxF4(float4 v)
{
    return max(max(v.x, v.y), max(v.z, v.w));
}

float4 ArrayToVec(float array[4])
{
    return float4(array[0], array[1], array[2], array[3]);
}

float3 UnscaledGaussian(float3 d, float3 s)
{
    float3 interm = d / s;
    return exp(-0.5f * interm * interm);
}

float3 UnscaledGaussian(float3 d, float s)
{
    return UnscaledGaussian(d, float3(s, s, s));
}

float UnscaledGaussian(float d, float s)
{
    float interm = d / s;
    return exp(-0.5f * interm * interm);
}

float3 Project(float3 v, float3 onto)
{
    // Note: Only works if onto is unit length.
    return onto * dot(v, onto);
}

float3 Orthogonalize(float3 v, float3 other)
{
    // Project v (arbitrary length) onto other (unit length),
    // then remove that component.
    return v - Project(v, other);
}

// Find the unit vector orthogonal to two input vectors.
float3 OrthogonalUnit(float3 v1, float3 v2)
{
    return normalize(cross(v1, v2));
}

// Orthogonalize v1 to v2, then re-normalize.
float3 OrthogonalizeUnit(float3 v1, float3 v2)
{
    return normalize(lerp(Orthogonalize(v1, v2), v1, EPS));
}

bool IsPlanar(float3 n1, float3 n2)
{
    return dot(n1, n2) > 1.f - EPS;
}

float4x4 mul(float4x4 A, float4x4 B)
{
    // A * B = (B^T * A^T)^T
    float4x4 AT, BT, MT;
    AT = transpose(A);
    BT = transpose(B);
    for (int i = 0; i < 4; i += 1)
    {
        MT[i] = mul(BT[i], AT);
    }
    return transpose(MT);
}

float det(float4x4 M)
{
    return determinant(M);
}

float4x4 id(float d)
{
    const float z = 0.f;
    return float4x4(
        d, z, z, z,
        z, d, z, z,
        z, z, d, z,
        z, z, z, d
    );
}
