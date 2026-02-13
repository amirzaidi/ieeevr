// Constant defines.
#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
//#define FLT_INF (1.f / 0.f)
#define EPS 0.00001f

#define THRES_LOW 0.25f
#define THRES_HIGH 0.50f
#define THRES (0.5f * (THRES_LOW + THRES_HIGH))

// Macro defines.
#define ZERO_I2 int2(0, 0)
#define ZERO_F4 float4(0.f, 0.f, 0.f, 0.f)
#define ONE_I2 int2(1, 1)
#define ONE_I3 int3(1, 1, 1)
#define ONE_I4 int4(1, 1, 1, 1)
#define ONE_F2 float2(1.f, 1.f)
#define ONE_F3 float3(1.f, 1.f, 1.f)
#define ONE_F4 float4(1.f, 1.f, 1.f, 1.f)
#define ONE_f2 ONE_F2
#define ONE_f3 ONE_F3
#define ONE_f4 ONE_F4

// Position Flags.
#define FLAG_NONE 0.f
#define FLAG_OUT_OF_BOUNDS 1.f
#define FLAG_EXCLUDED 2.f

// Useful macros.
#define FOR(array, var) for (uint var = 0; var < array.Length; var += 1)

// Static memory allocation.
static const int2 COMPASS[4] =
{
    int2(1, 0), // E
    int2(0, 1), // N
    int2(-1, 0), // W
    int2(0, -1) // S
};

static const int2 COMPASS_HALF[4] =
{
    int2(1, 0), // E
    int2(1, 1), // NE
    int2(0, 1), // N
    int2(-1, 1) // NW
};

static const float2 DFT4V[4] =
{
    float2(+1.f, +0.f), // E
    float2(+0.f, +1.f), // N
    float2(-1.f, +0.f), // W
    float2(+0.f, -1.f) // S
};
