import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/view/fit.dart';

Camera _camera({double yaw = 0}) => Camera(
  yawRadians: yaw,
  pitchRadians: 0,
  distance: 3,
  focal: 1.6,
  radialSegments: 10,
  sectorCount: 6,
  phiHeight: 1.6,
  minDepth: 0.05,
);

SceneNode _node({double radial01 = 0.5, int sector = 0, double phiFraction01 = 0}) =>
    SceneNode(
      id: 'n$radial01-$sector',
      radial01: radial01,
      sector: sector,
      sectorFraction01: 0,
      phiLevel: 0,
      phiFraction01: phiFraction01,
      size01: 0.5,
      brightness01: 0.5,
      dashed: false,
      colorIndex: 0,
      ringFill01: 0,
      ringClosed: false,
      pulse: 0,
    );

List<SceneNode> _ring() => <SceneNode>[
  for (int i = 0; i < 6; i++) _node(radial01: 0.99, sector: i),
];

void main() {
  group('自适应取景（视口短边 46% 为允许半径）', () {
    test('取景后内容不越界、也不塌成一点（无 SPEC：装得下是取景前提）', () {
      final List<SceneNode> nodes = _ring();
      const double width = 240;
      const double height = 200;
      final Camera fitted = fitCameraToViewport(
        nodes: nodes,
        edges: const <EdgeSpan>[],
        base: _camera(),
        viewportWidth: width,
        viewportHeight: height,
      );

      final ProjectedFrame frame = projectFrame(
        nodes: nodes,
        edges: const <EdgeSpan>[],
        camera: fitted,
      );
      final double maxExtent = frame.nodes
          .map((ProjectedNode n) => n.x.abs() > n.y.abs() ? n.x.abs() : n.y.abs())
          .reduce((double a, double b) => a > b ? a : b);

      const double allowed = 200 * fitViewportRadiusRatio;
      expect(maxExtent, lessThanOrEqualTo(allowed + 0.5), reason: '不越出短边');
      expect(
        maxExtent,
        greaterThan(allowed * 0.5),
        reason: '不能塌成一点 —— 旧实现焦距 1.6 时全部点挤在 0.5 px 内',
      );
    });

    test('同一场景、不同 yaw 得到同一焦距（无 SPEC：旋转不变量属实现要求）', () {
      final List<SceneNode> nodes = _ring();
      double focalFor(double yaw) => fitCameraToViewport(
        nodes: nodes,
        edges: const <EdgeSpan>[],
        base: _camera(yaw: yaw),
        viewportWidth: 240,
        viewportHeight: 200,
      ).focal;

      expect(focalFor(0), closeTo(focalFor(1.1), 1e-9));
      expect(focalFor(0), closeTo(focalFor(2.7), 1e-9));
    });

    test('空场景原样返回（无 SPEC：退化输入不抛）', () {
      final Camera base = _camera();
      final Camera fitted = fitCameraToViewport(
        nodes: const <SceneNode>[],
        edges: const <EdgeSpan>[],
        base: base,
        viewportWidth: 240,
        viewportHeight: 200,
      );
      expect(identical(fitted, base), isTrue);
    });
  });
}
