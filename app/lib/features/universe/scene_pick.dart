/// 宇宙里的点击拾取（`SPEC-VIEW-014` 第一个入口：宇宙点星）。
///
/// 这一层只做一件事：把「屏幕上的一个点」翻译成「哪一个节点」。装配相机、
/// 自适应取景、`pixelsPerUnit` 全部复用 `buildSceneFrame` —— 与 `paint` 同源，
/// 见 `frame_painter.dart` 的说明。
///
/// ## 为什么不给 `FramePainter` 加状态
///
/// 直觉做法是让 painter 在 `paint` 里把每帧的投影结果存下来供点击查询。那样
/// 要跨「绘制」与「手势」两个阶段共享状态，而绘制是 60 Hz 的重入路径 ——
/// 存状态的时机、点击时拿到的到底是哪一帧（自转一直在动）、以及 painter
/// 被 `shouldRepaint` 跳过时状态是否还是旧的，都要另立规矩。
///
/// 重算是 O(项数) 的纯计算，与一帧投影同价（`STR` 轮次 `R1` 的 CPU 侧读数是
/// `0.03 ms` 量级），而点击是人工频率。**换一次无状态**，比省这点计算划算得多。
library;

import 'dart:ui';

import '../../core/frame/pick.dart';
import 'frame_painter.dart';
import 'scene_source.dart';

/// 点 [point] 命中的节点 id。`null` = 点空了。
///
/// [yawRadians] 必须与**当前帧**一致 —— 宇宙在自转，调用方要传
/// `spunYaw(baseYaw, spin.value)`（见 `frame_painter.dart`）算出的这一刻偏航；
/// 传静态的基准偏航会整体点偏。
String? pickSceneNode({
  required SceneBundle scene,
  required Size viewport,
  required double yawRadians,
  required Offset point,
  Set<String>? visibleIds,
}) {
  if (scene.nodes.isEmpty || viewport.width <= 0 || viewport.height <= 0) {
    return null;
  }
  final SceneFrame sceneFrame = buildSceneFrame(
    scene: scene,
    viewportWidth: viewport.width,
    viewportHeight: viewport.height,
    yawRadians: yawRadians,
  );
  return pickNodeAt(
    frame: sceneFrame.frame,
    originX: sceneFrame.originX,
    originY: sceneFrame.originY,
    pixelsPerUnit: sceneFrame.pixelsPerUnit,
    pointX: point.dx,
    pointY: point.dy,
    screenRadiusOf: dotScreenRadius,
    visibleIds: visibleIds,
  );
}
