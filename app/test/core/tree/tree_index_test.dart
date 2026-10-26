import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import '../../support/pack_fixture.dart';
import '../../support/tree_fixture.dart';

void main() {
  late TreeIndex tree;

  setUp(() {
    tree = treeFixture();
  });

  test('三条轴根同时在场，按 `Axis` 声明序（`SPEC-TREE-003`）', () {
    final List<TreeRow> roots = tree.axisRoots();
    expect(roots.map((TreeRow r) => r.axis).toList(), <Axis>[
      Axis.discipline,
      Axis.major,
      Axis.occupation,
    ]);
    expect(roots.map((TreeRow r) => r.nodeId).toList(), <String>[
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
    ]);
  });

  test('兄弟按官方码升序，无码的排在最后（`SPEC-TREE-011`）', () {
    expect(
      tree.childrenOf('skeleton:d').map((TreeRow r) => r.label).toList(),
      <String>['哲学', '经济学'],
      reason: '`02` 写在 `01` 前面，排序后应回到 `01` / `02`',
    );
    expect(
      tree.childrenOf('skeleton:d-01').map((TreeRow r) => r.label).toList(),
      <String>['马克思主义哲学', '补充方向'],
      reason: '无码的排在有码的之后',
    );
  });

  test('同一份数据建两次树，行序逐字相同（`SPEC-TREE-011`）', () {
    final List<String> first = tree
        .subtree('skeleton:d')
        .map((TreeRow r) => r.nodeId)
        .toList();
    final List<String> again = treeFixture()
        .subtree('skeleton:d')
        .map((TreeRow r) => r.nodeId)
        .toList();
    expect(again, first);
  });

  test('`path` 含轴根段，层深从轴根 `0` 起逐级 +1（`SPEC-TREE-006`）', () {
    expect(tree.pathOf('skeleton:d'), 'd');
    expect(tree.pathOf('skeleton:d-01'), 'd/d-01');
    expect(tree.pathOf('skeleton:d-0101'), 'd/d-01/d-0101');
    expect(tree.depthOf('skeleton:d'), 0);
    expect(tree.depthOf('skeleton:d-01'), 1);
    expect(tree.depthOf('skeleton:d-0101'), 2);
  });

  test('面包屑第 1 段是 `知识`，无地址、不可点（`SPEC-TREE-002`）', () {
    final List<BreadcrumbSegment> crumbs = tree.breadcrumb('skeleton:d-0101');
    expect(crumbs.first.label, '知识');
    expect(crumbs.first.path, isEmpty);
    expect(crumbs.first.isVirtualRoot, isTrue);
    expect(crumbs.skip(1).every((BreadcrumbSegment c) => c.path.isNotEmpty), isTrue);
  });

  test('`path` 段数 = 层深 + 1，含 `知识` 共 层深 + 2 段（`SPEC-TREE-006`）', () {
    expect(tree.breadcrumb('skeleton:d').length, 0 + 2);
    expect(tree.breadcrumb('skeleton:d-0101').length, 2 + 2);
    expect(tree.breadcrumb('python:p1').length, tree.depthOf('python:p1')! + 2);
    // 下面这条是两处口径的分界：`path` 段数比面包屑总段数少一段虚拟根。
    expect(
      tree.breadcrumb('skeleton:d-0101').length,
      tree.pathOf('skeleton:d-0101')!.split('/').length + 1,
    );
  });

  test('段名取 `name`，不是 `slug`（`SPEC-TREE-006`）', () {
    expect(
      tree.breadcrumb('skeleton:d-0101').map((BreadcrumbSegment c) => c.label).toList(),
      <String>['知识', '学科', '哲学', '马克思主义哲学'],
    );
  });

  test('换根后本子树算得出相对路径，子树外为 `null`（`SPEC-TREE-005`）', () {
    expect(tree.relativePath(rootId: 'skeleton:d-01', nodeId: 'skeleton:d-0101'), 'd-0101');
    expect(tree.relativePath(rootId: 'skeleton:d-01', nodeId: 'skeleton:d-01'), isEmpty);
    expect(tree.relativePath(rootId: 'skeleton:m', nodeId: 'skeleton:d-0101'), isNull);
    expect(tree.relativePath(rootId: 'skeleton:d', nodeId: 'skeleton:o'), isNull);
  });

  test('子树前序展开含自己，跨轴不串门（`SPEC-TREE-001`）', () {
    expect(tree.subtree('skeleton:d').map((TreeRow r) => r.nodeId).toList(), <String>[
      'skeleton:d',
      'skeleton:d-01',
      'skeleton:d-0101',
      'python:sys',
      'python:p1',
      'skeleton:d-x',
      'skeleton:d-02',
    ]);
  });

  test('载荷节点接在骨架恒星之后，深度续算（`SPEC-TREE-001`）', () {
    expect(tree.pathOf('python:sys'), 'd/d-01/d-0101/sys');
    expect(tree.depthOf('python:p1'), 4);
  });

  test('主父不唯一即拒（无 SPEC：`entity-fields` §3 只写了「主父唯一」，树索引自建时没人查）', () {
    final PackContent base = skeletonFixture();
    // 直接拼 `PackContent` 而不走夹具：夹具按 `parentId` 只生成一条 `main` 边，
    // 造不出「同一子两条主父」。这里测的是树索引的父边去重，不是解析层。
    final PackContent broken = PackContent(
      pack: base.pack,
      nodes: base.nodes,
      edges: <NodeEdge>[
        ...base.edges,
        const ParentEdge(
          childId: 'skeleton:d-0101',
          parentId: 'skeleton:d-02',
          kind: ParentEdgeKind.main,
        ),
      ],
      entries: base.entries,
      sources: base.sources,
      schemes: base.schemes,
      methods: base.methods,
    );
    expect(() => TreeIndex.build(contents: <PackContent>[broken]), throwsArgumentError);
  });

  test('同轴两条无父链即拒（无 SPEC：`TREE-001` 只说每轴一个根，第二条出现时无断言）', () {
    final PackContent twoRoots = fixturePack(
      <FixtureNode>[
        FixtureNode('skeleton:d', '学科', slot: LevelSlot.supercluster, axis: Axis.discipline),
        FixtureNode('skeleton:d2', '第二条根', slot: LevelSlot.supercluster, axis: Axis.discipline),
      ],
      pluginId: 'skeleton',
      packName: '骨架夹具',
      kinds: const <String>[],
    );
    expect(() => TreeIndex.build(contents: <PackContent>[twoRoots]), throwsArgumentError);
  });
}
