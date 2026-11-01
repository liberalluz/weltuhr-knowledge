import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/universe/placement.dart';

import '../../support/tree_fixture.dart';

/// 造一个带官方码的结构节点。`officialCode` 决定它在兄弟里的次序，
/// 因此这一组用例必须能指定它 —— `node_fixture` 的 `structuralNode` 没开这个口子。
StructuralNode coded({
  required String id,
  required String slug,
  required String? code,
  Axis axis = Axis.discipline,
  LevelSlot slot = LevelSlot.group,
}) => StructuralNode(
  id: id,
  axis: axis,
  levelSlot: slot,
  name: slug,
  slug: slug,
  scope: Scope.s0,
  packId: 'skeleton',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
  officialCode: code,
);

Node rootOf(Axis axis) => coded(
  id: 'skeleton:${axis.name}-root',
  slug: '${axis.name}-root',
  code: '00',
  axis: axis,
  slot: LevelSlot.supercluster,
);

void main() {
  group('层序与半径', () {
    test('槽位序：学科三槽、专业四槽、角色五槽，轴根恒为 0（ADR-0006 修订十二）', () {
      expect(
        shellIndexOf(axis: Axis.discipline, slot: LevelSlot.supercluster),
        0,
      );
      expect(shellIndexOf(axis: Axis.discipline, slot: LevelSlot.group), 1);
      expect(shellIndexOf(axis: Axis.discipline, slot: LevelSlot.star), 2);

      expect(shellIndexOf(axis: Axis.major, slot: LevelSlot.galaxy), 2);
      expect(shellIndexOf(axis: Axis.major, slot: LevelSlot.star), 3);

      expect(shellIndexOf(axis: Axis.occupation, slot: LevelSlot.cluster), 3);
      expect(shellIndexOf(axis: Axis.occupation, slot: LevelSlot.star), 4);
    });

    test('非法组合返回 null，不给位置（`galaxy` 不挂在学科轴上）（ADR-0006 修订十二）', () {
      expect(
        shellIndexOf(axis: Axis.discipline, slot: LevelSlot.galaxy),
        isNull,
      );
      expect(
        shellIndexOf(axis: Axis.discipline, slot: LevelSlot.cluster),
        isNull,
      );
      expect(shellIndexOf(axis: Axis.major, slot: LevelSlot.cluster), isNull);
      expect(
        shellIndexOf(axis: Axis.discipline, slot: LevelSlot.planet),
        isNull,
      );
    });

    test('五层半径按 8.0 × 1.62^idx 等比，最外层仍在天球内（ADR-0006 修订十二）', () {
      final List<double> radii = <double>[
        for (int i = 0; i < universeShellCount; i++) shellRadiusOf(i),
      ];
      expect(radii.first, universeShellInnermostRadius);
      expect(radii[1], closeTo(12.96, 0.01));
      expect(radii[2], closeTo(20.9952, 0.001));
      expect(radii[3], closeTo(34.012, 0.01));
      expect(radii[4], closeTo(55.1, 0.02));
      expect(
        radii.last,
        lessThan(100),
        reason: '星空半径 100，节点最外层必须留在天球之内，否则「近处的东西」跑到背景外',
      );
      for (int i = 1; i < radii.length; i++) {
        expect(radii[i], greaterThan(radii[i - 1]));
      }
    });
  });

  group('子级格位', () {
    test('格数 = 列 × 行，且不小于骨架最大同父子数 105（ADR-0006 修订十二）', () {
      expect(
        universeChildCellCount,
        universeSkyGridColumns * universeSkyGridRows,
      );
      expect(
        universeChildCellCount,
        greaterThanOrEqualTo(105),
        reason: '专业轴有父挂 105 个子；格数少于它就会被迫叠放',
      );
    });

    test('第 0 格在左下、最后一格在右上，方位与仰角都落在跨度内（ADR-0006 修订十二）', () {
      final SkyPoint first = childPointOf(index: 0, radius: 20);
      final SkyPoint last = childPointOf(
        index: universeChildCellCount - 1,
        radius: 20,
      );
      expect(first.radius, 20);
      expect(first.elevationDeg, lessThan(0));
      expect(first.azimuthDeg, lessThan(0));
      expect(last.elevationDeg, greaterThan(0));
      expect(last.azimuthDeg, greaterThan(0));

      for (final SkyPoint p in <SkyPoint>[first, last]) {
        expect(
          p.elevationDeg.abs(),
          lessThan(universeChildElevationSpanDeg / 2),
        );
        expect(p.azimuthDeg.abs(), lessThanOrEqualTo(180));
      }
    });

    test('超出格数时回卷叠放，不抛错（ADR-0006 修订十二）', () {
      final SkyPoint wrapped = childPointOf(
        index: universeChildCellCount,
        radius: 20,
      );
      final SkyPoint zero = childPointOf(index: 0, radius: 20);
      expect(wrapped, zero, reason: '第 120 个与第 0 个同格 —— 判据要求叠放而不是报错');
    });

    test('子级全部落在来路走廊之下，不与祖先抢同一块球面（ADR-0006 修订十二）', () {
      final double highestChild = childPointOf(
        index: universeChildCellCount - 1,
        radius: 20,
      ).elevationDeg;
      final double lowestAncestor = ancestorElevationOf(0);
      expect(
        lowestAncestor,
        greaterThan(highestChild),
        reason: '球心视角下半径不改变屏幕位置、只改变遮挡 —— 同仰角同位角就是叠成一个点',
      );
    });
  });

  group('来路走廊', () {
    test('逐级递增且始终低于天顶（ADR-0006 修订十二）', () {
      double previous = ancestorElevationOf(0);
      expect(previous, lessThan(90));
      for (int depth = 1; depth < universeShellCount; depth++) {
        final double current = ancestorElevationOf(depth);
        expect(current, greaterThan(previous));
        expect(current, lessThan(90), reason: '顶到天顶之后方位角失去意义，所有祖先会挤成一个点');
        previous = current;
      }
    });
  });

  group('整幅落位', () {
    test('轴根没有来路，子级按官方码排序后依次落格（ADR-0006 修订十二）', () {
      final Node root = rootOf(Axis.discipline);
      final List<Node> children = <Node>[
        coded(id: 'c-3', slug: 'bing', code: '03'),
        coded(id: 'c-1', slug: 'yi', code: '01'),
        coded(id: 'c-2', slug: 'jia', code: '02'),
      ];
      final UniverseLayout layout = layoutUniverse(
        path: <Node>[root],
        children: children,
      );
      expect(layout.ancestors, isEmpty);
      expect(layout.current.azimuthDeg, 0);
      expect(layout.current.elevationDeg, 0);
      expect(layout.current.radius, universeShellInnermostRadius);

      // 排序后 `01` 在前 ⇒ 它拿第 0 格（左下）。
      expect(
        layout.children['c-1'],
        childPointOf(index: 0, radius: layout.children['c-1']!.radius),
      );
      expect(
        layout.children['c-2'],
        childPointOf(index: 1, radius: layout.children['c-2']!.radius),
      );
      expect(
        layout.children['c-3'],
        childPointOf(index: 2, radius: layout.children['c-3']!.radius),
      );
    });

    test('无官方码的排在末尾，不占住视野最低处（ADR-0006 修订十二）', () {
      final Node root = rootOf(Axis.discipline);
      final List<Node> children = <Node>[
        coded(id: 'no-code', slug: 'wu', code: null),
        coded(id: 'has-code', slug: 'you', code: '01'),
      ];
      final UniverseLayout layout = layoutUniverse(
        path: <Node>[root],
        children: children,
      );
      final SkyPoint first = childPointOf(
        index: 0,
        radius: layout.children['has-code']!.radius,
      );
      expect(layout.children['has-code'], first);
      expect(layout.children['no-code'], isNot(first));
    });

    test('来路由近到远，半径按各自层序（ADR-0006 修订十二）', () {
      final Node root = rootOf(Axis.occupation);
      final Node group = coded(
        id: 'g',
        slug: 'g',
        code: '01',
        axis: Axis.occupation,
      );
      final Node galaxy = coded(
        id: 'gal',
        slug: 'gal',
        code: '01',
        axis: Axis.occupation,
        slot: LevelSlot.galaxy,
      );
      final UniverseLayout layout = layoutUniverse(
        path: <Node>[root, group, galaxy],
        children: const <Node>[],
      );
      expect(layout.ancestors.length, 2);
      expect(
        layout.ancestors[0].radius,
        closeTo(12.96, 0.01),
        reason: '父是 group，第 1 层',
      );
      expect(
        layout.ancestors[1].radius,
        universeShellInnermostRadius,
        reason: '根是第 0 层',
      );
      expect(
        layout.ancestors[0].elevationDeg,
        lessThan(layout.ancestors[1].elevationDeg),
        reason: '近的父在走廊下沿，远的根在上沿',
      );
      expect(
        layout.current.radius,
        closeTo(20.9952, 0.001),
        reason: '当前是 galaxy，第 2 层',
      );
    });

    test('同父子级同半径 —— 层是结构的属性，不随视角变（ADR-0006 修订十二）', () {
      final Node root = rootOf(Axis.major);
      final Node galaxy = coded(
        id: 'gal',
        slug: 'gal',
        code: '01',
        axis: Axis.major,
        slot: LevelSlot.galaxy,
      );
      final List<Node> stars = <Node>[
        for (int i = 0; i < 5; i++)
          coded(
            id: 's$i',
            slug: 's$i',
            code: '0$i',
            axis: Axis.major,
            slot: LevelSlot.star,
          ),
      ];
      final UniverseLayout layout = layoutUniverse(
        path: <Node>[root, galaxy],
        children: stars,
      );
      final Set<double> radii = layout.children.values
          .map((SkyPoint p) => p.radius)
          .toSet();
      expect(radii.length, 1);
      expect(radii.single, closeTo(34.012, 0.01));
    });

    test('空路径抛错，不给默认位置（ADR-0006 修订十二）', () {
      expect(
        () => layoutUniverse(path: const <Node>[], children: const <Node>[]),
        throwsArgumentError,
      );
    });

    test('只有一级且不是轴根时抛错（ADR-0006 修订十二）', () {
      final Node orphan = coded(id: 'x', slug: 'x', code: '01');
      expect(
        () => layoutUniverse(path: <Node>[orphan], children: const <Node>[]),
        throwsArgumentError,
      );
    });
  });

  group('真实骨架', () {
    /// 骨架包是装配产物、不入库，`app-checks` 现场跑装配脚本。
    /// **缺产物就 fail，不 skip** —— skip 会让「忘了装配」表现成绿灯。
    late PackContent content;
    late Map<String, String> parentOf;
    late Map<String, List<Node>> childrenOf;
    late List<Node> allNodes;

    setUpAll(() {
      final File file = File('../content/skeleton/pack.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: '骨架包没装配 —— 先跑 content/tools 下的装配脚本',
      );
      content = readPack(file.readAsStringSync());
      allNodes = content.nodes;
      parentOf = <String, String>{
        for (final ParentEdge edge in content.edges.whereType<ParentEdge>())
          if (edge.isMain) edge.childId: edge.parentId,
      };
      childrenOf = <String, List<Node>>{};
      parentOf.forEach((String child, String parent) {
        final Node? node = content.nodeById[child];
        if (node != null) {
          childrenOf.putIfAbsent(parent, () => <Node>[]).add(node);
        }
      });
    });

    /// 从轴根到 [node] 的完整路径。父链断了就停在那里，由各用例自己断言。
    List<Node> pathTo(Node node) {
      final List<Node> path = <Node>[node];
      String? parent = parentOf[node.id];
      int guard = 0;
      while (parent != null && guard++ < 16) {
        final Node? parentNode = content.nodeById[parent];
        if (parentNode == null) {
          break;
        }
        path.insert(0, parentNode);
        parent = parentOf[parent];
      }
      return path;
    }

    test('全部骨架节点都算得出落位，没有节点掉在坐标外（ADR-0006 修订十二）', () {
      expect(
        allNodes.length,
        greaterThan(3000),
        reason: 'ADRP 记录骨架 3,375 个节点；少于三千说明装配漏了轴',
      );

      int placed = 0;
      for (final Node node in allNodes) {
        final List<Node> path = pathTo(node);

        expect(
          path.first.levelSlot,
          LevelSlot.supercluster,
          reason: '${node.id} 的父链没走到轴根 —— 装配出的边不成树',
        );

        final UniverseLayout layout = layoutUniverse(
          path: path,
          children: childrenOf[node.id] ?? const <Node>[],
        );
        expect(layout.current.radius, greaterThan(0));
        placed++;
      }
      expect(placed, allNodes.length);
    });

    test('三轴最大的同父子集都能不叠放地落格（ADR-0006 修订十二）', () {
      int widest = 0;
      childrenOf.forEach((String parent, List<Node> kids) {
        if (kids.length > widest) {
          widest = kids.length;
        }
      });
      expect(
        universeChildCellCount,
        greaterThanOrEqualTo(widest),
        reason: '实测最大同父子数 $widest，格数 $universeChildCellCount 必须不低于它',
      );
    });

    test('同一父的子落位互不相同（子数不超格数的前提下）（ADR-0006 修订十二）', () {
      childrenOf.forEach((String parent, List<Node> kids) {
        final Node? parentNode = content.nodeById[parent];
        if (parentNode == null || kids.length > universeChildCellCount) {
          return;
        }
        final UniverseLayout layout = layoutUniverse(
          path: pathTo(parentNode),
          children: kids,
        );
        final Set<SkyPoint> points = layout.children.values.toSet();
        expect(
          points.length,
          kids.length,
          reason: '$parent 下有 ${kids.length} 个子却只落了 ${points.length} 个不同的格',
        );
      });
    });
  });

  group('从树取一片天', () {
    late TreeIndex tree;

    setUp(() {
      tree = treeFixture();
    });

    test('骨架星：来路自轴根起，载荷子级不进子级列表（ADR-0006 修订十四）', () {
      // `skeleton:d-0101` 是学科轴上的星，载荷 `python:sys` 挂在它下面。
      // 载荷没有球壳可上 —— 留着它，`layoutUniverse` 取层序时会抛。
      final UniverseView? view = layoutOfNode(tree, 'skeleton:d-0101');
      expect(view, isNotNull);
      expect(view!.anchorId, 'skeleton:d-0101');
      expect(view.axis, Axis.discipline);
      expect(view.layout.children, isEmpty, reason: '载荷子级不该出现在骨架的天上');
      expect(
        view.layout.ancestors,
        hasLength(2),
        reason: '哲学（门类）→ 学科（轴根），近的在前',
      );
      expect(view.layout.current.azimuthDeg, 0);
      expect(view.layout.current.elevationDeg, 0);
    });

    test('载荷节点上取最近的骨架祖先，不给近似坐标（ADR-0006 修订十四）', () {
      // 行星系没有槽位可上（`legalSkeletonSlots` 里没有 `system`）。给个近似
      // 位置等于承认 `system` 能挂在学科轴上 —— 与合法槽位表直接冲突。
      final UniverseView? view = layoutOfNode(tree, 'python:sys');
      expect(view, isNotNull);
      expect(view!.anchorId, 'skeleton:d-0101');
      expect(view.axis, Axis.discipline);
    });

    test('再深一级的载荷叶子上取到同一颗骨架星（ADR-0006 修订十四）', () {
      // `python:p1` → `python:sys` → 骨架星。上取要看整条来路，只看父会漏。
      final UniverseView? view = layoutOfNode(tree, 'python:p1');
      expect(view, isNotNull);
      expect(view!.anchorId, 'skeleton:d-0101');
    });

    test('轴根：来路为空、子级是该轴的直接子（ADR-0006 修订十四）', () {
      final UniverseView? view = layoutOfNode(tree, 'skeleton:d');
      expect(view, isNotNull);
      expect(view!.anchorId, 'skeleton:d');
      expect(view.layout.ancestors, isEmpty);
      expect(view.layout.children, hasLength(2), reason: '门类 `01` 与 `02`');
    });

    test('树里没有的 id 返回 null，不抛（ADR-0006 修订十四）', () {
      // 骨架未装载、地址过期都走这条路。返回 null 的语义是「这一片天画不出来」，
      // 由渲染层按「只画星空」处置 —— 不是拿一个空布局凑数。
      expect(layoutOfNode(tree, 'no-such-node'), isNull);
    });
  });
}
