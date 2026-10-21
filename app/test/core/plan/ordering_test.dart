import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/scheme.dart';
import 'package:project_knowledge/core/entities/source.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/candidates.dart';
import 'package:project_knowledge/core/plan/ordering.dart';

import '../../support/pack_fixture.dart';

/// 一条最短的 `⪯` 链 `i-a ⪯ i-b ⪯ i-c` + 一个游离项 `i-d`。
///
/// 四套体系刻意做成：**线性扩展**（0 处逆序）· **整段倒过来**（2 处）·
/// **换一对位置**（1 处）· **只含一项**（缺端点的边不算逆序）—— 逆序数若只是
/// 「序列里倒置的项对」而不是「几条前提边被倒置」，这几套的读数会完全不同，
/// 用例才分得开。
PackContent _pack() => fixturePack(
  const <FixtureNode>[
    FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    FixtureNode(
      'python:lex',
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    FixtureNode(
      'i-a',
      'A 边界',
      parentId: 'python:lex',
      type: LearnableType.declarative,
      sourceRefs: <String>['src-textbook'],
    ),
    FixtureNode(
      'i-b',
      'B 归纳',
      parentId: 'python:lex',
      type: LearnableType.procedural,
      sourceRefs: <String>['src-standard'],
    ),
    FixtureNode(
      'i-c',
      'C 装饰器',
      parentId: 'python:lex',
      type: LearnableType.skill,
      sourceRefs: <String>['src-official'],
    ),
    FixtureNode(
      'i-d',
      'D 游离项',
      parentId: 'python:lex',
      type: LearnableType.tacit,
    ),
  ],
  prerequisites: const <(String, String)>[('i-a', 'i-b'), ('i-b', 'i-c')],
  schemes: <String, List<String>>{
    'scheme-linear': <String>['i-a', 'i-b', 'i-c', 'i-d'],
    'scheme-reversed': <String>['i-c', 'i-b', 'i-a'],
    'scheme-swapped': <String>['i-a', 'i-c', 'i-b'],
    'scheme-dec-only': <String>['i-a'],
  },
  sources: const <String, String>{
    'src-official': '官方文档',
    'src-standard': '国家标准',
    'src-textbook': '教材',
    'src-reference': '手册',
    'src-community': '社区帖',
  },
  sourceLevels: const <String, AuthorityLevel>{
    'src-official': AuthorityLevel.official,
    'src-standard': AuthorityLevel.standard,
    'src-textbook': AuthorityLevel.textbook,
    'src-reference': AuthorityLevel.reference,
    'src-community': AuthorityLevel.community,
  },
);

/// 一条**不标等级**的材料源 —— 旧的「未知等级」用例在新本体里由 `null` 表达
/// （`authority_level` 可空，`entity-fields` §11）。
SourceRef _bareSource(String id, String name) => SourceRef.fromJson(
  <String, Object?>{
    'id': id,
    'name': name,
    'kind': 'material',
    'version': '1.0',
    'appliesTo': <String, Object?>{
      'axes': <String>['major'],
      'node_scope': <String>[],
    },
  },
);

/// 一条自建源，等级由调用方给。
SourceRef _userSource(String id, String name, AuthorityLevel level) =>
    SourceRef.fromJson(
      <String, Object?>{
        'id': id,
        'name': name,
        'kind': 'material',
        'authority_level': level.name,
        'version': '1.0',
        'appliesTo': <String, Object?>{
          'axes': <String>['major'],
          'node_scope': <String>[],
        },
      },
    );

MethodBundle _bundle(
  String id,
  String name,
  Map<LearnableType, String> byType,
) => MethodBundle(
  id: id,
  name: name,
  origin: CandidateOrigin.user,
  byType: byType,
);

void main() {
  group('源段的排序键：出处等级（SPEC-PLAN-020）', () {
    test('TC-PLAN-019 官方 → 标准 → 教材 → 手册 → 社区依次靠前，不是字母序（SPEC-PLAN-020）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.sources.map((SourceCandidate c) => c.id),
        <String>[
          'src-official',
          'src-standard',
          'src-textbook',
          'src-reference',
          'src-community',
        ],
      );
      expect(
        authorityLevelOrder,
        <AuthorityLevel>[
          AuthorityLevel.official,
          AuthorityLevel.standard,
          AuthorityLevel.textbook,
          AuthorityLevel.reference,
          AuthorityLevel.community,
        ],
        reason: '旧 `L0`–`L4` 编号已废，语义值本身即排序键',
      );
    });

    test('TC-PLAN-020 无等级排最后：不抛错、也不被删（无 SPEC：五档未覆盖「不标」这一情形）', () {
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[_bareSource('src-bare', '没标等级的材料')],
      );
      final SourceCandidate last = set.sources.last;

      expect(last.id, 'src-bare');
      expect(last.authorityLevel, isNull);
      expect(authorityRank(null), authorityLevelOrder.length);
      expect(authorityRank(AuthorityLevel.official), 0);
      expect(set.sources.length, 6, reason: '排最后 ≠ 被过滤掉');
    });

    test('TC-PLAN-021 同一等级并列时保持包声明顺序（无 SPEC：`PLAN-020` 只给键，并列的回落本笔补）', () {
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[
          _userSource('src-user-1', '自建一', AuthorityLevel.community),
          _userSource('src-user-2', '自建二', AuthorityLevel.community),
        ],
      );

      final List<String> order = <String>[
        for (final SourceCandidate c in set.sources)
          if (c.authorityLevel == AuthorityLevel.community) c.id,
      ];
      expect(order, <String>['src-community', 'src-user-1', 'src-user-2']);
    });
  });

  group('体系段的逆序数（SPEC-PLAN-012）', () {
    test('TC-PLAN-022 线性扩展 ⇒ 0 处逆序，显示「本序无逆序」（SPEC-PLAN-012）', () {
      final PackContent pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-linear'),
        edges: pack.prerequisites,
        nodeById: pack.nodeById,
      );

      expect(cost.inversions, 0);
      expect(cost.isLinearExtension, isTrue);
      expect(cost.firstBlockedStep, isNull);
      expect(cost.display, '本序无逆序');
    });

    test('TC-PLAN-023 整段倒过来 ⇒ 2 处逆序，第 1 步卡住（SPEC-PLAN-012）', () {
      final PackContent pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-reversed'),
        edges: pack.prerequisites,
        nodeById: pack.nodeById,
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
      final PackContent pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-swapped'),
        edges: pack.prerequisites,
        nodeById: pack.nodeById,
      );

      expect(cost.inversions, 1);
      expect(
        cost.firstBlockedStep,
        2,
        reason: '`i-c` 排在位置 1 ⇒ 第 2 步；取最早的那个位置，不是最后一条边',
      );
      expect(cost.firstBlockedItemName, 'C 装饰器');
    });

    test('TC-PLAN-025 一端不在序列里的边不算逆序（无 SPEC：只数两端都在序列里的边）', () {
      final PackContent pack = _pack();
      final SchemeOrderCost cost = schemeOrderCost(
        scheme: pack.schemes.firstWhere((Scheme s) => s.id == 'scheme-dec-only'),
        edges: pack.prerequisites,
        nodeById: pack.nodeById,
      );

      expect(cost.inversions, 0);
      expect(cost.display, '本序无逆序');
    });

    test('TC-PLAN-026 体系按逆序数升序，且逆序多的仍在列表里（SPEC-PLAN-013）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.schemes.map((SchemeCandidate c) => c.id),
        <String>[
          'scheme-linear',
          'scheme-dec-only',
          'scheme-swapped',
          'scheme-reversed',
        ],
        reason: '0 处的两套并列 ⇒ 保持包声明顺序；「工程路线」沉到最后但还在',
      );
      expect(set.schemes.length, 4, reason: '排序只重排：输入四套，输出四套');
      expect(set.schemes.last.id, 'scheme-reversed');
    });
  });

  group('方法段的排序键：类型覆盖率（SPEC-PLAN-020）', () {
    test('TC-PLAN-027 分母是本集合里出现的类型数，不是恒 4（无 SPEC：分母本笔补）', () {
      final PackContent pack = _pack();
      final TypeCoverage coverage = methodTypeCoverage(
        bundle: _bundle('m-1', '全类型', <LearnableType, String>{
          LearnableType.declarative: 'method-feynman',
          LearnableType.procedural: 'method-deliberate',
          LearnableType.skill: 'method-shadowing',
          LearnableType.tacit: 'method-project',
        }),
        nodes: <LearnableNode>[pack.learnableOf('i-a')!],
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
      final CandidateSet set = loadCandidates(
        _pack(),
        userMethodBundles: <MethodBundle>[
          _bundle('m-thin', '只会陈述项', <LearnableType, String>{
            LearnableType.declarative: 'method-feynman',
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
      final PackContent pack = _pack();
      final TypeCoverage coverage = methodTypeCoverage(
        bundle: _bundle('m-decl-only', '只会陈述项', <LearnableType, String>{
          LearnableType.declarative: 'method-feynman',
        }),
        nodes: <LearnableNode>[
          pack.learnableOf('i-a')!,
          pack.learnableOf('i-c')!,
        ],
      );

      expect(coverage.total, 2);
      expect(coverage.covered, <LearnableType>{LearnableType.declarative});
      expect(coverage.ratio, 0.5);
    });
  });

  group('推荐的呈现（SPEC-PLAN-021 只做 A 级）', () {
    test('TC-PLAN-030 三段每张卡都给出「为何推荐」，且内容即排序键（SPEC-PLAN-021）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(set.sources.first.reason, '出处等级 official');
      expect(set.schemes.first.reason, '本序无逆序');
      expect(set.methods.first.reason, '覆盖 4/4 类');
    });

    test('TC-PLAN-031 排序键不看出处：自建 standard 仍排在包内 textbook 之前（无 SPEC：出处不参与排序键本笔补）', () {
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[
          _userSource('src-user-standard', '自建标准', AuthorityLevel.standard),
        ],
      );

      final List<String> order = <String>[
        for (final SourceCandidate c in set.sources) c.id,
      ];
      expect(
        order.indexOf('src-user-standard') < order.indexOf('src-textbook'),
        isTrue,
        reason: '若把「用户自建」当成一种降权，它会沉到包内 textbook 之后 —— 那一页的排序键就变成了两个',
      );
      expect(
        set.sources
            .firstWhere((SourceCandidate c) => c.id == 'src-user-standard')
            .origin,
        CandidateOrigin.user,
        reason: '排位变了，出处标签不变 —— 排序改的是位置，不是它的来路',
      );
      expect(
        order.where((String id) => id == 'src-standard').length,
        1,
        reason: '同级的 src-standard 与 src-user-standard 都在，且各自只有一条',
      );
    });
  });
}
