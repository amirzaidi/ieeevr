// Skip opposite if in single draw mode.
#ifdef UNITY_STEREO_INSTANCING_ENABLED
#define SLICE_ARRAY_OPPOSITE_INDEX (1 - SLICE_ARRAY_INDEX)
#define TEX_GLOBAL_FUNC(tex) float4 tex##Global(int2 xyp) { return LOAD_TEXTURE2D_ARRAY_LOD(tex, unsign2(xyp), SLICE_ARRAY_INDEX, 0); }
#define TEX_GLOBAL_OPPOSITE_FUNC(tex) float4 tex##GlobalOpposite(int2 xyp) { return LOAD_TEXTURE2D_ARRAY_LOD(tex, unsign2(xyp), SLICE_ARRAY_OPPOSITE_INDEX, 0); }
#define TEX_OFFSET_FUNC(tex) float4 tex##Offset(int2 dxy) { return tex##Global(xy + dxy); }
#define TEX_OFFSET_OPPOSITE_FUNC(tex) float4 tex##OffsetOpposite(int2 dxy) { return tex##GlobalOpposite(xy + dxy); }
#else
#define SLICE_ARRAY_OPPOSITE_INDEX SLICE_ARRAY_INDEX
#define TEX_GLOBAL_FUNC(tex) float4 tex##Global(int2 xyp) { return LOAD_TEXTURE2D_LOD(tex, unsign2(xyp), 0); }
#define TEX_GLOBAL_OPPOSITE_FUNC(tex) float4 tex##GlobalOpposite(int2 xyp) { return LOAD_TEXTURE2D_LOD(tex, unsign2(xyp), 0); }
#define TEX_OFFSET_FUNC(tex) float4 tex##Offset(int2 dxy) { return tex##Global(xy + dxy); }
#define TEX_OFFSET_OPPOSITE_FUNC(tex) float4 tex##OffsetOpposite(int2 dxy) { return tex##GlobalOpposite(xy + dxy); }
#endif

#define TEX(tex) TEXTURE2D_X(tex); TEX_GLOBAL_FUNC(tex); TEX_GLOBAL_OPPOSITE_FUNC(tex); TEX_OFFSET_FUNC(tex); TEX_OFFSET_OPPOSITE_FUNC(tex);

// Stereo Code.
uniform float4 CameraPos[3];
uniform float4 CameraForward; // To-Do.
#define SOURCE_CAMERA_POS (CameraPos[SLICE_ARRAY_INDEX]).xyz
#define CENTER_CAMERA_POS (CameraPos[2]).xyz
#define TARGET_CAMERA_POS (CameraPos[SLICE_ARRAY_OPPOSITE_INDEX]).xyz
uniform float4x4 VP[2];
#define SOURCE_VP VP[SLICE_ARRAY_INDEX]
#define TARGET_VP VP[SLICE_ARRAY_OPPOSITE_INDEX]
uniform float FogStart;
uniform float FogEnd;
uniform float4 FogColor;

// Global variables.
float2 uv;
int2 xy;

float DepthOffset(int2 dxy)
{
    return LoadSceneDepth(unsign2(xy + dxy));
}

float3 NormOffset(int2 dxy)
{
    return LoadSceneNormals(unsign2(xy + dxy));
}

// For now we always work with 4 channels for arbitrary processing.
TEX(Blit);
TEX(BlitGBuffer0);
TEX(BlitGBuffer1);
TEX(BlitGBuffer2);
TEX(BlitGBuffer3);
TEX(Prev);

bool IsSpecular(int2 offset)
{
    half4 gbuffer0 = BlitGBuffer0Offset(offset);
    uint materialFlags = UnpackMaterialFlags(gbuffer0.a);
    //bool smoothnessZero = BlitGBuffer2Offset(offset).w == 0.f; // Terrain has bugged normals, so we exclude it.
    return (materialFlags & 0x8) != 0; // || smoothnessZero;
}

// Input.
struct Attributes
{
    uint vertexID : VERTEXID_SEMANTIC;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Intermediate.
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float4 texCoord0 : INTERP0;
    UNITY_VERTEX_OUTPUT_STEREO
};

float4 Main();

Varyings vert(Attributes v)
{
    float2 uv = float2((v.vertexID << 1) & 2, v.vertexID & 2);
    float4 pos = float4(uv * 2.0 - 1.0, UNITY_NEAR_CLIP_VALUE, 1.0);

    Varyings output = (Varyings) 0;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
    output.positionCS = pos;
    output.texCoord0.xy = float2(uv.x, 1.f - uv.y);
    return output;
}

float4 frag(Varyings unpacked) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);
    
    uv = unpacked.texCoord0.xy;
    xy = int2(uv * _ScreenSize.xy);
    return Main();
}
