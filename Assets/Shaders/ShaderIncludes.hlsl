// We want all the data.
#define REQUIRE_DEPTH_TEXTURE
#define REQUIRE_NORMAL_TEXTURE
#define _GBUFFER_NORMALS_OCT

// Includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

/*
// Not necessary.
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
#include "Packages/com.unity.shadergraph/Editor/Generation/Targets/Fullscreen/Includes/FullscreenShaderPass.cs.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/Functions.hlsl"
*/

#include "ShaderDefines.hlsl"
#include "ShaderFunctions.hlsl"
#include "ShaderPipeline.hlsl"
