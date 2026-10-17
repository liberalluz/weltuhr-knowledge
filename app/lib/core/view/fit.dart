/// 自适应取景：让场景**刚好装进视口**（`B3` 笔 2 修 · 笔 3 前再修）。
///
/// ## 两次都算错的教训
///
/// 1. 第一版按世界**球半径** `√(r² + (φ·h)²)` 算 ⇒ 把一片 60° 的薄楔形当成
///    实心球，按最大对角缩放，内容被缩得很小（实测 1080×600 下横跨仅 50 px）。
/// 2. 若改用**单帧**投影包围盒 ⇒ 场景每帧自转，包围盒随 yaw 变 ⇒ 焦距每帧变
///    ⇒ 画面「呼吸」。
///
/// 现在按 `C-42` 在固定几个 yaw 上各投一次取最大 —— 与帧无关，也不浪费。
/// 屏幕坐标与焦距成正比（`x = worldX · focal / depth`），所以先按基准焦距量出
/// 最大 extent，再线性解出焦距。
library;

import 'dart:math' as math;

import '../constants.dart';
import '../frame/projection.dart';

/// 把 [base] 的场景装进 [viewportWidth] × [viewportHeight]。
///
/// 允许半径 = 视口短边 × [fitViewportRadiusRatio]（`C-38`）。
Camera fitCameraToViewport({
  required List<SceneNode> nodes,
  required List<EdgeSpan> edges,
  required Camera base,
  required double viewportWidth,
  required double viewportHeight,
  double pixelsPerUnit = 1,
}) {
  if (nodes.isEmpty || viewportWidth <= 0 || viewportHeight <= 0) {
    return base;
  }

  const double step = fullTurnRadians / fitYawSamples;
  double maxExtent = 0;
  for (int i = 0; i < fitYawSamples; i++) {
    final Camera probe = Camera(
      yawRadians: i * step,
      pitchRadians: base.pitchRadians,
      distance: base.distance,
      focal: base.focal,
      radialSegments: base.radialSegments,
      sectorCount: base.sectorCount,
      phiHeight: base.phiHeight,
      minDepth: base.minDepth,
    );
    for (final ProjectedNode node
        in projectFrame(nodes: nodes, edges: edges, camera: probe).nodes) {
      maxExtent = math.max(maxExtent, math.max(node.x.abs(), node.y.abs()));
    }
  }
  if (maxExtent <= 0) {
    return base;
  }

  // ⚠️ 目标必须换算到**投影单位**：绘制层还会乘一次 `pixelsPerUnit`
  // （`size.shortestSide × 0.85`）。漏掉这一步会让焦距大出两个数量级 ——
  // 投影后看着正常，屏幕上全在视口外，表现就是「画面全空」。
  final double target =
      math.min(viewportWidth, viewportHeight) *
      fitViewportRadiusRatio /
      (pixelsPerUnit <= 0 ? 1 : pixelsPerUnit);
  final double focal = base.focal * target / maxExtent;
  if ((focal - base.focal).abs() < fitFocalEpsilon) {
    return base;
  }

  return Camera(
    yawRadians: base.yawRadians,
    pitchRadians: base.pitchRadians,
    distance: base.distance,
    focal: focal,
    radialSegments: base.radialSegments,
    sectorCount: base.sectorCount,
    phiHeight: base.phiHeight,
    minDepth: base.minDepth,
  );
}
