import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

Map<String, Object?> _item(String id, String title, String ability, String domainId) =>
    <String, Object?>{
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
  return parsePack(manifestJson: jsonEncode(manifest), packJson: jsonEncode(pack));
}

void main() {
  final Locator locator = Locator(_pack());

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
      expect(result.hits.every((LocateHit h) => h.strength == MatchStrength.fuzzy), isTrue);
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
      final int lastDomain =
          result.hits.lastIndexWhere((LocateHit h) => h.kind == LocateKind.domain);
      final int firstItem = result.hits.indexWhere((LocateHit h) => h.kind == LocateKind.item);
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
  });
}
