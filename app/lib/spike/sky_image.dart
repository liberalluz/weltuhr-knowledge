/// 运行期画一张等距柱状投影（equirect）星空图。
///
/// **不落盘、不入库** —— `ADR-0006` 决策 4 要求天球贴图是构建产物。这里
/// 连构建期产物都不需要：spike 要验的是「这台机器这套引擎能不能跑」，图
/// 画在内存里直接交给 `EnvironmentMap.fromUIImages`，你那边跑之前不必先
/// 执行任何脚本。
///
/// 真星空由下一笔用 Yale BSC5 星表烘焙，那张图换进来时只换数据来源，这个
/// 函数签名不变。
library;

import 'dart:math';
import 'dart:ui' as ui;

/// 画一张 [width]×[height] 的星空全景图。
///
/// 星点按**幂律亮度分布**撒：绝大多数极暗，少数中等，极少数很亮。真实星
/// 空看上去就是这个比例 —— 均匀撒点会像噪点，不像星。
Future<ui.Image> paintSkyImage({
  int width = 2048,
  int height = 1024,
  int starCount = 20000,
  int brightCount = 320,
  int seed = 20261030,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final double w = width.toDouble();
  final double h = height.toDouble();

  // 底色：极暗的蓝黑，天顶略亮、地平更暗。真实夜空不是纯黑 —— 气辉与散射
  // 撑起那一层底光，压到 #000 反而假。这里只做观感，不做物理。
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(0, h),
        const <ui.Color>[
          ui.Color.fromARGB(255, 4, 6, 14),
          ui.Color.fromARGB(255, 9, 11, 20),
          ui.Color.fromARGB(255, 2, 3, 8),
        ],
        const <double>[0.0, 0.58, 1.0],
      ),
  );

  final Random rng = Random(seed);

  // 一条极淡的斜带，模拟银河。位置与宽度都是随手定的，只为让「一眼看上去
  // 像夜空」成立 —— 真银河的走向要等星表烘焙那一笔才有意义。
  canvas.drawRect(
    ui.Rect.fromLTWH(0, h * 0.28, w, h * 0.22),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, h * 0.28),
        ui.Offset(0, h * 0.5),
        const <ui.Color>[
          ui.Color.fromARGB(0, 40, 46, 70),
          ui.Color.fromARGB(255, 16, 20, 34),
          ui.Color.fromARGB(0, 40, 46, 70),
        ],
        const <double>[0.0, 0.5, 1.0],
      ),
  );

  // 暗星：一次 `drawPoints` 批量画完。两万次 `drawCircle` 会在这个尺寸上慢
  // 到能感觉出来，而点模式对一两个像素的星本来就更合适。
  final List<ui.Offset> dims = <ui.Offset>[];
  for (int i = 0; i < starCount; i++) {
    dims.add(ui.Offset(rng.nextDouble() * w, rng.nextDouble() * h));
  }
  canvas.drawPoints(
    ui.PointMode.points,
    dims,
    ui.Paint()
      ..color = const ui.Color.fromARGB(255, 208, 216, 240)
      ..strokeWidth = 1.0
      ..strokeCap = ui.StrokeCap.round,
  );

  // 亮星：幂律取亮度（3 次方让分布明显向暗端压），再按亮度定半径与光晕。
  // 颜色走色温：冷白偏多、黄白次之、橙红少数 —— 与真实恒星的色指数分布同向。
  for (int i = 0; i < brightCount; i++) {
    final double u = rng.nextDouble();
    final double lum = u * u * u;
    final ui.Offset center = ui.Offset(
      rng.nextDouble() * w,
      rng.nextDouble() * h,
    );
    final double radius = 0.7 + lum * 2.4;

    final double temp = rng.nextDouble();
    final ui.Color core;
    if (temp < 0.55) {
      core = const ui.Color.fromARGB(255, 226, 236, 255);
    } else if (temp < 0.85) {
      core = const ui.Color.fromARGB(255, 255, 248, 226);
    } else {
      core = const ui.Color.fromARGB(255, 255, 210, 170);
    }

    // 光晕：同色低透明度的大圆。这张图本身是 sRGB 的，bloom 若要吃亮度
    // 阈值，光晕得在这里就画出来 —— 贴图进场景前的亮度是它自己。
    canvas.drawCircle(
      center,
      radius * 3.2,
      ui.Paint()
        ..color = core.withValues(alpha: 0.10 + lum * 0.12)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()..color = core.withValues(alpha: 0.55 + lum * 0.45),
    );
  }

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}
