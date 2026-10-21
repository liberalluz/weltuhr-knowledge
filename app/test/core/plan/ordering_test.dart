import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/candidates.dart';
import 'package:project_knowledge/core/plan/method_bundle.dart';
import 'package:project_knowledge/core/plan/ordering.dart';

/// 一条最短的 `⪯` 链 `i-a ⪯ i-b ⪯ i-c` + 一个游离项 `i-d`。
///
/// 三套体系刻意做成：**线性扩展**（0 处逆序）· **整段倒过来**（2 处）·
/// **换一对位置**（1 处）—— 逆序数若只是「序列长了几对倒置」而不是「几条前提边
/// 被倒置」，这三套的读数会完全不同，用例才分得开。
///
/// 四条源覆盖 `L0` / `L1` / `L2` / `L4`，另加一条 `L3`：`entity-fields` §一.6 的
/// 取值域里**没有** `L3`，用它测「未知等级不许被推荐到第一位」。
LoadedPack _pack() {
  final List<Map<String, Object?>> items = <Map<String, Object?>>[
    _item('i-a', 'A 边界', 'declarative', <String>['src-l2']),
    _item('i-b', 'B 归纳', 'procedural', <String>['src-l1']),
    _item('i-c', 'C 装饰器', 'skill', <String>['src-l0']),
    _item('i-d', 'D 游离项', 'tacit', <String>[]),
  ];

  final Map<String, Object?> manifest = <String, Object?>{
    'id': 'python',
    'name': 'Python',
    'version': '0.1.0',
    'sixAxis': <String, String>{'subject': '计算机科学'},
    'accent': '#3776ab',
    'order': 10,
    'domainIds': <String>['python/lexical'],
  };

  final Map<String, Object?> pack = <String, Object?>{
    'meta': <String, Object?>{'space': 'python', 'version': '0.1.0'},
    'items': items,
    'edges': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'e1',
        'from': 'i-a',
        'to': 'i-b',
        'type': 'strong',
      },
      <String, Object?>{
        'id': 'e2',
        'from': 'i-b',
        'to': 'i-c',
        'type': 'strong',
      },
    ],
    'schemes': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'scheme-linear',
        'name': '原序',
        'nodes': <String>['i-a', 'i-b', 'i-c', 'i-d'],
        'authorityLevel': 'L1',
      },
      <String, Object?>{
        'id': 'scheme-reversed',
        'name': '工程路线',
        'nodes': <String>['i-c', 'i-b', 'i-a'],
        'authorityLevel': 'L2',
      },
      <String, Object?>{
        'id': 'scheme-swapped',
        'name': '换一对位置',
        'nodes': <String>['i-a', 'i-c', 'i-b'],
        'authorityLevel': 'L2',
      },
      <String, Object?>{
        'id': 'scheme-dec-only',
        'name': '只含一个陈述项',
        'nodes': <String>['i-a'],
        'authorityLevel': 'L0',
      },
    ],
    'questions': <Map<String, Object?>>[],
    'excerpts': <Map<String, Object?>>[
      _excerpt('src-l0', 'L0 标准', 'L0'),
      _excerpt('src-l1', 'L1 官方文档', 'L1'),
      _excerpt('src-l2', 'L2 教材', 'L2'),
      _excerpt('src-l3', 'L3 不在册', 'L3'),
      _excerpt('src-l4', 'L4 社区', 'L4'),
    ],
  };

  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

Map<String, Object?> _item(
  String id,
  String title,
  String type,
  List<String> sourceRefs,
) => <String, Object?>{
  'id': id,
  'title': title,
  'sixAxis': <String, String>{'subject': '计算机科学', 'ability': '基础语法'},
  'layer': 'persistent',
  'type': type,
  'requirements': <String, Object?>{
    'boundary': 'present',
    'justification': 'present',
    'proposition': 'present',
    'relation': 'present',
    'how': 'present',
    'tacit': 'not_externalizable',
  },
  'sourceRefs': sourceRefs,
  'domainId': 'python/lexical',
  'inScope': true,
};

Map<String, Object?> _excerpt(String id, String name, String level) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'authorityLevel': level,
      'version': '1.0',
      'segments': <Map<String, Object?>>[
        <String, Object?>{
          'text': '摘录正文',
          'locator': '§1',
          'license': 'PSF-2.0',
        },
      ],
      'appliesTo': <String, Object?>{'spaceId': 'python'},
    };

MethodBundle _bundle(String id, String name, Map<ItemType, String> byType) =>
    MethodBundle(
      id: id,
      name: name,
      origin: CandidateOrigin.user,
      byType: byType,
    );

void main() {
  group('源段的排序键：出处等级（SPEC-PLAN-020）', () {
    test('TC-PLAN-019 L0 → L1 → L2 → L4 依次靠前，不是字母序（SPEC-PLAN-020）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.sources.map((SourceCandidate c) => c.id),
        <String>['src-l0', 'src-l1', 'src-l2', 'src-l4', 'src-l3'],
      );
      expect(
        authorityLevelOrder,
        <String>['L0', 'L1', 'L2', 'L4'],
        reason: '`L3` 不在册 —— 取值域就是这四个，按字母序会把它们排成 L0/L1/L2/L4 的巧合掩盖掉',
      );
    });

    test('TC-PLAN-020 未知等级排最后：不抛错、也不被删（无 SPEC：`PLAN-020` 只给了四级，未认等级的位置本笔补）', () {
      final CandidateSet set = loadCandidates(_pack());
      final SourceCandidate last = set.sources.last;

      expect(last.id, 'src-l3');
      expect(authorityRank('L3'), authorityLevelOrder.length);
      expect(authorityRank('L0'), 0);
      expect(
        set.sources.length,
        5,
        reason: '不认识的等级排最后 ≠ 被过滤掉',
      );
    });

    test('TC-PLAN-021 同一等级并列时保持包声明顺序（无 SPEC：`PLAN-020` 只给键，并列的回落本笔补）', () {
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[
          SourceRef.fromJson(_excerpt('src-user-1', '自建一', 'L4')),
          SourceRef.fromJson(_excerpt('src-user-2', '自建二', 'L4')),
        ],
      );

      final List<String> order = <String>[
        for (final SourceCandidate c in set.sources)
          if (c.authorityLevel == 'L4') c.id,
      ];
      expect(order, <String>['src-l4', 'src-user-1', 'src-user-2']);
    });
  });

  group('体系段的逆序数（SPEC-PLAN-012）', () {
    test('TC-PLAN-022 线性扩展 ⇒ 0 处逆序，显示「本序无逆序」（SPEC-PLAN-012）', () {
      final LoadedPack pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-linear'),
        edges: pack.edges,
        itemById: pack.itemById,
      );

      expect(cost.inversions, 0);
      expect(cost.isLinearExtension, isTrue);
      expect(cost.firstBlockedStep, isNull);
      expect(cost.display, '本序无逆序');
    });

    test('TC-PLAN-023 整段倒过来 ⇒ 2 处逆序，第 1 步卡住（SPEC-PLAN-012）', () {
      final LoadedPack pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-reversed'),
        edges: pack.edges,
        itemById: pack.itemById,
      );

      expect(
        cost.inversions,
        2,
        reason: '数的是**前提边**（两条各被倒置一次），不是「序列里倒置的项对」',
      );
      expect(cost.firstBlockedStep, 1);
      expect(cost.firstBlockedItemName, 'C 装饰器');
      expect(cost.display, '本序 2 处逆序，第 1 步会卡在 C 装饰器');
    });

    test('TC-PLAN-024 只换一对位置 ⇒ 1 处逆序，第 2 步卡住（SPEC-PLAN-012）', () {
      final LoadedPack pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-swapped'),
        edges: pack.edges,
        itemById: pack.itemById,
      );

      expect(cost.inversions, 1);
      expect(
        cost.firstBlockedStep,
        2,
        reason: '`i-c` 排在位置 1 ⇒ 第 2 步；取最早的那个位置，不是最后一条边',
      );
      expect(cost.firstBlockedItemName, 'C 装饰器');
    });

    test('TC-PLAN-025 一端不在序列里的边不算逆序（无 SPEC：`entity-fields` 只说「倒置了多少条前提边」，缺端点的边本笔补）', () {
      final LoadedPack pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-dec-only'),
        edges: pack.edges,
        itemById: pack.itemById,
      );

      expect(cost.inversions, 0);
      expect(cost.display, '本序无逆序');
    });

    test('TC-PLAN-026 体系按逆序数升序，且逆序多的仍在列表里（SPEC-PLAN-013）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.schemes.map((SchemeCandidate c) => c.id),
        <String>['scheme-linear', 'scheme-dec-only', 'scheme-swapped', 'scheme-reversed'],
        reason: '0 处的两套并列 ⇒ 保持包声明顺序；`工程路线` 沉到最后但还在',
      );
      expect(
        set.schemes.length,
        4,
        reason: '排序只重排：输入四套，输出四套',
      );
      expect(set.schemes.last.name, '工程路线');
    });
  });

  group('方法段的排序键：类型覆盖率（SPEC-PLAN-020）', () {
    test('TC-PLAN-027 分母是本集合里出现的类型数，不是恒 4（无 SPEC：`PLAN-020` 只说「`Item.type` 覆盖率」，分母本笔补）', () {
      final LoadedPack pack = _pack();
      final List<Item> onlyDeclarative = <Item>[pack.itemById['i-a']!];
      final TypeCoverage coverage = methodTypeCoverage(
        bundle: _bundle('m-1', '全类型', <ItemType, String>{
          ItemType.declarative: 'method-feynman',
          ItemType.procedural: 'method-deliberate',
          ItemType.skill: 'method-shadowing',
          ItemType.tacit: 'method-project',
        }),
        items: onlyDeclarative,
      );

      expect(coverage.total, 1);
      expect(coverage.coveredCount, 1);
      expect(
        coverage.display,
        '覆盖 1/1 类',
        reason: '写死 4 作分母会得出「1/4」，那分数不反映任何事实',
      );
    });

    test('TC-PLAN-028 覆盖率高者靠前，覆盖少的仍在列表里（SPEC-PLAN-013）', () {
      final LoadedPack pack = _pack();
      final CandidateSet set = loadCandidates(
        pack,
        userMethodBundles: <MethodBundle>[
          _bundle('m-thin', '只会陈述项', <ItemType, String>{
            ItemType.declarative: 'method-feynman',
          }),
        ],
      );

      final List<String> order = <String>[
        for (final MethodCandidate c in set.methods) c.id,
      ];
      expect(order.first.startsWith('method-bundle-'), isTrue);
      expect(order.last, 'm-thin');
      expect(
        set.methods.length,
        4,
        reason: '覆盖 1/4 也算候选 —— 用户可能只想要那一类的走法',
      );
    });

    test('TC-PLAN-029 未覆盖的类型不计入分子，但计入分母（SPEC-PLAN-020）', () {
      final LoadedPack pack = _pack();
      final List<Item> items = <Item>[
        pack.itemById['i-a']!,
        pack.itemById['i-c']!,
      ];
      final TypeCoverage coverage = methodTypeCoverage(
        bundle: _bundle('m-decl-only', '只会陈述项', <ItemType, String>{
          ItemType.declarative: 'method-feynman',
        }),
        items: items,
      );

      expect(coverage.total, 2);
      expect(coverage.covered, <ItemType>{ItemType.declarative});
      expect(coverage.ratio, 0.5);
    });
  });

  group('推荐的呈现（SPEC-PLAN-021 只做 A 级）', () {
    test('TC-PLAN-030 三段每张卡都给出「为何推荐」，且内容即排序键（SPEC-PLAN-021）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(set.sources.first.reason, '出处等级 L0');
      expect(set.schemes.first.reason, '本序无逆序');
      expect(set.methods.first.reason, '覆盖 4/4 类');
    });

    test('TC-PLAN-031 排序键不看出处：自建 L1 仍排在包内 L2 之前（无 SPEC：`PLAN-013` 只讲不折叠不置灰，出处不参与排序键本笔补）', () {
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[
          SourceRef.fromJson(_excerpt('src-user-l1', '自建 L1', 'L1')),
        ],
      );

      final List<String> order = <String>[
        for (final SourceCandidate c in set.sources) c.id,
      ];
      expect(
        order.indexOf('src-user-l1') < order.indexOf('src-l2'),
        isTrue,
        reason: '若把「用户自建」当成一种降权，它会沉到包内 `L2` 之后 —— 那一页的排序键就变成了两个',
      );
      expect(
        set.sources.firstWhere((SourceCandidate c) => c.id == 'src-user-l1').origin,
        CandidateOrigin.user,
        reason: '排位变了，出处标签不变 —— 排序改的是位置，不是它的来路',
      );
      expect(
        order.where((String id) => id == 'src-l1').length,
        1,
        reason: '同级的 src-l1 与 src-user-l1 都在，且各自只有一条',
      );
    });
  });
}
