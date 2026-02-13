using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using System.IO;
using System;
using System.Globalization;
using System.Threading;

namespace LeetProfiling
{
    public class BenchScript : MonoBehaviour
    {
        private const string RECORDER = "Unnamed_ScriptableRenderPass";
        private const int FRAMES = 300;

        private readonly List<long> mMeasurements = new();
        private readonly ControlScript mControl = new();
        private Recorder mRecorder;

        public void Awake()
        {
            var ci = CultureInfo.CreateSpecificCulture("en-US");
            Thread.CurrentThread.CurrentCulture = ci;
            Thread.CurrentThread.CurrentUICulture = ci;
            CultureInfo.DefaultThreadCurrentCulture = ci;
            CultureInfo.DefaultThreadCurrentUICulture = ci;
        }

        public void Start() =>
            Delay(3f);

        private void Delay(float delay) =>
            StartCoroutine(DelayRoutine(delay));

        private IEnumerator DelayRoutine(float delay)
        {
            enabled = false;
            yield return new WaitForSecondsRealtime(delay);
            enabled = true;
        }

        public void Update()
        {
            if (mRecorder == null)
            {
                mRecorder = Recorder.Get(RECORDER);
                mRecorder.enabled = true;
                mMeasurements.Clear();
                Delay(1f);
                return;
            }

            if (mRecorder.gpuElapsedNanoseconds == 0)
            {
                mRecorder = null;
                return;
            }

            mMeasurements.Add(mRecorder.gpuElapsedNanoseconds);
            if (mMeasurements.Count >= FRAMES)
            {
                if (!mControl.RecordMeasurementAndProgress(mMeasurements, GetComponent<DemoScript>()))
                {
                    enabled = false;
                }

                mMeasurements.Clear();
            }
        }

        private class ControlScript
        {
            private static readonly DemoScript.Method[] METHODS =
            {
                DemoScript.Method.Ours,
                DemoScript.Method.OursFull,
                DemoScript.Method.Honks,
                DemoScript.Method.Sobel,
            };

            private static readonly float[] RESOLUTIONS =
            {
                0.25f,
                0.50f,
                0.75f,
                1.00f,
                1.25f,
                1.50f,
                1.75f,
                2.00f,
            };

            private static readonly (DemoScript.Method Method, float Scale)[] CONFIGS =
                RESOLUTIONS.Join(
                    METHODS,
                    _ => true,
                    _ => true,
                    (res, method) => (method, res)
                ).ToArray();

            private const string FILE = "bench-aggregate.csv";

            private int mIndex = -1;
            private float mDefaultScale;

            public bool RecordMeasurementAndProgress(List<long> measurements, DemoScript demo)
            {
                var dir = Directory.GetCurrentDirectory();
                var urp = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;

                if (mIndex < 0)
                {
                    mDefaultScale = urp.renderScale;
                    File.WriteAllLines(
                        $"{dir}/{FILE}",
                        new string[] { "index,method,scale,mean,min,median,max" }
                    );
                }
                else
                {
                    var c = CONFIGS[mIndex];
                    var ms = measurements.Average();
                    var ordered = measurements.OrderBy(_ => _).ToArray();
                    var median = ordered.Length % 2 == 0
                        ? (ordered[ordered.Length / 2 - 1] + ordered[ordered.Length / 2]) / 2
                        : ordered[ordered.Length / 2];

                    Debug.Log($"Finish -- {mIndex}, {c}: {ms / 1000000d}");
                    File.AppendAllLines(
                        $"{dir}/{FILE}",
                        new string[] { $"{mIndex},{c.Method},{c.Scale},{ms},{ordered.First()},{median},{ordered.Last()}" }
                    );
                    File.WriteAllLines(
                        $"{dir}/bench-{mIndex}-{c.Method}-{c.Scale}.csv",
                        measurements.Select(_ => $"{_}")
                    );
                }

                if (++mIndex < CONFIGS.Length)
                {
                    Debug.Log($"Start -- {mIndex}, {CONFIGS[mIndex]}");
                    demo.SetMethod(CONFIGS[mIndex].Method);
                    urp.renderScale = CONFIGS[mIndex].Scale;
                    return true;
                }
                else
                {
                    urp.renderScale = mDefaultScale;
                    return false;
                }
            }
        }
    }
}
