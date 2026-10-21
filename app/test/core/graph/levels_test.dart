import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/levels.dart';

PrerequisiteEdge _edge(
  String from,
  String to, {
  EdgeStrength strength = EdgeStrength.required,
}) => PrerequisiteEdge(fromId: from, toId: to, strength: strength);

void main() {
  test('链：a→b→c 得 0 / 1 / 2（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: <PrerequisiteEdge>[_edge('a', 'b'), _edge('b', 'c')],
    );
    expect(levels, <String, int>{'a': 0, 'b': 1, 'c': 2});
  });

  test('菱形：汇合点取两侧较深的一层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c', 'd'],
      edges: <PrerequisiteEdge>[
        _edge('a', 'b'),
        _edge('a', 'c'),
        _edge('b', 'd'),
        _edge('c', 'd'),
      ],
    );
    expect(levels['d'], 2);
  });

  test('取最长前置链，不取最短（SPEC-VIEW-002）', () {
    // a→b→c 与 a→c 并存：c 的层号必须是 2，不能因为有一条直达边就算 1。
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: <PrerequisiteEdge>[
        _edge('a', 'b'),
        _edge('b', 'c'),
        _edge('a', 'c'),
      ],
    );
    expect(levels['c'], 2);
  });

  test('孤立节点为 0 层，与入度为 0 的节点同层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'lonely'],
      edges: <PrerequisiteEdge>[_edge('a', 'b')],
    );
    expect(levels['lonely'], 0);
  });

  test('空边集：全部 0 层（SPEC-VIEW-002）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b', 'c'],
      edges: const <PrerequisiteEdge>[],
    );
    expect(levels.values.every((int value) => value == 0), isTrue);
  });

  test('端点不在册的边被忽略，不影响层号（无 SPEC：存在性校验在构建期）', () {
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b'],
      edges: <PrerequisiteEdge>[_edge('a', 'ghost'), _edge('ghost', 'b')],
    );
    expect(levels, <String, int>{'a': 0, 'b': 0});
  });

  test('`recommended` 不参与 ⪯：只被建议指向的节点仍在 0 层（ADR-0005 决策 4）', () {
    // 把它算进层号会让一个「只被建议指向」的项往后挪一层，看起来像它真有前置。
    final Map<String, int> levels = kahnLevels(
      nodeIds: <String>['a', 'b'],
      edges: <PrerequisiteEdge>[
        _edge('a', 'b', strength: EdgeStrength.recommended),
      ],
    );
    expect(levels, <String, int>{'a': 0, 'b': 0});
  });

  test('边顺序不影响结果 —— 层号取 max，与入队顺序无关（SPEC-VIEW-002）', () {
    final List<PrerequisiteEdge> edges = <PrerequisiteEdge>[
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
        edges: <PrerequisiteEdge>[_edge('a', 'b'), _edge('b', 'a')],
      ),
      throwsFormatException,
    );
  });
}
