/// 朴素绘制层 —— 这一笔要**故意不优化**。
///
/// 判据不是「画得好不好看」，而是「一帧 300 多次绘制调用到底撑不撑得住
/// 30 fps」。所以这里每个节点一次 `drawCircle`、每条边一次或多次 `drawLine`，
/// 不做任何批绘制、不做视口剔除、不合并 `Paint`。`ADR-0002` §决策 2 把
/// 「若 150 项达不到帧预算就得换实现路径」前置到 `B2`，要证的正是这条路。
///
/// 相机参数与 `tool/bench/projection_bench.dart` **同一套**（distance 3 ·
/// focal 1.6 · radialSegments 7 · minDepth 0.05 · phiHeight 固定 1.6）。
/// 两处不一致的话，`main` 上的 bench 数与终端帧率就不是在说同一种几何。
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants.dart';
import '../../core/view/fit.dart';
import '../../core/frame/projection.dart';
import 'frame_draw_target.dart';
import 'scene_source.dart';

// ── 相机（与 bench 同口径） ────────────────────────────────────────────────
const double _cameraPitch = 0.42;
const double _cameraDistance = 3;
const double _cameraFocal = 1.6;
const double _phiWorldHeight = 1.6;
const double _minDepth = 0.05;

/// `VIEW-002`：`r` 是 7 段径向分层。

/// 自转起始角（与 bench 的静态视角一致，便于两处对数）。
const double baseYawRadians = 0.35;

// ── 屏幕变换 ──────────────────────────────────────────────────────────────
/// 一个世界单位折算多少像素 × 短边。让 150 个点大致铺满画面。
const double _unitToPixel = 0.85;

// ── 节点尺寸 ──────────────────────────────────────────────────────────────
const double _minDotRadius = 0.9;
const double _maxDotRadius = 16;
const double _sizeToRadius = 5;

// ── 虚线 ──────────────────────────────────────────────────────────────────
const double _dashLength = 5;
const double _dashGap = 4;
const double _dashPeriod = _dashLength + _dashGap;

/// 短于这个长度视为退化，不分段（否则会画出几十个零长线段，把调用数虚高）。
const double _degenerateLength = 0.5;
const double _edgeWidth = 1;

// ── 颜色 ──────────────────────────────────────────────────────────────────
/// 六轴 / 六扇区的调色板。序号来自 `SceneNode.colorIndex`。
const List<int> _palette = <int>[
  0xFF6E63D8,
  0xFF2FB3A0,
  0xFFE0913C,
  0xFF4A8FE0,
  0xFFC85894,
  0xFF8A9C3C,
];

const int _edgeArgbSolid = 0x3A9AA3C0;
const int _edgeArgbDashed = 0x249AA3C0;

/// 亮度通道的映射区间：`brightness01 = 0` 时压到 35%，满值给 100%。
const double _minShade = 0.35;
const double _maxShade = 1;

/// 画一帧。**先边后点**：点压在线上，读起来才像「连到点」而不是「穿过点」。
///
/// 返回的 [FrameDrawReport] 是这一笔的核心产物 —— 它把「多少个 draw call」
/// 从估计值变成观测量。
FrameDrawReport paintFrame({
  required FrameDrawTarget target,
  required ProjectedFrame frame,
  required Offset origin,
  required double pixelsPerUnit,
  required Size viewport,
  Set<String>? visibleIds,
}) {
  int dots = 0;
  int strokes = 0;
  int dashedEdges = 0;
  int dashedSegments = 0;
  int skipped = 0;
  int offscreen = 0;

  for (final EdgeSpan edge in frame.edges) {
    final ProjectedNode from = frame.nodes[edge.fromIndex];
    final ProjectedNode to = frame.nodes[edge.toIndex];
    // 筛选（`SPEC-VIEW-021`）：两端都在才画。只藏一端的话，边上会伸出一截
    // 连到空气里的线 —— 那看起来像「数据缺失」，而实际只是被筛掉了。
    if (visibleIds != null &&
        (!visibleIds.contains(from.id) || !visibleIds.contains(to.id))) {
      continue;
    }
    final double x1 = origin.dx + from.x * pixelsPerUnit;
    final double y1 = origin.dy + from.y * pixelsPerUnit;
    final double x2 = origin.dx + to.x * pixelsPerUnit;
    final double y2 = origin.dy + to.y * pixelsPerUnit;

    if (!edge.dashed) {
      target.stroke(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        argb: _edgeArgbSolid,
        width: _edgeWidth,
      );
      strokes += 1;
      continue;
    }

    dashedEdges += 1;
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double length = math.sqrt(dx * dx + dy * dy);
    if (length < _degenerateLength) {
      skipped += 1;
      continue;
    }

    final int segments = (length / _dashPeriod).ceil();
    for (int i = 0; i < segments; i++) {
      final double start = i * _dashPeriod;
      if (start >= length) {
        break;
      }
      double end = start + _dashLength;
      if (end > length) {
        end = length;
      }
      final double t0 = start / length;
      final double t1 = end / length;
      target.stroke(
        x1: x1 + dx * t0,
        y1: y1 + dy * t0,
        x2: x1 + dx * t1,
        y2: y1 + dy * t1,
        argb: _edgeArgbDashed,
        width: _edgeWidth,
      );
      strokes += 1;
      dashedSegments += 1;
    }
  }

  for (final int index in frame.drawOrder) {
    final ProjectedNode node = frame.nodes[index];
    // 被筛掉的节点**不画也不计数** —— 计数是帧预算的读数，把没画的算进去，
    // 会让「筛选之后更快了」这件事在读数里看不出来。
    if (visibleIds != null && !visibleIds.contains(node.id)) {
      continue;
    }
    final double radius = dotScreenRadius(node);
    final double x = origin.dx + node.x * pixelsPerUnit;
    final double y = origin.dy + node.y * pixelsPerUnit;

    // 屏外照样发调用 —— 朴素实现不逐个判屏，而「有多少被画到画面外」正是
    // φ 未归一时的症状，藏起来就看不见了。
    if (x + radius < 0 || y + radius < 0 || x - radius > viewport.width || y - radius > viewport.height) {
      offscreen += 1;
    }

    target.dot(
      x: x,
      y: y,
      radius: radius,
      argb: _nodeArgb(node),
      // 虚实通道：不可外化比例高 ⇒ 空心（`channel-table.md` 通道 4）。
      filled: !node.dashed,
    );
    dots += 1;
  }

  return FrameDrawReport(
    dots: dots,
    strokes: strokes,
    dashedEdges: dashedEdges,
    dashedSegments: dashedSegments,
    skippedEdges: skipped,
    offscreenDots: offscreen,
  );
}

/// 半径随透视收缩。开方是为了别让远处节点缩成半个像素后被抗锯齿糊掉 ——
/// 那会让「画了 150 个点」看起来像「画了 20 个点」。
///
/// **公开**：拾取（`SPEC-VIEW-014` 入口 1）要用同一个圆判断点中了谁。改成
/// 第二份公式的话，两个半径之差就是「看得见、点边缘无效」的那一圈。
double dotScreenRadius(ProjectedNode node) {
  final double perspective = math.sqrt(_cameraDistance / node.depth);
  final double radius = (_minDotRadius + _sizeToRadius * node.size01) * perspective;
  if (radius.isNaN || radius < _minDotRadius) {
    return _minDotRadius;
  }
  return radius > _maxDotRadius ? _maxDotRadius : radius;
}

/// 六色取一，再按亮度压暗 —— 亮度通道 = 可外化要件完整度。
int _nodeArgb(ProjectedNode node) {
  final int base = _palette[node.colorIndex.abs() % _palette.length];
  final double brightness = node.brightness01.isNaN
      ? 0
      : node.brightness01.clamp(0.0, 1.0).toDouble();
  final double shade = _minShade + (_maxShade - _minShade) * brightness;
  final int r = (((base >> 16) & 0xFF) * shade).round();
  final int g = (((base >> 8) & 0xFF) * shade).round();
  final int b = ((base & 0xFF) * shade).round();
  return 0xFF000000 | (r << 16) | (g << 8) | b;
}

/// 每帧回调：把这一帧的绘制报告与两段耗时交给调用方做读数。
typedef FrameRepaintCallback =
    void Function(FrameDrawReport report, double projectMs, double paintMs);

/// 一帧的几何：投影结果 + 屏幕变换。
///
/// 绘制与拾取**必须同源**（见 [buildSceneFrame]）—— 这个类型就是那份同源的
/// 载体：两边拿到的 `frame / origin / pixelsPerUnit` 出自同一次计算。
class SceneFrame {
  const SceneFrame({
    required this.frame,
    required this.originX,
    required this.originY,
    required this.pixelsPerUnit,
  });

  final ProjectedFrame frame;

  /// 屏幕原点（视口中心）。
  final double originX;
  final double originY;

  /// 一个投影单位折算多少像素。
  final double pixelsPerUnit;
}

/// 自转推进到第 [spinValue] 圈（0→1）时的偏航。
///
/// 绘制与拾取共用这一条式子。两处各写一遍 `base + value × 2π` 也算重复，
/// 但更要紧的是：**改了其中一处的方向或取模，点击就会整体偏一个角度**，
/// 而这种偏差在大星上仍能点中、只在窄星上偶发失效 —— 最难查的那一类。
double spunYaw(double baseYawRadians, double spinValue) =>
    baseYawRadians + spinValue * fullTurnRadians;

/// 按场景 + 视口 + 偏航算出一帧。
///
/// `paint` 与 `pickSceneNode` 都走这里。**不要在其中任一处另写一遍装配**：
/// 相机常量、自适应取景、`pixelsPerUnit` 三者只要有一处不同，屏幕上的星与
/// 可点的位置就会错开，而错开多少取决于窗口尺寸 —— 那是查不出来的偶发 bug。
SceneFrame buildSceneFrame({
  required SceneBundle scene,
  required double viewportWidth,
  required double viewportHeight,
  required double yawRadians,
}) {
  final Camera baseCamera = Camera(
    yawRadians: yawRadians,
    pitchRadians: _cameraPitch,
    distance: _cameraDistance,
    focal: _cameraFocal,
    radialSegments: scene.radialSegments,
    sectorCount: spikeSectorCount,
    // φ 归一到一个世界单位高度：α 包最大层号 63，不做归一的话最深那批
    // 会跑到相机后面，量到的是钳制分支。
    phiHeight: _phiWorldHeight,
    minDepth: _minDepth,
  );

  // 按当前场景与视口**自适应取景**：写死一组 distance/focal，换个包或
  // 换个窗口尺寸就会裁切（实测反馈：最下一排点被切）。
  final Camera camera = fitCameraToViewport(
    nodes: scene.nodes,
    edges: scene.edges,
    base: baseCamera,
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    pixelsPerUnit: math.min(viewportWidth, viewportHeight) * _unitToPixel,
  );

  return SceneFrame(
    frame: projectFrame(nodes: scene.nodes, edges: scene.edges, camera: camera),
    originX: viewportWidth / 2,
    originY: viewportHeight / 2,
    pixelsPerUnit: math.min(viewportWidth, viewportHeight) * _unitToPixel,
  );
}

/// 把一枚场景画到 `Canvas` 上，每帧按 `spin` 推进自转。
class FramePainter extends CustomPainter {
  FramePainter({
    required this.scene,
    required this.spin,
    required this.onRepaint,
    this.baseYaw = baseYawRadians,
    this.visibleIds,
  }) : super(repaint: spin);

  /// 自转的起始偏航。正式视图把 `CameraState.yawRadians` 传进来，
  /// 于是「切档保留视角」在画面上真的成立；spike 不传，沿用 `baseYawRadians`。
  final double baseYaw;

  final SceneBundle scene;

  /// 只画这些 id（`null` = 全画）。来自 ② 的筛选（`SPEC-VIEW-021`）。
  ///
  /// **筛选不重排**：`r / θ / φ` 一律不动，只让不匹配的不出现。重排会让
  /// 「筛一下」变成「换一张图」—— 用户刚建立起来的方位感每次都归零。
  final Set<String>? visibleIds;

  /// 0→1 循环。乘一整圈就是自转 —— 视角一直在变，才能测到不同遮挡关系下的
  /// 光栅化成本，而不是一个静止画面的幸运值。
  final Animation<double> spin;

  final FrameRepaintCallback onRepaint;

  @override
  void paint(Canvas canvas, Size size) {
    final Stopwatch watch = Stopwatch()..start();

    final SceneFrame sceneFrame = buildSceneFrame(
      scene: scene,
      viewportWidth: size.width,
      viewportHeight: size.height,
      yawRadians: spunYaw(baseYaw, spin.value),
    );
    final double projectMs = watch.elapsedMicroseconds / 1000;

    watch
      ..reset()
      ..start();
    final FrameDrawReport report = paintFrame(
      target: CanvasDrawTarget(canvas),
      frame: sceneFrame.frame,
      origin: Offset(sceneFrame.originX, sceneFrame.originY),
      pixelsPerUnit: sceneFrame.pixelsPerUnit,
      viewport: size,
      visibleIds: visibleIds,
    );
    final double paintMs = watch.elapsedMicroseconds / 1000;

    onRepaint(report, projectMs, paintMs);
  }

  @override
  bool shouldRepaint(FramePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.spin != spin ||
      // 集合按元素比而不是按引用比：`universe_screen` 每次 build 都可能给出
      // 一个新集合，按引用比会每帧都重绘（自转时本来就每帧重绘，但筛选后
      // 静止的 spike 画面会白刷）。
      !_sameIds(oldDelegate.visibleIds, visibleIds);
}

bool _sameIds(Set<String>? a, Set<String>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  return a.length == b.length && a.containsAll(b);
}
