import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/precedence.dart';

PrerequisiteEdge _edge(
  String from,
  String to, {
  EdgeStrength strength = EdgeStrength.required,
}) => PrerequisiteEdge(fromId: from, toId: to, strength: strength);

List<String> _predecessorsOf(String nodeId, List<PrerequisiteEdge> edges) =>
    requiredPredecessorsOf(nodeId: nodeId, edges: edges);

void main() {
  group('precedence（`⪯` 的唯一实现）', () {
    test('TC-FND-008 传递闭包：a→b→c 时 c 的前置是 b 与 a，由近及远（SPEC-FND-005）', () {
      expect(
        _predecessorsOf('c', <PrerequisiteEdge>[_edge('a', 'b'), _edge('b', 'c')]),
        <String>['b', 'a'],
      );
    });

    test('TC-FND-009 `recommended` 不构成前置，也不逐跳累积（ADR-0005 决策 4）', () {
      // 全是 suggested：三段链路跑完，c 仍然「不必先学任何东西」。
      expect(
        _predecessorsOf('c', <PrerequisiteEdge>[
          _edge('a', 'b', strength: EdgeStrength.recommended),
          _edge('b', 'c', strength: EdgeStrength.recommended),
        ]),
        isEmpty,
      );
    });

    test('TC-FND-010 混合边集：`recommended` 不越权，但同层的 `required` 照常传递（ADR-0005 决策 4）', () {
      // a → b（必学）· b ⇢ c（建议）· b → d（必学）
      final List<PrerequisiteEdge> edges = <PrerequisiteEdge>[
        _edge('a', 'b'),
        _edge('b', 'c', strength: EdgeStrength.recommended),
        _edge('b', 'd'),
      ];
      expect(_predecessorsOf('d', edges), <String>['b', 'a']);
      // c 只被建议指向 b，可它自己还有一条必学的路：a → b 是必学、b ⇢ c 是建议，
      // 于是 c 的前置应当只有「沿途全是必学」的那一段，也就是空集合。
      expect(_predecessorsOf('c', edges), isEmpty);
    });

    test('TC-FND-011 自环被跳过，不死循环（无 SPEC：自环是数据错误，构建期另报）', () {
      expect(_predecessorsOf('a', <PrerequisiteEdge>[_edge('a', 'a')]), isEmpty);
    });

    test('TC-FND-012 成环时闭包仍是有限集，不死循环（SPEC-FND-005）', () {
      // 环该由加载期拒（TC-FND-015），但本函数不能把「数据坏了」表现为挂死。
      expect(
        _predecessorsOf('a', <PrerequisiteEdge>[_edge('a', 'b'), _edge('b', 'a')]),
        <String>['b'],
      );
    });

    test('TC-FND-013 两份边集交替调用互不污染，返回值改动不影响下次（`V1` 不物化闭包）', () {
      final List<PrerequisiteEdge> left = <PrerequisiteEdge>[_edge('a', 'b')];
      final List<PrerequisiteEdge> right = <PrerequisiteEdge>[_edge('x', 'y')];

      // ① 交替调用：若按节点 id 缓存了一份闭包，第三次会取到第一轮的结果。
      expect(_predecessorsOf('b', left), <String>['a']);
      expect(_predecessorsOf('y', right), <String>['x']);
      expect(_predecessorsOf('b', right), isEmpty);

      // ② 返回的列表是可改的、且不是内部那份：清空它，下次调用照旧。
      final List<String> first = _predecessorsOf('b', left);
      first.clear();
      expect(_predecessorsOf('b', left), <String>['a']);
    });

    test('TC-FND-014 `isRequiredBefore` 严格：自己不先于自己（SPEC-FND-005）', () {
      final List<PrerequisiteEdge> edges = <PrerequisiteEdge>[_edge('a', 'b')];
      expect(isRequiredBefore(a: 'a', b: 'b', edges: edges), isTrue);
      expect(isRequiredBefore(a: 'b', b: 'a', edges: edges), isFalse);
      expect(isRequiredBefore(a: 'a', b: 'a', edges: edges), isFalse);
    });
  });
}
