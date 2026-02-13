using System;
using System.Linq;
using UnityEngine;

[Serializable]
public struct ComputePassOverride<T>
{
    public Shader shader;
    public string name;
    public T value;
}

[Serializable]
public struct ComputePassSlider
{
    public Shader shader;
    public string name;
    [Range(0f, 1f)] public float value;
}

[ExecuteAlways]
public class ComputePassRendererController : MonoBehaviour
{
    [SerializeField]
    private ComputePassRendererFeature feature;

    public ComputePassOverride<int>[] intOverrides;
    public ComputePassOverride<float>[] floatOverrides;
    public ComputePassOverride<bool>[] boolOverrides;
    public ComputePassSlider[] sliderOverrides;

    public static void Set<T>(ComputePassOverride<T>[] overrides, string name, T value)
    {
        for (var i = 0; i < overrides.Length; i += 1)
        {
            if (overrides[i].name == name)
            {
                overrides[i].value = value;
            }
        }
    }

    public static void Set(ComputePassSlider[] overrides, string name, float value)
    {
        for (var i = 0; i < overrides.Length; i += 1)
        {
            if (overrides[i].name == name)
            {
                overrides[i].value = value;
            }
        }
    }

    void OnRenderObject()
    {
        feature.GetPass().SingleRenderOverride = (shader, props) =>
        {
            SetAll(shader, intOverrides, props.SetInt);
            SetAll(shader, floatOverrides, props.SetFloat);
            SetAll(shader, boolOverrides, (k, v) => props.SetInt(k, v ? 1 : 0));
            foreach (var _ in sliderOverrides.Where(_ => _.shader == shader))
            {
                props.SetFloat(_.name, _.value);
            }
        };
    }

    private void SetAll<T>(Shader shader, ComputePassOverride<T>[] overrides, Action<string, T> setter)
    {
        foreach (var _ in overrides.Where(_ => _.shader == null || _.shader == shader))
        {
            setter(_.name, _.value);
        }
    }
}
