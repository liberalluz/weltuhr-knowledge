/// 绘制表面**按面积封顶**的换算（`C-33` · `ADR-0002` 修订二）。
///
/// 实测结论是成本随**覆盖面积**走（面积 `1.55×` ⇒ 光栅 `2.02×`，`STR` 轮次
/// `R1`），所以「窗口变大」不能让它无限变贵。做法不是缩点，而是**固定绘制
/// 表面**：超过基准窗口后，把画布按面积缩到基准尺寸再放大贴上去。
///
/// 纯数学，不 import `dart:ui` —— 与 `projection.dart` 同一口径，便于单测。
library;

import 'dart:math' as math;

import '../constants.dart';

/// 一次换算的结果。
class ViewportPlan {
  const ViewportPlan({
    required this.surfaceWidth,
    required this.surfaceHeight,
    required this.scale,
  });

  /// 离屏画布的宽（逻辑像素）。**面积不超过** `C-33`。
  final double surfaceWidth;

  /// 离屏画布的高。
  final double surfaceHeight;

  /// 画布 → 窗口的放大倍数。`1` 表示按原尺寸直接画。
  final double scale;

  /// 是否真的降了分辨率（测试与 HUD 都用它判断走到哪条分支）。
  bool get isDownscaled => scale > 1;
}

/// 按窗口尺寸算绘制表面。
///
/// 判据是**面积**而不是任一边：`2560×1080` 与 `1920×1440` 面积相同，
/// 若按宽或高单独判，二者会走到不同分支，而它们的填充成本是一样的。
ViewportPlan planViewport(
  double windowWidth,
  double windowHeight, {
  double benchWidth = frameBenchWidth,
  double benchHeight = frameBenchHeight,
}) {
  final double windowArea = windowWidth * windowHeight;
  final double benchArea = benchWidth * benchHeight;
  if (windowArea <= benchArea || windowArea <= 0) {
    return ViewportPlan(
      surfaceWidth: windowWidth,
      surfaceHeight: windowHeight,
      scale: 1,
    );
  }
  // 等比缩放到基准面积：k = √(基准 / 窗口)。
  final double shrink = math.sqrt(benchArea / windowArea);
  return ViewportPlan(
    surfaceWidth: windowWidth * shrink,
    surfaceHeight: windowHeight * shrink,
    scale: 1 / shrink,
  );
}
