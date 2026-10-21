import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/levels.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/alpha_pack.dart';

Edge _edge(String from, String to) =>
    Edge(id: '$from-$to', from: from, to: to, type: EdgeType.strong);

void main() {
  test('链：a→b→c 得 0 / 1 / 2（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: <Edge>[_edge('a', 'b'), _edge('b', 'c')],
    );
    expect(levels, <String, int>{'a': 0, 'b': 1, 'c': 2});
  });

  test('菱形：汇合点取两侧较深的一层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c', 'd'],
      edges: <Edge>[_edge('a', 'b'), _edge('a', 'c'), _edge('b', 'd'), _edge('c', 'd')],
    );
    expect(levels['d'], 2);
  });

  test('取最长前置链，不取最短（SPEC-VIEW-002）', () {
    // a→b→c 与 a→c 并存：c 的层号必须是 2，不能因为有一条直达边就算 1。
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: <Edge>[_edge('a', 'b'), _edge('b', 'c'), _edge('a', 'c')],
    );
    expect(levels['c'], 2);
  });

  test('孤立节点为 0 层，与入度为 0 的节点同层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'lonely'],
      edges: <Edge>[_edge('a', 'b')],
    );
    expect(levels['lonely'], 0);
  });

  test('空边集：全部 0 层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: const <Edge>[],
    );
    expect(levels.values.every((int value) => value == 0), isTrue);
  });

  test('端点不在册的边被忽略，不影响层号（无 SPEC：存在性校验在构建期，见 pack_parse 注释）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b'],
      edges: <Edge>[_edge('a', 'ghost'), _edge('ghost', 'b')],
    );
    expect(levels, <String, int>{'a': 0, 'b': 0});
  });

  test('边顺序不影响结果 —— 层号取 max，与入队顺序无关（SPEC-VIEW-002）', () {
    final List<Edge> edges = <Edge>[
      _edge('a', 'b'),
      _edge('b', 'c'),
      _edge('a', 'c'),
      _edge('c', 'd'),
    ];
    final Map<String, int> forward = kahnLevels(
      nodeIds: <String>['a', 'b', 'c', 'd'],
      edges: edges,
    );
    final Map<String, int> backward = kahnLevels(
      nodeIds: <String>['a', 'b', 'c', 'd'],
      edges: edges.reversed.toList(),
    );
    expect(backward, forward);
  });

  test('有环即抛错并列出卡住的节点，不返回半份结果（SPEC-FND-005）', () {
    expect(
      () => kahnLevels(
        nodeIds: <String>['a', 'b'],
        edges: <Edge>[_edge('a', 'b'), _edge('b', 'a')],
      ),
      throwsFormatException,
    );
  });

  test('真实 α 包：150 项全部有层号，最深 63 层（SPEC-VIEW-002）', () {
    final LoadedPack pack = loadAlphaPack();
    final Map<String, int> levels = kahnLevels(
      nodeIds: pack.items.map((Item item) => item.id),
      edges: pack.edges,
    );
    expect(levels.length, 150);
    int maxLevel = 0;
    int zeroLevel = 0;
    for (final int value in levels.values) {
      if (value > maxLevel) {
        maxLevel = value;
      }
      if (value == 0) {
        zeroLevel += 1;
      }
    }
    // 这两个数是内容侧事实，不是调出来的：α 包的 ⪯ 近乎一条长链。
    // 它们决定宇宙视图把 φ 直接当高度时会不会把节点推出画面，`B3` 必须知道。
    expect(maxLevel, 63);
    expect(zeroLevel, 3);
  });
}
