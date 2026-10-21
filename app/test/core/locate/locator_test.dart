import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

import '../../support/pack_fixture.dart';

/// 五个项刻意包含「精确 + 子串」一对（`装饰器` / `装饰器参数`），
/// 它决定三态判在最强档还是全命中集上。
///
/// 树是三组域各挂若干个行星：域命中、项命中、圈定范围三类用例都要有东西可中。
PackContent _pack() {
  const List<String> planets = <String>[
    'python:lex-keyword',
    'python:lex-identifier',
    'python:ctl-if',
    'python:fn-decorator',
    'python:fn-decorator-params',
  ];
  return fixturePack(
    const <FixtureNode>[
      FixtureNode(
        'python:root',
        '研究生目录',
        slot: LevelSlot.supercluster,
      ),
      FixtureNode(
        'python:lexical',
        '词法',
        slot: LevelSlot.group,
        parentId: 'python:root',
      ),
      FixtureNode(
        'python:control',
        '控制',
        slot: LevelSlot.group,
        parentId: 'python:root',
      ),
      FixtureNode(
        'python:fn',
        '函数',
        slot: LevelSlot.group,
        parentId: 'python:root',
      ),
      FixtureNode('python:lex-keyword', '关键字', parentId: 'python:lexical'),
      FixtureNode('python:lex-identifier', '标识符', parentId: 'python:lexical'),
      FixtureNode('python:ctl-if', 'if 语句', parentId: 'python:control'),
      FixtureNode('python:fn-decorator', '装饰器', parentId: 'python:fn'),
      FixtureNode(
        'python:fn-decorator-params',
        '装饰器参数',
        parentId: 'python:fn',
      ),
    ],
    schemes: <String, List<String>>{'scheme-1': planets},
  );
}

/// 另一个包的最小形状。跨包判据不关心结构，只关心「另一个包里有没有同名
/// 或同 id 的东西」，所以域省掉、体系按需给。
///
/// [schemeNodes] 给一项就建一个只含这些节点的体系 —— `C-27` 的匹配面里
/// 「节点 id」是唯一能按 id 命中的字段。
PackContent _packOf({
  required String pluginId,
  required String packName,
  required List<FixtureNode> nodes,
  List<String>? schemeNodes,
}) => fixturePack(
  nodes,
  pluginId: pluginId,
  packName: packName,
  schemes: <String, List<String>>{'$pluginId-scheme': ?schemeNodes},
);

void main() {
  final Locator locator = Locator.single(_pack());

  group('定位三态', () {
    test('完整名字 ⇒ 有定位，落点就是该节点（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('装饰器');
      expect(result.state, LocateState.located);
      expect(result.top?.kind, LocateKind.item);
      expect(result.top?.target, 'python:fn-decorator');
      expect(result.top?.strength, MatchStrength.exact);
    });

    test('只有子串命中 ⇒ 部分命中，给候选（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('饰器');
      expect(result.state, LocateState.partial);
      expect(result.hits.length, 2);
      expect(
        result.hits.every((LocateHit h) => h.strength == MatchStrength.fuzzy),
        isTrue,
      );
    });

    test('全不中 ⇒ 无定位，命中集为空（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('zzz');
      expect(result.state, LocateState.none);
      expect(result.hits, isEmpty);
      expect(result.top, isNull);
    });

    test('命中域 ⇒ 部分命中（命中上层）（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('词法');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.domain);
      expect(result.top?.target, 'python:lexical');
    });

    test('命中轴根 ⇒ 部分命中，且归「空间」档（点它换整棵树）（SPEC-FND-006 / SPEC-FND-008）', () {
      final LocateResult result = locator.locate('研究生目录');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.space);
      expect(result.top?.target, 'python:root');
    });

    test('命中包名 ⇒ 部分命中（命中上层）（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('Python 语法分层');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.space);
      expect(result.top?.target, 'python');
    });

    test('命中轴取值 ⇒ 部分命中，且带上轴键供筛选（SPEC-VIEW-028）', () {
      final LocateResult result = locator.locate('专业');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.axis);
      expect(result.top?.target, 'major');
      expect(result.top?.axisKey, 'major');
    });
  });

  group('多命中的排序与判据', () {
    test('精确命中优先于子串命中，且精确那条唯一 ⇒ 直接落点（SPEC-VIEW-027）', () {
      final LocateResult result = locator.locate('装饰器');
      expect(result.hits.first.target, 'python:fn-decorator');
      expect(result.hits.last.target, 'python:fn-decorator-params');
      expect(result.state, LocateState.located);
    });

    test('强度相同看档位：轴根排前、域次之、项最后（SPEC-VIEW-029）', () {
      // `python:` 对所有节点 id 同为前缀命中 ⇒ 只看档位排序。
      final LocateResult result = locator.locate('python:');
      expect(result.state, LocateState.partial);
      final int lastDomain = result.hits.lastIndexWhere(
        (LocateHit h) => h.kind == LocateKind.domain,
      );
      final int firstItem = result.hits.indexWhere(
        (LocateHit h) => h.kind == LocateKind.item,
      );
      expect(lastDomain, isNonNegative);
      expect(firstItem, greaterThan(lastDomain));
      expect(result.hits.first.kind, LocateKind.space, reason: '轴根 id 也是前缀命中');
    });

    test('大小写与首尾空白不影响命中（SPEC-VIEW-029）', () {
      expect(locator.locate('  IF 语句 ').state, LocateState.located);
      expect(locator.locate('if 语句').top?.target, 'python:ctl-if');
    });

    test('空输入不产生命中，也不触发分诊（无 SPEC：空输入不构成搜索）', () {
      final LocateResult result = locator.locate('   ');
      expect(result.state, LocateState.none);
      expect(result.hits, isEmpty);
    });

    test('轴键名不命中，节点 id 命中（SPEC-VIEW-025）', () {
      expect(locator.locate('major').state, LocateState.none);
      final LocateResult byNodeId = locator.locate('python:lex-keyword');
      expect(byNodeId.state, LocateState.located);
      expect(byNodeId.top?.target, 'python:lex-keyword');
    });

    test('名字与 id 各算一条命中，但同一目标只留最强那条（C-27）', () {
      // 「装饰器」既不是 id 也不是子串，只有名字命中 ⇒ 该目标只出现一次。
      final LocateResult result = locator.locate('装饰器');
      expect(
        result.hits.where((LocateHit h) => h.target == 'python:fn-decorator'),
        hasLength(1),
      );
    });

    test('匹配字段常量与实现覆盖面对齐（C-27）', () {
      expect(searchMatchFields.toSet(), <String>{
        'node.name',
        'node.axis',
        'pack.name',
        'scheme.nodes',
      });
    });

    test('模糊档 = 子串包含：连续才命中，跨字不命中（C-28：v0.1 不设相似度阈值）', () {
      // 「饰器参」是「装饰器参数」里连续的一段 ⇒ 模糊档命中。
      final LocateResult contiguous = locator.locate('饰器参');
      expect(contiguous.top?.strength, MatchStrength.fuzzy);
      expect(contiguous.top?.target, 'python:fn-decorator-params');

      // 「饰器数」与「装饰器参数」只差一次替换 —— 编辑距离会判它「像」，
      // 子串包含不会。这就是 `C-28` 裁定的可判边界：模糊 = 连续包含，
      // 不是「相似度够不够」。将来若真做编辑距离，这条会红，提醒同步改判据。
      expect(locator.locate('饰器数').hits, isEmpty);
    });
  });

  group('跨包与作用域（SPEC-VIEW-031 / 033）', () {
    final PackContent python = _pack();
    final PackContent go = _packOf(
      pluginId: 'go',
      packName: 'Go 语言',
      nodes: const <FixtureNode>[
        // 与 Python 的项**同名**：这是 `VIEW-033` 存在的理由。
        FixtureNode('go:fn-decorator', '装饰器'),
        // 与 Python 的项**同 id**：去重键若不带包，两条会被并成一条。
        FixtureNode('python:fn-decorator', '闭包'),
      ],
      schemeNodes: <String>['go:fn-decorator', 'python:fn-decorator'],
    );

    test('两个包的同名项都在命中集里，各带自己的包（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<PackContent>[
        python,
        go,
      ]).locate('装饰器');
      // 精确命中两条（两包各一条）+ 模糊命中一条（Python 的「装饰器参数」）。
      final List<LocateHit> exact = result.hits
          .where((LocateHit h) => h.strength == MatchStrength.exact)
          .toList(growable: false);
      expect(exact.length, 2, reason: '两个包各一条，不许并成一条');
      expect(exact.map((LocateHit h) => h.packId).toSet(), <String>{
        'python',
        'go',
      });
      // 前缀要用包**名**（`VIEW-033` 的例子是 `Python › 装饰器`）。
      expect(exact.map((LocateHit h) => h.packName).toSet(), <String>{
        'Python 语法分层',
        'Go 语言',
      });
    });

    test('同 id 跨包不被去重并成一条 —— 去重键带包（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<PackContent>[
        python,
        go,
      ]).locate('闭包');
      // go 那份里 `python:fn-decorator` 的名字是「闭包」，与 python 同 id 不同名。
      expect(result.usableHits.length, 1);
      expect(result.usableHits.single.packId, 'go');
      final LocateResult byId = Locator(<PackContent>[
        python,
        go,
      ]).locate('python:fn-decorator');
      final List<LocateHit> exact = byId.hits
          .where((LocateHit h) => h.strength == MatchStrength.exact)
          .toList(growable: false);
      expect(exact.length, 2, reason: '同一个 id 在两个包里各是一条；并成一条就说明去重键少了包');
      expect(exact.map((LocateHit h) => h.packId).toSet(), <String>{
        'python',
        'go',
      });
    });

    test('作用域收窄 ⇒ 只回本包（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<PackContent>[
        python,
        go,
      ], pluginId: 'go').locate('装饰器');
      expect(result.usableHits.length, 1);
      expect(result.usableHits.single.packId, 'go');
    });

    test('作用域给了不存在的包 ⇒ 空，不放宽成全部包（SPEC-VIEW-031）', () {
      // 静默放宽会把「本包没搜到」变成「全部包没搜到」，两种结论的含义不同。
      final LocateResult result = Locator(<PackContent>[
        python,
        go,
      ], pluginId: 'rust').locate('装饰器');
      expect(result.hits, isEmpty);
      expect(result.state, LocateState.none);
    });

    test('两个包各有一处精确命中 ⇒ 部分命中，等用户选一次（SPEC-FND-008）', () {
      final LocateResult result = Locator(<PackContent>[
        python,
        go,
      ]).locate('装饰器');
      expect(result.state, LocateState.partial);
      expect(result.top, isNotNull);
    });

    test('空包列表是合法输入，不抛（无 SPEC：入参形状的兜底）', () {
      final LocateResult result = Locator(const <PackContent>[]).locate('装饰器');
      expect(result.hits, isEmpty);
      expect(result.state, LocateState.none);
    });
  });

  group('圈定范围（ADR-0007 决策 2：inScope 是派生值）', () {
    test('给了子树根 ⇒ 子树外的是圈外，进 hits 但进不了 usableHits（ADR-0007 决策 2）', () {
      final LocateResult result = Locator.single(
        _pack(),
        subtreeRoot: 'python:lexical',
      ).locate('装饰器');
      expect(result.hits, isNotEmpty, reason: '存在性归引擎 —— 它确实在库里');
      expect(result.usableHits, isEmpty);
      expect(result.state, LocateState.none);
      expect(result.hits.first.inScope, isFalse);
    });

    test('子树根自己算圈内（子树含根）（ADR-0007 决策 2）', () {
      final LocateResult result = Locator.single(
        _pack(),
        subtreeRoot: 'python:fn',
      ).locate('装饰器');
      expect(result.state, LocateState.located);
      expect(result.top?.inScope, isTrue);
    });

    test('不给子树根 ⇒ 不判圈内，每条命中都可用（ADR-0007 决策 2）', () {
      final LocateResult result = Locator.single(_pack()).locate('装饰器');
      expect(result.usableHits, isNotEmpty);
      expect(
        result.hits.every((LocateHit h) => h.inScope),
        isTrue,
      );
    });
  });
}
