import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/events/migration.dart';

CarryLink _carry(String from, List<String> toItemIds, {double? ratio}) => CarryLink(
  eventId: 'carry-$from',
  from: from,
  toItemIds: toItemIds,
  ratio: ratio ?? 1 / toItemIds.length,
);

MergeLink _merge(List<String> fromItemIds, String toItemId) => MergeLink(
  eventId: 'merge-$toItemId',
  fromItemIds: fromItemIds,
  toItemId: toItemId,
);

void main() {
  test('空账本原样返回（C-12）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'a': 10},
      carries: const <CarryLink>[],
      merges: const <MergeLink>[],
    );
    expect(result, <String, double>{'a': 10});
  });

  test('拆分：子项各拿源项 S 的 1/n（C-12）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'a': 9},
      carries: <CarryLink>[_carry('a', <String>['b', 'c', 'd'])],
      merges: const <MergeLink>[],
    );
    expect(result['b'], closeTo(3, 1e-12));
    expect(result['c'], closeTo(3, 1e-12));
    expect(result['d'], closeTo(3, 1e-12));
  });

  test('拆分不删源项，孤儿项仍有值（SPEC-FND-012）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'a': 9},
      carries: <CarryLink>[_carry('a', <String>['b', 'c'])],
      merges: const <MergeLink>[],
    );
    expect(result['a'], 9);
  });

  test('合并：取各源项最大 S，不是求和（C-13）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'b': 4, 'c': 11, 'd': 7},
      carries: const <CarryLink>[],
      merges: <MergeLink>[_merge(<String>['b', 'c', 'd'], 'merged')],
    );
    expect(result['merged'], 11);
  });

  test('二次拆分：比例连乘（C-12）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'a': 8},
      carries: <CarryLink>[
        _carry('a', <String>['b', 'c']),
        _carry('b', <String>['d', 'e']),
      ],
      merges: const <MergeLink>[],
    );
    expect(result['b'], closeTo(4, 1e-12));
    expect(result['d'], closeTo(2, 1e-12));
    expect(result['e'], closeTo(2, 1e-12));
  });

  test('账本顺序颠倒也得到同一结果（C-12）', () {
    // 账本顺序 = 事件时间序，但折算必须与顺序无关，否则重放结果会飘。
    final List<CarryLink> forward = <CarryLink>[
      _carry('a', <String>['b', 'c']),
      _carry('b', <String>['d', 'e']),
    ];
    final Map<String, double> a = carryStability(
      source: <String, double>{'a': 8},
      carries: forward,
      merges: const <MergeLink>[],
    );
    final Map<String, double> b = carryStability(
      source: <String, double>{'a': 8},
      carries: forward.reversed.toList(),
      merges: const <MergeLink>[],
    );
    expect(b['d'], closeTo(a['d']!, 1e-12));
    expect(b['e'], closeTo(a['e']!, 1e-12));
  });

  test('重放同一账本结果不变（幂等）（C-12）', () {
    final Map<String, double> once = carryStability(
      source: <String, double>{'a': 8},
      carries: <CarryLink>[_carry('a', <String>['b', 'c'])],
      merges: <MergeLink>[_merge(<String>['b', 'c'], 'merged')],
    );
    final Map<String, double> twice = carryStability(
      source: once,
      carries: <CarryLink>[_carry('a', <String>['b', 'c'])],
      merges: <MergeLink>[_merge(<String>['b', 'c'], 'merged')],
    );
    expect(twice, once);
  });

  test('源项没有 S 时不造 0 值（SPEC-FND-014）', () {
    final Map<String, double> result = carryStability(
      source: const <String, double>{},
      carries: <CarryLink>[_carry('never-learned', <String>['b', 'c'])],
      merges: <MergeLink>[_merge(<String>['x', 'y'], 'merged')],
    );
    expect(result.containsKey('b'), isFalse);
    expect(result.containsKey('merged'), isFalse);
    expect(result, isEmpty);
  });

  test('目标项已有更大实测值时不覆盖（C-12）', () {
    final Map<String, double> result = carryStability(
      source: <String, double>{'a': 4, 'b': 20},
      carries: <CarryLink>[_carry('a', <String>['b', 'c'])],
      merges: const <MergeLink>[],
    );
    expect(result['b'], 20);
  });
}
