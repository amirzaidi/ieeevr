using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using Unity.XR.MockHMD;
using UnityEngine.XR.Management;
using UnityEngine.InputSystem;
using TMPro;

public class DemoScript : MonoBehaviour
{
    public enum Method
    {
        Ours = 0,
        OursFull = 1,
        Honks = 2,
        Sobel = 3,
        Shading = 4,
    }

    private string[] METHODS = new string[]
    {
        "Ours (Base)",
        "Ours (Full)",
        "Honks",
        "Sobel",
        "Shading",
    };

    [SerializeField]
    private ComputePassRendererController rendererController;

    [SerializeField]
    private Method method = Method.OursFull;

    private readonly Queue<float> mFrametimes = new();
    private double mTotalFrametime;

    [SerializeField]
    private InputActionProperty PrevButtonAction;

    [SerializeField]
    private InputActionProperty NextButtonAction;

    [SerializeField]
    private TMP_Text mText;

    void Awake()
    {
        if (enabled)
        {
            var loader = XRGeneralSettings.Instance.Manager.activeLoader;
            var xrEnabled = loader != null && loader is not MockHMDLoader;
            if (!xrEnabled)
            {
                Application.Quit();
            }
        }
    }

    void OnEnable()
    {
        PrevButtonAction.action?.Enable();
        NextButtonAction.action?.Enable();
    }

    void OnDisable()
    {
        PrevButtonAction.action?.Disable();
        NextButtonAction.action?.Disable();
    }

    void Start() =>
        SetParams();

    public void SetMethod(Method method)
    {
        this.method = method;
        SetParams();
    }

    private void SetParams()
    {
        mText.text = "Method: " + METHODS[(int)method];

        // Bypass everything.
        if (method == Method.Shading)
        {
            ComputePassRendererController.Set(rendererController.sliderOverrides, "Strength", 0f);
            return;
        }

        // Always.
        ComputePassRendererController.Set(rendererController.sliderOverrides, "StrengthToon", 1f);
        ComputePassRendererController.Set(rendererController.sliderOverrides, "Strength", 1f);
        ComputePassRendererController.Set(rendererController.boolOverrides, "LineFog", true);

        // Only on Sobel.
        ComputePassRendererController.Set(rendererController.boolOverrides, "BPassthrough", method == Method.Sobel);

        // Only on Honks.
        ComputePassRendererController.Set(rendererController.boolOverrides, "BPassthroughImproved", method == Method.Honks);

        // Only on Ours with improvements.
        var oursFull = method == Method.OursFull;
        ComputePassRendererController.Set(rendererController.boolOverrides, "BNoiseReduce", oursFull);
        ComputePassRendererController.Set(rendererController.boolOverrides, "BReproj", oursFull);
        ComputePassRendererController.Set(rendererController.sliderOverrides, "StrengthFade", oursFull ? 1f : 0f);
        ComputePassRendererController.Set(rendererController.sliderOverrides, "StrengthLM", (oursFull || method == Method.Sobel) ? 1f : 0.5f);
    }

    void Update()
    {
        for (var i = 0; i < 5; i += 1)
        {
            if (Input.GetKeyDown(KeyCode.F1 + i))
            {
                mFrametimes.Clear();
                mTotalFrametime = 0.0;

                SetMethod((Method)i);
            }
        }

        if (PrevButtonAction.action?.WasPressedThisFrame() ?? false)
        {
            SetMethod((Method)(((int)method + 4) % 5));
        }

        if (NextButtonAction.action?.WasPressedThisFrame() ?? false)
        {
            SetMethod((Method)(((int)method + 1) % 5));
        }

        var dt = Time.deltaTime;
        mFrametimes.Enqueue(dt);
        mTotalFrametime += dt;
        if (mTotalFrametime >= 10.0)
        {
            static float Sqr(float x) =>
                x * x;

            var set = mFrametimes.ToArray();
            var sum = set.Sum();
            var count = set.Length;
            var mean = sum / count;
            var stddev = Mathf.Sqrt(set.Sum(_ => Sqr(_ - mean)) / (count - 1));

            var urp = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            Debug.Log($"Frame time at scale={urp.renderScale}: total={mTotalFrametime} frames={count} mean={mean} stddev={stddev}");

            mFrametimes.Clear();
            mTotalFrametime = 0.0;
        }
    }
}
