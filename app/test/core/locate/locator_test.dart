import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

Map<String, Object?> _item(
  String id,
  String title,
  String ability,
  String domainId,
) => <String, Object?>{
  'id': id,
  'title': title,
  'sixAxis': <String, String>{'subject': '计算机科学', 'ability': ability},
  'layer': 'persistent',
  'type': 'declarative',
  'requirements': <String, Object?>{
    'boundary': 'present',
    'justification': 'present',
    'proposition': 'present',
    'relation': 'present',
    'how': 'present',
    'tacit': 'not_externalizable',
  },
  'sourceRefs': <String>[],
  'domainId': domainId,
  'inScope': true,
};

/// 四个项刻意包含「精确 + 子串」一对（`装饰器` / `装饰器参数`），
/// 它决定三态判在最强档还是全命中集上。
LoadedPack _pack() {
  const List<String> ids = <String>[
    'python/lex-keyword',
    'python/lex-identifier',
    'python/ctl-if',
    'python/fn-decorator',
    'python/fn-decorator-params',
  ];
  final Map<String, Object?> manifest = <String, Object?>{
    'id': 'python',
    'name': 'Python 语法分层',
    'version': '0.1.0',
    'sixAxis': <String, String>{'subject': '计算机科学'},
    'accent': '#3776ab',
    'order': 10,
    'domainIds': <String>['python/lexical', 'python/control', 'python/func'],
  };
  final Map<String, Object?> pack = <String, Object?>{
    'meta': <String, Object?>{'space': 'python', 'version': '0.1.0'},
    'items': <Map<String, Object?>>[
      _item('python/lex-keyword', '关键字', '基础语法', 'python/lexical'),
      _item('python/lex-identifier', '标识符', '基础语法', 'python/lexical'),
      _item('python/ctl-if', 'if 语句', '控制流', 'python/control'),
      _item('python/fn-decorator', '装饰器', '抽象', 'python/func'),
      _item('python/fn-decorator-params', '装饰器参数', '抽象', 'python/func'),
    ],
    'edges': <Map<String, Object?>>[],
    'schemes': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'scheme-1',
        'name': '语法分层',
        'nodes': ids,
        'authorityLevel': 'L1',
      },
    ],
    'questions': <Map<String, Object?>>[],
    'excerpts': <Map<String, Object?>>[],
  };
  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

/// 另一个空间的最小包。跨空间判据不关心形状，只关心「另一个空间里有没有同名
/// 或同 id 的东西」，所以域从项里推、边留空。
///
/// [schemeNodes] 给一项就建一个只含这些节点的体系 —— `C-27` 的匹配面里
/// 「节点 id」是唯一能按 id 命中的字段。
LoadedPack _spaceOf({
  required String spaceId,
  required String spaceName,
  required List<Map<String, Object?>> items,
  List<String>? schemeNodes,
}) {
  final Map<String, Object?> manifest = <String, Object?>{
    'id': spaceId,
    'name': spaceName,
    'version': '0.1.0',
    'sixAxis': <String, String>{'subject': '计算机科学'},
    'accent': '#00add8',
    'order': 20,
    'domainIds': <String>{
      for (final Map<String, Object?> item in items)
        item['domainId']! as String,
    }.toList(growable: false),
  };
  final Map<String, Object?> pack = <String, Object?>{
    'meta': <String, Object?>{'space': spaceId, 'version': '0.1.0'},
    'items': items,
    'edges': <Map<String, Object?>>[],
    'schemes': <Map<String, Object?>>[
      if (schemeNodes != null)
        <String, Object?>{
          'id': '$spaceId-scheme',
          'name': '$spaceName 体系',
          'nodes': schemeNodes,
          'authorityLevel': 'L1',
        },
    ],
    'questions': <Map<String, Object?>>[],
    'excerpts': <Map<String, Object?>>[],
  };
  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

void main() {
  final Locator locator = Locator.single(_pack());

  group('定位三态', () {
    test('完整标题 ⇒ 有定位，落点就是该项（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('装饰器');
      expect(result.state, LocateState.located);
      expect(result.top?.kind, LocateKind.item);
      expect(result.top?.target, 'python/fn-decorator');
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
      final LocateResult result = locator.locate('python/lexical');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.domain);
    });

    test('命中空间名 ⇒ 部分命中（命中上层）（SPEC-FND-008）', () {
      final LocateResult result = locator.locate('Python 语法分层');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.space);
      expect(result.top?.target, 'python');
    });

    test('命中轴取值 ⇒ 部分命中，且带上轴键供筛选（SPEC-VIEW-028）', () {
      final LocateResult result = locator.locate('控制流');
      expect(result.state, LocateState.partial);
      expect(result.top?.kind, LocateKind.axis);
      expect(result.top?.target, '控制流');
      expect(result.top?.axisKey, 'ability');
    });
  });

  group('多命中的排序与判据', () {
    test('精确命中优先于子串命中，且精确那条唯一 ⇒ 直接落点（SPEC-VIEW-027）', () {
      final LocateResult result = locator.locate('装饰器');
      expect(result.hits.first.target, 'python/fn-decorator');
      expect(result.hits.last.target, 'python/fn-decorator-params');
      expect(result.state, LocateState.located);
    });

    test('强度相同看档位：域排在项前（SPEC-VIEW-029）', () {
      // `python/` 对三个域名与五个节点 id 同为前缀命中 ⇒ 只看档位排序。
      final LocateResult result = locator.locate('python/');
      expect(result.state, LocateState.partial);
      final int lastDomain = result.hits.lastIndexWhere(
        (LocateHit h) => h.kind == LocateKind.domain,
      );
      final int firstItem = result.hits.indexWhere(
        (LocateHit h) => h.kind == LocateKind.item,
      );
      expect(lastDomain, isNonNegative);
      expect(firstItem, greaterThan(lastDomain));
    });

    test('大小写与首尾空白不影响命中（SPEC-VIEW-029）', () {
      expect(locator.locate('  IF 语句 ').state, LocateState.located);
      expect(locator.locate('if 语句').top?.target, 'python/ctl-if');
    });

    test('空输入不产生命中，也不触发分诊（无 SPEC：空输入不构成搜索）', () {
      final LocateResult result = locator.locate('   ');
      expect(result.state, LocateState.none);
      expect(result.hits, isEmpty);
    });

    test('匹配面只到 C-27 的五个字段：轴键名不命中，节点 id 命中（SPEC-VIEW-025）', () {
      expect(locator.locate('ability').state, LocateState.none);
      final LocateResult byNodeId = locator.locate('python/lex-keyword');
      expect(byNodeId.state, LocateState.located);
      expect(byNodeId.top?.target, 'python/lex-keyword');
    });

    test('匹配字段常量与实现覆盖面对齐（C-27）', () {
      expect(searchMatchFields.toSet(), <String>{
        'item.title',
        'item.domainId',
        'space.name',
        'item.sixAxis',
        'scheme.nodes',
      });
    });

    test('模糊档 = 子串包含：连续才命中，跨字不命中（C-28：v0.1 不设相似度阈值）', () {
      // 「饰器参」是「装饰器参数」里连续的一段 ⇒ 模糊档命中。
      final LocateResult contiguous = locator.locate('饰器参');
      expect(contiguous.top?.strength, MatchStrength.fuzzy);
      expect(contiguous.top?.target, 'python/fn-decorator-params');

      // 「饰器数」与「装饰器参数」只差一次替换 —— 编辑距离会判它「像」，
      // 子串包含不会。这就是 `C-28` 裁定的可判边界：模糊 = 连续包含，
      // 不是「相似度够不够」。将来若真做编辑距离，这条会红，提醒同步改判据。
      expect(locator.locate('饰器数').hits, isEmpty);
    });
  });

  group('跨空间与作用域（SPEC-VIEW-031 / 033）', () {
    final LoadedPack python = _pack();
    final LoadedPack go = _spaceOf(
      spaceId: 'go',
      spaceName: 'Go 语言',
      items: <Map<String, Object?>>[
        // 与 Python 的项**同名**：这是 `VIEW-033` 存在的理由。
        _item('go/fn-decorator', '装饰器', '抽象', 'go/func'),
        // 与 Python 的项**同 id**：去重键若不带空间，两条会被并成一条。
        _item('python/fn-decorator', '闭包', '抽象', 'python/func'),
      ],
      schemeNodes: <String>['go/fn-decorator', 'python/fn-decorator'],
    );

    test('两个空间的同名项都在命中集里，各带自己的空间（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<LoadedPack>[python, go])
          .locate('装饰器');
      // 精确命中两条（两空间各一条）+ 模糊命中一条（Python 的「装饰器参数」）。
      final List<LocateHit> exact = result.hits
          .where((LocateHit h) => h.strength == MatchStrength.exact)
          .toList(growable: false);
      expect(exact.length, 2, reason: '两个空间各一条，不许并成一条');
      expect(exact.map((LocateHit h) => h.spaceId).toSet(), <String>{
        'python',
        'go',
      });
      // 前缀要用空间**名**（`VIEW-033` 的例子是 `Python › 装饰器`）。
      expect(exact.map((LocateHit h) => h.spaceName).toSet(), <String>{
        'Python 语法分层',
        'Go 语言',
      });
    });

    test('同 id 跨空间不被去重并成一条 —— 去重键带空间（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<LoadedPack>[python, go])
          .locate('闭包');
      // go 那份里 `python/fn-decorator` 的标题是「闭包」，与 python 同名 id 不同标题。
      expect(result.usableHits.length, 1);
      expect(result.usableHits.single.spaceId, 'go');
      final LocateResult byId = Locator(<LoadedPack>[python, go])
          .locate('python/fn-decorator');
      final List<LocateHit> exact = byId.hits
          .where((LocateHit h) => h.strength == MatchStrength.exact)
          .toList(growable: false);
      expect(exact.length, 2, reason: '同一个 id 在两个空间里各是一条；并成一条就说明去重键少了空间');
      expect(exact.map((LocateHit h) => h.spaceId).toSet(), <String>{
        'python',
        'go',
      });
    });

    test('作用域收窄 ⇒ 只回本空间（SPEC-VIEW-031）', () {
      final LocateResult result = Locator(<LoadedPack>[
        python,
        go,
      ], spaceId: 'go').locate('装饰器');
      expect(result.usableHits.length, 1);
      expect(result.usableHits.single.spaceId, 'go');
    });

    test('作用域给了不存在的空间 ⇒ 空，不放宽成全部空间（SPEC-VIEW-031）', () {
      // 静默放宽会把「本空间没搜到」变成「全部空间没搜到」，两种结论的含义不同。
      final LocateResult result = Locator(<LoadedPack>[
        python,
        go,
      ], spaceId: 'rust').locate('装饰器');
      expect(result.hits, isEmpty);
      expect(result.state, LocateState.none);
    });

    test('两个空间各有一处精确命中 ⇒ 部分命中，等用户选一次（SPEC-FND-008）', () {
      final LocateResult result = Locator(<LoadedPack>[python, go])
          .locate('装饰器');
      expect(result.state, LocateState.partial);
      expect(result.top, isNotNull);
    });

    test('空包列表是合法输入，不抛（无 SPEC：入参形状的兜底）', () {
      final LocateResult result = Locator(const <LoadedPack>[]).locate('装饰器');
      expect(result.hits, isEmpty);
      expect(result.state, LocateState.none);
    });
  });
}
