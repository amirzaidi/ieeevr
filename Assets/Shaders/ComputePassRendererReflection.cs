using System.Reflection;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

class ComputePassRendererReflection
{
    private static readonly BindingFlags REFLECTION_FLAGS = BindingFlags.NonPublic | BindingFlags.Instance;
    private static readonly FieldInfo DEFERRED_LIGHTS_GETTER = typeof(UniversalRenderer).GetField(
        "m_DeferredLights",
        REFLECTION_FLAGS
    );

    internal static RTHandle[] GetGBuffers(UniversalRenderer renderer)
    {
        var deferredLights = DEFERRED_LIGHTS_GETTER.GetValue(renderer);
        var gBufferRTsGetter = deferredLights.GetType().GetField("GbufferRTHandles", REFLECTION_FLAGS);
        return gBufferRTsGetter.GetValue(deferredLights) as RTHandle[];
    }
}
