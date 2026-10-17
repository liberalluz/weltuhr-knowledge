/// `paintFrame` 的绘制调用计数 —— 「150 项 = 150 次 `drawCircle`」得是断言，不是估计。
///
/// 这一笔的全部结论都建立在一个数上：一帧发多少次绘制调用。若这个数只能靠
/// 读代码数，那它就是意见；被断言住才是事实。所以测试用记账实现顶替 `Canvas`，
/// 直接数指令。
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/features/universe/frame_draw_target.dart';
import 'package:project_knowledge/features/universe/frame_painter.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';

void main() {
  group('paintFrame 的指令计数', () {
    test('150 项 / 167 边 ⇒ 150 次 dot + 实线 1 段 + 虚线段若干（ADR-0002）', () {
      final SceneBundle scene = buildSyntheticScene();
      final ProjectedFrame frame = _project(scene);

      final _CountingTarget target = _CountingTarget();
      final FrameDrawReport report = paintFrame(
        target: target,
        frame: frame,
        origin: const Offset(400, 300),
        pixelsPerUnit: 400,
        viewport: const Size(800, 600),
      );

      expect(scene.itemCount, 150);
      expect(scene.edgeCount, 167);
      expect(report.dots, 150);
      expect(target.dots, 150);
      // 每条边至少一次调用：实线 1 段、虚线按长度拆成多段。
      expect(report.strokes, greaterThanOrEqualTo(167));
      expect(report.strokes, target.strokes);
      // 虚线边一定多于 1 段（否则「虚线」等于实线）。
      expect(report.dashedSegments, greaterThan(report.dashedEdges));
      expect(report.total, 150 + report.strokes);
    });

    test('实线边只发一次 stroke（SPEC-VIEW-002）', () {
      final ProjectedFrame frame = _twoNodeFrame(dashed: false);
      final _CountingTarget target = _CountingTarget();

      final FrameDrawReport report = paintFrame(
        target: target,
        frame: frame,
        origin: Offset.zero,
        pixelsPerUnit: 1,
        viewport: const Size(400, 400),
      );

      expect(report.strokes, 1);
      expect(report.dashedEdges, 0);
      expect(report.dashedSegments, 0);
      expect(target.strokes, 1);
    });

    test('虚线边按 9 px 周期拆段：100 px ⇒ 12 段（无 SPEC：虚线段长为设计 token）', () {
      final ProjectedFrame frame = _twoNodeFrame(dashed: true);
      final _CountingTarget target = _CountingTarget();

      final FrameDrawReport report = paintFrame(
        target: target,
        frame: frame,
        origin: Offset.zero,
        pixelsPerUnit: 1,
        viewport: const Size(400, 400),
      );

      // 100 / (5 + 4) 向上取整 = 12。
      expect(report.dashedEdges, 1);
      expect(report.dashedSegments, 12);
      expect(report.strokes, 12);
    });

    test('两端重合的虚线边被跳过，不计段（无 SPEC：退化输入的保护）', () {
      final ProjectedFrame frame = _overlappingFrame();
      final FrameDrawReport report = paintFrame(
        target: _CountingTarget(),
        frame: frame,
        origin: Offset.zero,
        pixelsPerUnit: 1,
        viewport: const Size(400, 400),
      );

      expect(report.dashedEdges, 1);
      expect(report.skippedEdges, 1);
      expect(report.strokes, 0);
      expect(report.dots, 2);
    });

    test('画到视口外的节点仍发绘制调用，并被计入 offscreenDots（ADR-0002）', () {
      final ProjectedFrame frame = _twoNodeFrame(dashed: false);
      final _CountingTarget target = _CountingTarget();

      final FrameDrawReport report = paintFrame(
        target: target,
        frame: frame,
        origin: const Offset(-5000, -5000),
        pixelsPerUnit: 1,
        viewport: const Size(400, 400),
      );

      expect(report.dots, 2);
      // 朴素实现不逐个判屏：调用照发，只是记下来。
      expect(report.offscreenDots, 2);
      expect(target.dots, 2);
    });

    test('先边后点：点压在线上（无 SPEC：绘制次序属实现选择）', () {
      final ProjectedFrame frame = _twoNodeFrame(dashed: false);
      final _CountingTarget target = _CountingTarget();

      paintFrame(
        target: target,
        frame: frame,
        origin: Offset.zero,
        pixelsPerUnit: 1,
        viewport: const Size(400, 400),
      );

      expect(target.sequence.first, 'stroke');
      expect(target.sequence.last, 'dot');
    });
  });
}

/// 与 `FramePainter.paint` 同一套相机（值取自 `projection_bench.dart`）。
ProjectedFrame _project(SceneBundle scene) {
  return projectFrame(
    nodes: scene.nodes,
    edges: scene.edges,
    camera: Camera(
      yawRadians: 0.35,
      pitchRadians: 0.42,
      distance: 3,
      focal: 1.6,
      radialSegments: 7,
      sectorCount: spikeSectorCount,
      phiGap: 1.6 / (scene.maxPhi + 1),
      minDepth: 0.05,
    ),
  );
}

ProjectedNode _node({required int index, required double x, required double y}) {
  return ProjectedNode(
    sourceIndex: index,
    id: 'n$index',
    x: x,
    y: y,
    depth: 3,
    size01: 0,
    brightness01: 1,
    dashed: false,
    colorIndex: index,
    ringFill01: 0,
    ringClosed: false,
    pulse: 0,
  );
}

ProjectedFrame _twoNodeFrame({required bool dashed}) {
  return ProjectedFrame(
    nodes: <ProjectedNode>[
      _node(index: 0, x: 0, y: 0),
      _node(index: 1, x: 100, y: 0),
    ],
    edges: <EdgeSpan>[EdgeSpan(fromIndex: 0, toIndex: 1, dashed: dashed)],
    drawOrder: <int>[0, 1],
  );
}

ProjectedFrame _overlappingFrame() {
  return ProjectedFrame(
    nodes: <ProjectedNode>[
      _node(index: 0, x: 10, y: 10),
      _node(index: 1, x: 10, y: 10),
    ],
    edges: <EdgeSpan>[const EdgeSpan(fromIndex: 0, toIndex: 1, dashed: true)],
    drawOrder: <int>[0, 1],
  );
}

/// 记账用目标：不碰 `Canvas`，只数调用并记住次序。
class _CountingTarget implements FrameDrawTarget {
  int dots = 0;
  int strokes = 0;
  final List<String> sequence = <String>[];

  @override
  void dot({
    required double x,
    required double y,
    required double radius,
    required int argb,
    required bool filled,
  }) {
    dots += 1;
    sequence.add('dot');
  }

  @override
  void stroke({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required int argb,
    required double width,
  }) {
    strokes += 1;
    sequence.add('stroke');
  }
}
