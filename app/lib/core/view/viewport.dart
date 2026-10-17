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
///
/// ## 为什么要吃 `devicePixelRatio`
///
/// `C-33` 的基准是「`1920×1080` 客户区，**100% 缩放**」—— 那句话里的「100% 缩放」
/// 才是关键：光栅化按**物理像素**算，`1920×1080` 逻辑窗口在 200% 缩放的屏幕上
/// 是 `3840×2160` 物理像素，成本已是基准的 4 倍。只看逻辑尺寸的话，Retina /
/// 高分屏上这条封顶**完全不起作用**，而画面上一切正常 —— 只有帧率掉下去。
///
/// 所以封顶按物理面积判：`w · h · dpr²` 对 `C-33` 的物理面积。
/// 返回值仍是**逻辑像素**（绘制表面的逻辑尺寸），`scale` 仍是「窗口逻辑尺寸 /
/// 画布逻辑尺寸」—— 缩放由合成层完成，与 dpr 无关。
ViewportPlan planViewport(
  double windowWidth,
  double windowHeight, {
  double devicePixelRatio = 1,
  double benchWidth = frameBenchWidth,
  double benchHeight = frameBenchHeight,
}) {
  // dpr 非法（0 / 负数 / NaN）按 1 处理：宁可少缩，也不要让 surface 变成 0 或 NaN
  // —— 那种情况下画布整块消失，而报错信息里只会写「画不出来」。
  final double dpr = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1;
  final double windowArea = windowWidth * windowHeight * dpr * dpr;
  // `C-33` 是 100% 缩放下的尺寸，故基准面积不乘 dpr。
  final double benchArea = benchWidth * benchHeight;
  if (windowArea <= benchArea || windowArea <= 0) {
    return ViewportPlan(
      surfaceWidth: windowWidth,
      surfaceHeight: windowHeight,
      scale: 1,
    );
  }
  // 等比缩到基准面积：k = √(基准 / 窗口物理面积)。
  final double shrink = math.sqrt(benchArea / windowArea);
  return ViewportPlan(
    surfaceWidth: windowWidth * shrink,
    surfaceHeight: windowHeight * shrink,
    scale: 1 / shrink,
  );
}
