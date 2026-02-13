using System;
using System.Linq;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;

[Serializable]
public struct ComputePassShader
{
    public Shader shader;
    public bool isEnabled;
}

public class ComputePassRendererFeature : ScriptableRendererFeature
{
    private static readonly string TAG = "ComputePassRendererFeature";

    private static readonly string PROP_COLOR_FORMAT = "ColorFormat";
    private static readonly string PROP_GRAPHICS_FORMAT = "GraphicsFormat";

    private static readonly ScriptableRenderPassInput REQUIREMENTS = ScriptableRenderPassInput.Depth
        | ScriptableRenderPassInput.Normal
        | ScriptableRenderPassInput.Color;

    public enum InjectionPoint
    {
        BeforeRenderingTransparents = RenderPassEvent.BeforeRenderingTransparents,
        BeforeRenderingPostProcessing = RenderPassEvent.BeforeRenderingPostProcessing,
        AfterRenderingPostProcessing = RenderPassEvent.AfterRenderingPostProcessing,
    }

    public InjectionPoint injectionPoint = InjectionPoint.AfterRenderingPostProcessing;
    public ComputePassShader[] shaders;

    private Shader[] Shaders => (shaders ?? Array.Empty<ComputePassShader>())
        .Where(_ => _.isEnabled)
        .Select(_ => _.shader)
        .ToArray();

    private readonly ComputePass mComputePass = new();
    private Material[] mMaterials;

    public override void Create()
    {
        mComputePass.renderPassEvent = (RenderPassEvent)injectionPoint;
        mComputePass.ConfigureInput(REQUIREMENTS);
    }

    private static (RenderTextureFormat, GraphicsFormat) ShaderOutput(Shader shader)
    {
        var indexColor = shader == null
            ? -1
            : shader.FindPropertyIndex(PROP_COLOR_FORMAT);

        var indexGraphics = shader == null
            ? -1
            : shader.FindPropertyIndex(PROP_GRAPHICS_FORMAT);

        var colorFormat = indexColor == -1
            ? RenderTextureFormat.ARGBFloat
            : (RenderTextureFormat)shader.GetPropertyDefaultIntValue(indexColor);

        var graphicsFormat = indexGraphics == -1
            ? GraphicsFormat.R32G32B32A32_SFloat
            : (GraphicsFormat)shader.GetPropertyDefaultIntValue(indexGraphics);

        return (colorFormat, graphicsFormat);
    }

    private Shader[] NonNullShaders() =>
        Shaders.Distinct().ToArray();

    private bool ShouldRecreateMaterials(Shader[] nonNullShaders)
    {
        if (mMaterials == null || mMaterials.Length != nonNullShaders.Length)
        {
            return true;
        }

        for (var i = 0; i < nonNullShaders.Length; i += 1)
        {
            if (mMaterials[i].IsDestroyed() || mMaterials[i].shader != nonNullShaders[i])
            {
                return true;
            }
        }

        return false;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var nonNullShaders = NonNullShaders();
        if (ShouldRecreateMaterials(nonNullShaders))
        {
            if (mMaterials != null)
            {
                foreach (var mat in mMaterials)
                {
                    CoreUtils.Destroy(mat);
                }
            }

            mMaterials = nonNullShaders.Select(_ => CoreUtils.CreateEngineMaterial(_)).ToArray();
        }

        if (mMaterials.Length > 0)
        {
            mComputePass.Setup(mMaterials, renderingData);
            renderer.EnqueuePass(mComputePass);
        }
    }

    public ComputePass GetPass() =>
        mComputePass;

    protected override void Dispose(bool disposing) =>
        mComputePass.Dispose();

    public class ComputePass : ScriptableRenderPass
    {
        private readonly ProfilingSampler mProfiling = new(TAG);

        private MaterialPropertyBlock mProps;
        private Material[] mMaterials;
        private RTHandle[] mTextures = new RTHandle[0];

        public Action<Shader, MaterialPropertyBlock> SingleRenderOverride;

        public void Setup(Material[] mat, in RenderingData renderingData)
        {
            mProps ??= new();
            mMaterials = mat;
            if (mat.Length > mTextures.Length)
            {
                Array.Resize(ref mTextures, mat.Length);
            }

            // Reset all textures to the screenspace size.
            var texFormat = renderingData.cameraData.cameraTargetDescriptor;
            texFormat.depthBufferBits = (int)DepthBits.None;

            for (var i = 0; i < mat.Length; i += 1)
            {
                if (i > 0)
                {
                    var (colorFormat, graphicsFormat) = ShaderOutput(mat[i - 1].shader);
                    texFormat.colorFormat = colorFormat;
                    texFormat.graphicsFormat = graphicsFormat;
                }

                RenderingUtils.ReAllocateIfNeeded(ref mTextures[i], texFormat, name: $"ComputePass-{i}");
            }
        }

        public void Dispose()
        {
            foreach (var tex in mTextures)
            {
                tex?.Release();
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            var cmd = CommandBufferPool.Get(mProfiling.name);

            if (cameraData.isPreviewCamera)
            {
                return;
            }

            if (cmd == null || profilingSampler == null)
            {
                Debug.LogWarningFormat($"Null: {cmd == null} {profilingSampler == null}", GetType().Name);
                return;
            }

            using (new UnityEngine.Rendering.ProfilingScope(cmd, profilingSampler))
            {
                // Comment by Unity developers:
                // For some reason BlitCameraTexture(cmd, dest, dest) scenario (as with before transparents effects) blitter fails to correctly blit the data
                // Sometimes it copies only one effect out of two, sometimes second, sometimes data is invalid (as if sampling failed?).
                // Adding RTHandle in between solves this issue.
                var renderer = (UniversalRenderer)cameraData.renderer;
                var source = renderer.cameraColorTargetHandle;

                // Set camera position.
                var cam = cameraData.camera;
                var c = cam.transform.position;
                var f = cam.transform.forward;
                var l = c;
                var r = c;

                var lvp = cam.projectionMatrix * cam.worldToCameraMatrix;
                var rvp = lvp;

                if (XRSettings.enabled)
                {
                    var lv = cam.GetStereoViewMatrix(Camera.StereoscopicEye.Left);
                    var rv = cam.GetStereoViewMatrix(Camera.StereoscopicEye.Right);
                    var lp = cam.GetStereoNonJitteredProjectionMatrix(Camera.StereoscopicEye.Left);
                    var rp = cam.GetStereoNonJitteredProjectionMatrix(Camera.StereoscopicEye.Right);

                    l = lv.inverse.GetColumn(3);
                    r = rv.inverse.GetColumn(3);
                    lvp = lp * lv;
                    rvp = rp * rv;
                }

                mProps.Clear();
                mProps.SetVectorArray("CameraPos", new Vector4[] { l, r, c });
                mProps.SetVector("CameraForward", new(f.x, f.y, f.z));
                mProps.SetMatrixArray("VP", new[] { lvp, rvp });
                
                float fogStart = float.MaxValue;
                float fogEnd = float.MaxValue;
                Color fogColor = Color.white;
                if (RenderSettings.fog && RenderSettings.fogMode == FogMode.Linear)
                {
                    fogStart = RenderSettings.fogStartDistance;
                    fogEnd = RenderSettings.fogEndDistance;
                    fogColor = RenderSettings.fogColor;
                }

                mProps.SetFloat("FogStart", fogStart);
                mProps.SetFloat("FogEnd", fogEnd);
                mProps.SetVector("FogColor", fogColor);

                // From source to copy, using a direct blit.
                Blitter.BlitCameraTexture(cmd, source, mTextures[0]);
                var gbuffers = ComputePassRendererReflection.GetGBuffers(renderer);

                // Set all known textures, even those we have not rendered to yet.
                for (var i = 0; i < mMaterials.Length; i += 1)
                {
                    // The output of Unity's pipeline.
                    mMaterials[i].SetTexture("Blit", mTextures[0]);
                    for (var j = 0; j < gbuffers.Length; j += 1)
                    {
                        if (gbuffers[j]?.rt != null)
                        {
                            mMaterials[i].SetTexture($"BlitGBuffer{j}", gbuffers[j]);
                        }
                    }

                    // The previous stage.
                    mMaterials[i].SetTexture("Prev", mTextures[i]);

                    // Allow binding every pass by name.
                    for (var j = 0; j < mMaterials.Length - 1; j += 1)
                    {
                        mMaterials[i].SetTexture(mMaterials[j].shader.name, mTextures[j + 1]);
                    }

                    // Setup all variables.
                    SingleRenderOverride?.Invoke(mMaterials[i].shader, mProps);

                    // Render.
                    CoreUtils.SetRenderTarget(cmd, (i == mMaterials.Length - 1) ? source : mTextures[i + 1]);
                    CoreUtils.DrawFullScreen(cmd, mMaterials[i], mProps, 0);
                }
            }
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            SingleRenderOverride = null;
        }
    }
}
