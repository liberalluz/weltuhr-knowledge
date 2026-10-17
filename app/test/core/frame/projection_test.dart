import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/frame/scene.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/alpha_pack.dart';

Camera _camera({
  double yaw = 0,
  double pitch = 0,
  double distance = 3,
  double focal = 1.6,
  int radialSegments = 7,
  int sectorCount = 6,
  double phiGap = 0.1,
  double minDepth = 0.05,
}) => Camera(
  yawRadians: yaw,
  pitchRadians: pitch,
  distance: distance,
  focal: focal,
  radialSegments: radialSegments,
  sectorCount: sectorCount,
  phiGap: phiGap,
  minDepth: minDepth,
);

SceneNode _node({
  String id = 'n',
  double radial01 = 0.5,
  int sector = 0,
  double sectorFraction01 = 0,
  int phiLevel = 0,
}) => SceneNode(
  id: id,
  radial01: radial01,
  sector: sector,
  sectorFraction01: sectorFraction01,
  phiLevel: phiLevel,
  size01: 0.5,
  brightness01: 0.5,
  dashed: false,
  colorIndex: 0,
  ringFill01: 0,
  ringClosed: false,
  pulse: 0,
);

void main() {
  test('r 是 7 段径向分层：同段同半径，跨段才拉开（SPEC-VIEW-002）', () {
    // yaw / pitch 置零、扇区取 0，于是 x 只由半径决定，可以逐字比对。
    final ProjectedFrame frame = projectFrame(
      nodes: <SceneNode>[
        _node(id: 'band0-a', radial01: 0),
        _node(id: 'band0-b', radial01: 0.1),
        _node(id: 'band6', radial01: 0.9),
      ],
      edges: const <EdgeSpan>[],
      camera: _camera(),
    );
    expect(frame.nodes[0].x, frame.nodes[1].x);
    expect(frame.nodes[2].x, greaterThan(frame.nodes[0].x));
  });

  test('φ 越深越靠外：层号大 ⇒ 轴向偏移大（SPEC-VIEW-002）', () {
    final ProjectedFrame frame = projectFrame(
      nodes: <SceneNode>[
        _node(id: 'shallow', phiLevel: 0),
        _node(id: 'deep', phiLevel: 3),
      ],
      edges: const <EdgeSpan>[],
      camera: _camera(),
    );
    expect(frame.nodes[1].y, greaterThan(frame.nodes[0].y));
  });

  test('θ 扇区：sector 0 与 sector 3 落在相反两侧（SPEC-VIEW-002）', () {
    final ProjectedFrame frame = projectFrame(
      nodes: <SceneNode>[
        _node(id: 'east', sector: 0),
        _node(id: 'west', sector: 3),
      ],
      edges: const <EdgeSpan>[],
      camera: _camera(),
    );
    expect(frame.nodes[0].x, greaterThan(0));
    expect(frame.nodes[1].x, lessThan(0));
  });

  test('贴到相机平面的节点被钳到 minDepth，不产生 Infinity（无 SPEC：数值稳健性）', () {
    // distance 与节点深度差小于 minDepth：不钳制就会算出 Infinity，
    // 而 painter 拿到 Infinity 的表现是整帧消失，不是报错。
    final ProjectedFrame frame = projectFrame(
      nodes: <SceneNode>[_node(sector: 2, radial01: 1)],
      edges: const <EdgeSpan>[],
      camera: _camera(distance: 0.1, minDepth: 0.05),
    );
    final ProjectedNode node = frame.nodes.single;
    expect(node.depth, 0.05);
    expect(node.x.isFinite, isTrue);
    expect(node.y.isFinite, isTrue);
  });

  test('深度排序：drawOrder 远 → 近，且不重排 nodes（无 SPEC：画家算法属实现要求）', () {
    final ProjectedFrame frame = projectFrame(
      nodes: <SceneNode>[
        _node(id: 'a', radial01: 0.2),
        _node(id: 'b', radial01: 0.8),
        _node(id: 'c', radial01: 0.5),
      ],
      edges: const <EdgeSpan>[],
      camera: _camera(yaw: 0.3),
    );
    expect(frame.drawOrder.length, frame.nodes.length);
    for (int i = 1; i < frame.drawOrder.length; i++) {
      final double previous = frame.nodes[frame.drawOrder[i - 1]].depth;
      final double current = frame.nodes[frame.drawOrder[i]].depth;
      expect(previous, greaterThanOrEqualTo(current));
    }
    // 边按下标引用两端，所以 nodes 必须保持入参顺序。
    expect(frame.nodes.map((ProjectedNode n) => n.id).toList(), <String>['a', 'b', 'c']);
  });

  test('确定性：同一输入连投两次，逐字段一致（无 SPEC：确定性属工程要求）', () {
    final List<SceneNode> nodes = <SceneNode>[
      for (int i = 0; i < 20; i++) _node(id: 'n$i', radial01: i / 20, sector: i % 6),
    ];
    final ProjectedFrame first = projectFrame(
      nodes: nodes,
      edges: <EdgeSpan>[const EdgeSpan(fromIndex: 0, toIndex: 1, dashed: false)],
      camera: _camera(yaw: 0.7, pitch: 0.2),
    );
    final ProjectedFrame second = projectFrame(
      nodes: nodes,
      edges: <EdgeSpan>[const EdgeSpan(fromIndex: 0, toIndex: 1, dashed: false)],
      camera: _camera(yaw: 0.7, pitch: 0.2),
    );
    expect(second.drawOrder, first.drawOrder);
    for (int i = 0; i < first.nodes.length; i++) {
      expect(second.nodes[i].x, first.nodes[i].x);
      expect(second.nodes[i].y, first.nodes[i].y);
      expect(second.nodes[i].depth, first.nodes[i].depth);
    }
  });

  test('真实 α 包：150 项 + 3 个占位节点全投影，坐标全部有限（SPEC-VIEW-002）', () {
    final LoadedPack pack = loadAlphaPack();
    final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);
    final ProjectedFrame frame = projectFrame(
      nodes: nodes,
      edges: buildEdgeSpans(pack, nodes),
      camera: _camera(yaw: 0.35, pitch: 0.42, phiGap: 0.025),
    );

    expect(frame.nodes.length, 153);
    expect(frame.drawOrder.length, 153);
    for (final ProjectedNode node in frame.nodes) {
      expect(node.x.isFinite, isTrue);
      expect(node.y.isFinite, isTrue);
      expect(node.depth.isFinite, isTrue);
      expect(node.depth, greaterThanOrEqualTo(0.05));
    }
  });

  test('真实 α 包：3 条「指向未知」由占位节点接住，170 条边全保留（ADR-0003）', () {
    // `type: unknown` 的边意即「前置指向一个还没写出来的项」，目标 id 刻意不在册。
    // `B2` 时这类边因缺端点被跳过（167 条）；`ADR-0003` §决策 5 裁定沿用
    // `SPEC-VIEW-007` 的黑洞 —— 缺失端画占位节点，边指向它，于是**不再丢边**。
    final LoadedPack pack = loadAlphaPack();
    final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);
    final List<EdgeSpan> spans = buildEdgeSpans(pack, nodes);

    expect(pack.edges.length, 170);
    expect(nodes.where((SceneNode n) => n.isPlaceholder).length, 3);
    expect(spans.length, 170);
    for (final EdgeSpan span in spans) {
      expect(span.fromIndex, inInclusiveRange(0, nodes.length - 1));
      expect(span.toIndex, inInclusiveRange(0, nodes.length - 1));
    }
  });
}
