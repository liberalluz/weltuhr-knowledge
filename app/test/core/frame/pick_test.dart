import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/frame/pick.dart';
import 'package:project_knowledge/core/frame/projection.dart';

/// 一个屏幕上的点。`x` / `y` 是**投影单位**，绘制时还要乘 `pixelsPerUnit`。
ProjectedNode _node({
  required String id,
  required double x,
  required double y,
  double depth = 3,
  double size01 = 0,
}) => ProjectedNode(
  sourceIndex: 0,
  id: id,
  x: x,
  y: y,
  depth: depth,
  size01: size01,
  brightness01: 1,
  dashed: false,
  colorIndex: 0,
  ringFill01: 0,
  ringClosed: false,
  pulse: 0,
);

/// `drawOrder` 必须是**远 → 近**（画家算法），本文件所有用例都按这个约定给。
ProjectedFrame _frame(List<ProjectedNode> nodes) => ProjectedFrame(
  nodes: nodes,
  edges: const <EdgeSpan>[],
  drawOrder: <int>[for (int i = 0; i < nodes.length; i++) i],
);

const double _unit = 100;

/// 每颗星按固定 4 px 半径判 —— 拾取的半径由绘制层注入，本文件只验「用给的
/// 半径判圆」这一件事，半径公式本身属绘制层（`dotScreenRadius`）。
double _radiusOf(ProjectedNode node) => 4;

String? _pick(
  ProjectedFrame frame,
  double x,
  double y, {
  Set<String>? visibleIds,
}) => pickNodeAt(
  frame: frame,
  originX: 0,
  originY: 0,
  pixelsPerUnit: _unit,
  pointX: x,
  pointY: y,
  screenRadiusOf: _radiusOf,
  visibleIds: visibleIds,
);

void main() {
  group('宇宙点星（SPEC-VIEW-014 入口 1）', () {
    test('点中星心 ⇒ 返回它的 id（SPEC-VIEW-014）', () {
      // x=0.5 投影单位 × 100 = 屏幕 50 px。
      final ProjectedFrame frame = _frame(<ProjectedNode>[
        _node(id: 'item-a', x: 0.5, y: 0.2),
      ]);
      expect(_pick(frame, 50, 20), 'item-a');
    });

    test('点在星的半径外 ⇒ null（不误选邻星）（SPEC-VIEW-014）', () {
      final ProjectedFrame frame = _frame(<ProjectedNode>[
        _node(id: 'item-a', x: 0.5, y: 0.2),
      ]);
      // 圆心 (50,20)，半径 4 px ⇒ 60 px 处是空的。
      expect(_pick(frame, 60, 20), isNull);
    });

    test('两星重叠时取更近的那颗，不是列表里靠前的（SPEC-VIEW-014）', () {
      // 画家算法的顺序 = 远在前。远星先画，被近星压住 —— 用户点的是看得见
      // 的那颗，所以拾取要反着查。
      final ProjectedFrame frame = _frame(<ProjectedNode>[
        _node(id: 'far', x: 0.5, y: 0.5, depth: 6),
        _node(id: 'near', x: 0.5, y: 0.5, depth: 2),
      ]);
      expect(_pick(frame, 50, 50), 'near');
    });

    test('被筛掉的星点不中 —— 屏幕上没画的不能选中（SPEC-VIEW-021）', () {
      final ProjectedFrame frame = _frame(<ProjectedNode>[
        _node(id: 'item-a', x: 0.5, y: 0.5),
      ]);
      expect(_pick(frame, 50, 50), 'item-a');
      expect(
        _pick(frame, 50, 50, visibleIds: <String>{'item-b'}),
        isNull,
        reason: '筛掉之后它不在画面上，点中了也会打开一片用户没见过的内容',
      );
    });

    test('比 C-44 还小的星按最小可点半径接住（C-44）', () {
      // 半径为 1 px 的星：严格按圆判，指针误差稍微一大就点不中。
      double tinyRadius(ProjectedNode node) => 1;
      final ProjectedFrame frame = _frame(<ProjectedNode>[
        _node(id: 'tiny', x: 0, y: 0),
      ]);
      String? pickAt(double x) => pickNodeAt(
        frame: frame,
        originX: 0,
        originY: 0,
        pixelsPerUnit: _unit,
        pointX: x,
        pointY: 0,
        screenRadiusOf: tinyRadius,
      );

      expect(pickAt(1), 'tiny');
      expect(
        pickAt(pickMinHitRadius - 1),
        'tiny',
        reason: 'C-44 的下限对「看得见但很小」的星必须生效',
      );
      expect(
        pickAt(pickMinHitRadius + 1),
        isNull,
        reason: '下限只补足到 C-44，不能无限放大去抢邻星',
      );
    });
  });
}
