# LSA Contours Source Code
This code will be openly published after acceptance.

Getting started:
1. Open the project using Unity Editor version 2023.1.10f1.
2. Load Assets/DemoScene or Assets/BenchScene through the Project browser window in Unity Editor.
3. Press the Play button on the center top of the screen (or Ctrl+P).
4. Double click the top black bar of the Game view to maximize the rendering output.

Switching stylistion method:
- Press the primary or secondary button on an XR controller to switch between modes.
- Alternatively, press one of the following buttons to switch between methods.
- F1: Our base method.
- F2: Our full pipeline.
- F3: Honks method from https://github.com/IronWarrior/UnityOutlineShader/blob/master/Assets/Outline.shader with default parameters.
- F4: Sobel filter on the depth map with a soft threshold at [0.0001, 0.0002].
- F5: Basic shading.

Changing parameters:
- In the hierarchy view, find the "RendererFeatures" object.
- Highlight it, then expand the Override on the Compute Pass Renderer Controller script.
- The 14 parameters shown can be adjusted during runtime.
