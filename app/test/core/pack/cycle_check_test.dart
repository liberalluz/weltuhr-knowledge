import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/cycle_check.dart';

List<({String from, String to})> _edges(List<List<String>> pairs) =>
    <({String from, String to})>[
      for (final List<String> pair in pairs) (from: pair.first, to: pair.last),
    ];

void main() {
  group('⪯ 环检测', () {
    test('无环图返回空（SPEC-FND-005）', () {
      expect(findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'b'],
        <String>['b', 'c'],
      ])), isEmpty);
    });

    test('菱形不是环 —— 共享后继不能误报（SPEC-FND-005）', () {
      expect(findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'b'],
        <String>['a', 'c'],
        <String>['b', 'd'],
        <String>['c', 'd'],
      ])), isEmpty);
    });

    test('自环跳过：那是数据错误，不是环（SPEC-FND-005）', () {
      expect(findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'a'],
        <String>['a', 'b'],
      ])), isEmpty);
    });

    test('二元环报一条，首尾闭合（SPEC-FND-005）', () {
      expect(findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'b'],
        <String>['b', 'a'],
      ])), <List<String>>[
        <String>['a', 'b', 'a'],
      ]);
    });

    test('环的起点归一为最小 id —— 不归一，同一个环换个入口就会被当成新环（SPEC-FND-005）', () {
      final List<List<String>> cycles = findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'c'],
        <String>['c', 'b'],
        <String>['b', 'c'],
      ]));
      expect(cycles, <List<String>>[
        <String>['b', 'c', 'b'],
      ]);
    });

    test('两个互不相连的环各报一条（SPEC-FND-005）', () {
      final List<List<String>> cycles = findCyclesFrom(_edges(<List<String>>[
        <String>['a', 'b'],
        <String>['b', 'a'],
        <String>['x', 'y'],
        <String>['y', 'x'],
      ]));
      expect(cycles.length, 2);
      expect(cycles, containsAll(<List<String>>[
        <String>['a', 'b', 'a'],
        <String>['x', 'y', 'x'],
      ]));
    });
  });
}
