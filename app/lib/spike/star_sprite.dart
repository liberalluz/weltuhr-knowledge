/// 星点光斑的纹理：**运行期画，不落盘**。
///
/// 笔 1 的星点是 `SpriteMaterial()` 不带纹理，于是每颗星渲染成一个**方块**
/// —— 靠 bloom 把边缘糊掉才勉强像圆的，换个亮度就露馅。这里改用一张径向
/// 渐变图：中心不透明、向外平滑掉到全透明，加性混合后就是一颗圆形光斑。
///
/// 为什么不放一张 PNG 进仓：天球贴图与星点贴图都属 `ADR-0006` 决策 4 的
/// 「构建产物」，那张决策的判据是不入库。而 `Texture2D.fromImage` 收的是
/// 运行期 `ui.Image`，画完直接交给 GPU，连临时文件都不需要 —— 这条路径让
/// 「不入库」不是靠纪律守，而是**没有可入库的东西**。
library;

import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart' as fs;

/// 光斑贴图的边长（像素）。64 足够：屏上一颗星通常只占几像素，光晕靠 bloom
/// 再放大一轮，再高的分辨率看不出来，只多占显存。
const int kStarSpritePixels = 64;

/// 光斑由中心到边缘的透明度台阶。
///
/// 四档而不是两档（不透明 → 透明）：真实星点的边缘不是线性衰减，是接近高斯
/// 的拖尾。两档渐变出来仍能看出一个硬芯，四档加 bloom 才连成一片。
const List<double> _kGlowStops = <double>[0.0, 0.22, 0.55, 1.0];
const List<int> _kGlowAlphas = <int>[255, 200, 70, 0];

/// 生成一颗星的光斑纹理。
///
/// 必须在 `Scene.initializeStaticResources()` **之后**调用 —— 它要拿 GPU
/// 上下文上传纹理，之前调用会失败。
Future<fs.Texture2D> buildStarSpriteTexture({
  int pixels = kStarSpritePixels,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final double half = pixels / 2;
  final ui.Offset center = ui.Offset(half, half);

  canvas.drawRect(
    ui.Rect.fromCircle(center: center, radius: half),
    ui.Paint()
      ..shader = ui.Gradient.radial(center, half, <ui.Color>[
        for (final int alpha in _kGlowAlphas)
          ui.Color.fromARGB(alpha, 255, 255, 255),
      ], _kGlowStops),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(pixels, pixels);
  picture.dispose();
  try {
    return await fs.Texture2D.fromImage(image);
  } finally {
    // `fromImage` 已经把像素读回给 GPU，图像对象在这里就没有用了。
    image.dispose();
  }
}

/// 星点材质：加性混合 + 上面那张光斑图。
///
/// 加性而非 alpha：星是**发光体**，它只会让背后的天空更亮，永远不会更暗。
/// 副产物是加性混合与绘制顺序无关，所以 9,096 颗星不需要深度排序。
fs.SpriteMaterial buildStarMaterial(fs.Texture2D texture) {
  return fs.SpriteMaterial(colorTexture: texture)
    ..blendMode = fs.SpriteBlendMode.additive;
}
