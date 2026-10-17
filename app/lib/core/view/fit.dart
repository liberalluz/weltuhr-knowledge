/// 自适应取景：让场景**刚好装进视口**（`B3` 笔 2 修）。
///
/// 起因是实测反馈：`1962×1109` 窗口下最下一排点被切掉，同时整团点又缩在
/// 中间偏下一小块 —— 说明写死的 `distance` / `focal` 两头都不对。
///
/// ## 为什么按世界坐标算，不按投影后的包围盒算
///
/// 场景每帧都在自转，投影后的包围盒随 yaw 变化 ⇒ 每帧算出来的 `focal`
/// 都不一样 ⇒ 画面会「呼吸」。改用**旋转不变**的世界半径：
/// `R = √(r² + (φ01 · phiHeight)²)`，它与 yaw 无关，pitch 只会让投影变小。
///
/// 屏幕上一点到中心的距离 ≈ `focal · R / distance`，令它等于允许半径即可解出
/// `focal`。**只动 `focal` 不动 `distance`**：距离变了透视强度就变，
/// 同一个空间在不同窗口尺寸下会看到不同的近大远小。
library;

import 'dart:math' as math;

import '../constants.dart';
import '../frame/projection.dart';

/// 把 [base] 的焦距调到「场景世界半径恰好占满 [viewportWidth] × [viewportHeight]
/// 短边的 `fitViewportRadiusRatio`」。
///
/// 对同一份场景与同一视口，结果**稳定**（不随自转变化）。
Camera fitCameraToViewport({
  required List<SceneNode> nodes,
  required List<EdgeSpan> edges,
  required Camera base,
  required double viewportWidth,
  required double viewportHeight,
}) {
  if (nodes.isEmpty || viewportWidth <= 0 || viewportHeight <= 0) {
    return base;
  }

  double radius = 0;
  for (final SceneNode node in nodes) {
    final double height = node.phiFraction01 * base.phiHeight;
    final double distance = math.sqrt(
      node.radial01 * node.radial01 + height * height,
    );
    if (distance > radius) {
      radius = distance;
    }
  }
  if (radius <= 0) {
    return base;
  }

  final double target =
      math.min(viewportWidth, viewportHeight) * fitViewportRadiusRatio;
  final double focal = target * base.distance / radius;
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
