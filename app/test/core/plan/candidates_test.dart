import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/applies_to.dart';
import 'package:project_knowledge/core/plan/candidates.dart';
import 'package:project_knowledge/core/plan/method_bundle.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';

/// 四类各一项：让「按 `Item.type` 派生」有四种对象可指。
///
/// `sourceRefs` 刻意做成**不全**：`i-skill` / `i-tacit` 不引用任何源 ——
/// 「覆盖 > 0 才进候选」这条如果写成「全在」，就测不出筛掉的那一半。
///
/// 三条源里有一条 `spaceId = java`：客户端不该显示别的空间的材料，而 α 包
/// 单空间，造不出这种形状。
LoadedPack _pack() {
  final List<Map<String, Object?>> items = <Map<String, Object?>>[
    _item('i-dec', 'declarative', <String>['src-a']),
    _item('i-proc', 'procedural', <String>['src-b']),
    _item('i-skill', 'skill', <String>[]),
    _item('i-tacit', 'tacit', <String>[]),
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
    'edges': <Map<String, Object?>>[],
    'schemes': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'scheme-all',
        'name': '全量序',
        'nodes': <String>['i-dec', 'i-proc', 'i-skill', 'i-tacit'],
        'authorityLevel': 'L1',
      },
      <String, Object?>{
        'id': 'scheme-dec-only',
        'name': '只含陈述项',
        'nodes': <String>['i-dec'],
        'authorityLevel': 'L2',
      },
    ],
    'questions': <Map<String, Object?>>[],
    'excerpts': <Map<String, Object?>>[
      _excerpt('src-a', 'A 材料', 'L0', 'python'),
      _excerpt('src-b', 'B 材料', 'L1', 'python'),
      _excerpt('src-java', '别的空间的材料', 'L2', 'java'),
    ],
  };

  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

Map<String, Object?> _item(String id, String type, List<String> sourceRefs) =>
    <String, Object?>{
      'id': id,
      'title': id,
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

Map<String, Object?> _excerpt(
  String id,
  String name,
  String level,
  String spaceId,
) => <String, Object?>{
  'id': id,
  'name': name,
  'authorityLevel': level,
  'version': '1.0',
  'segments': <Map<String, Object?>>[
    <String, Object?>{'text': '摘录正文', 'locator': '§1', 'license': 'PSF-2.0'},
  ],
  'appliesTo': <String, Object?>{'spaceId': spaceId},
};

SourceRef _userSource(String id, String name) =>
    SourceRef.fromJson(_excerpt(id, name, 'L4', 'python'));

void main() {
  group('三段候选装载', () {
    test('不给体系与源时，源候选是空间内全部、覆盖按全空间项数算（SPEC-PLAN-006）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.sources.map((SourceCandidate c) => c.id),
        <String>['src-a', 'src-b'],
      );
      for (final SourceCandidate candidate in set.sources) {
        expect(candidate.coverage.total, 4);
        expect(candidate.coverage.covered, 1);
      }
      expect(set.schemes.map((SchemeCandidate c) => c.id), <String>[
        'scheme-all',
        'scheme-dec-only',
      ]);
      expect(
        set.schemes.map((SchemeCandidate c) => c.coverage),
        <CandidateCoverage?>[null, null],
      );
    });

    test('给出体系即按覆盖收窄源，覆盖为 0 的不进候选（SPEC-PLAN-014）', () {
      final CandidateSet set = loadCandidates(_pack(), schemeId: 'scheme-dec-only');

      expect(set.sources.map((SourceCandidate c) => c.id), <String>['src-a']);
      expect(set.sources.single.coverage.covered, 1);
      expect(set.sources.single.coverage.total, 1);
    });

    test('给出源即按覆盖收窄体系，两张表都进来源时只剩交集（SPEC-PLAN-014）', () {
      final CandidateSet set = loadCandidates(_pack(), sourceId: 'src-b');

      expect(set.schemes.map((SchemeCandidate c) => c.id), <String>['scheme-all']);
      expect(set.schemes.single.coverage!.covered, 1);
      expect(set.schemes.single.coverage!.total, 4);
    });

    test('两段同时给出且互相无覆盖时，已选值从候选里消失（SPEC-PLAN-014）', () {
      // `scheme-dec-only` 只有 i-dec（引用 src-a），而 src-b 只被 i-proc 引用
      // ⇒ 这一对互不覆盖。装载不会替调用方清空选择，但两侧列表都不再含它，
      // 这就是 `P-4` 要显式标「与当前源无交集，需重选」的可观测形态。
      final CandidateSet both = loadCandidates(
        _pack(),
        schemeId: 'scheme-dec-only',
        sourceId: 'src-b',
      );

      expect(both.sources.map((SourceCandidate c) => c.id), <String>['src-a']);
      expect(both.schemes.map((SchemeCandidate c) => c.id), <String>['scheme-all']);
    });

    test('同 id 三源并存时 user 覆盖 pack 的**整条**记录（SPEC-PLAN-006）', () {
      // `P-3` 起顺序由排序键决定（`SPEC-PLAN-020`），不再是「首次出现的位置」——
      // 这条用例因此改成按 id 取，不再依赖列表位置。附带立一条真断言：覆盖的是
      // 整条记录，自建版写的等级也一起生效，不是只换了个名字。
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[_userSource('src-a', '自建版 A')],
      );

      final SourceCandidate merged = set.sources
          .firstWhere((SourceCandidate c) => c.id == 'src-a');
      expect(merged.name, '自建版 A');
      expect(merged.origin, CandidateOrigin.user);
      expect(
        merged.authorityLevel,
        'L4',
        reason: '自建版声明的 `L4` 生效 ⇒ 它从第一掉到最后，而 `src-b` 的 `L1` 顶上来',
      );
      expect(
        set.sources.where((SourceCandidate c) => c.id == 'src-a').length,
        1,
      );
      expect(set.sources.first.id, 'src-b');
    });

    test('别的空间的源不进候选（SPEC-PLAN-006）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.sources.map((SourceCandidate c) => c.id),
        isNot(contains('src-java')),
      );
    });

    test('不存在的体系 id 抛错，不返回空列表（无 SPEC：`PLAN` 未定此契约，静默空表会被读成「零覆盖」）', () {
      expect(
        () => loadCandidates(_pack(), schemeId: 'scheme-nope'),
        throwsArgumentError,
      );
    });

    test('方法候选只有三套平台组合，出处均为 platform（SPEC-PLAN-006）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.methods.map((MethodCandidate c) => c.id),
        <String>[
          'method-bundle-understand',
          'method-bundle-memory',
          'method-bundle-build',
        ],
      );
      for (final MethodCandidate candidate in set.methods) {
        expect(candidate.origin, CandidateOrigin.platform);
      }
    });

    test('三段的候选都实现同一个读法，卡片才能统一（SPEC-PLAN-008）', () {
      final CandidateSet set = loadCandidates(_pack());

      for (final PlanSegment segment in PlanSegment.values) {
        final List<PlanCandidate> candidates = set.of(segment);
        expect(candidates, isNotEmpty);
        for (final PlanCandidate candidate in candidates) {
          expect(candidate.id, isNotEmpty);
          expect(candidate.name, isNotEmpty);
        }
      }
    });
  });

  group('平台内置的方法分支与组合', () {
    test('每套组合的每个类型分支都在分支册内，且该分支的 appliesTo 覆盖该类型（SPEC-PLAN-010）', () {
      final LoadedPack pack = _pack();
      final Map<String, MethodProfile> index = platformMethodProfileIndex();

      for (final MethodBundle bundle in platformMethodBundles) {
        expect(
          bundle.byType.length,
          ItemType.values.length,
          reason: '组合 `${bundle.id}` 缺类型 —— 缺的那类会落到「无方法可用」',
        );
        bundle.byType.forEach((ItemType type, String profileId) {
          final MethodProfile? profile = index[profileId];
          expect(profile, isNotNull, reason: '组合 `${bundle.id}` 指向了不存在的方法 `$profileId`');
          final Item? item = _firstItemOfType(pack, type);
          expect(item, isNotNull);
          expect(
            appliesToItem(profile!.appliesTo, space: pack.space, item: item!),
            isTrue,
            reason: '方法 `$profileId` 的 appliesTo 声明不覆盖 `$type`',
          );
        });
      }
    });

    test('五份分支都至少有一个 review 步骤（SPEC-STEP-027）', () {
      for (final MethodProfile profile in platformMethodProfiles) {
        expect(
          profile.hasReviewStep,
          isTrue,
          reason: '方法 `${profile.id}` 全是 first 步骤 —— 静默绕过了遗忘曲线',
        );
      }
    });

    test('理解优先的分支映射就是 PLAN-010 举的那三例（SPEC-PLAN-010）', () {
      final MethodBundle understand = platformMethodBundles.firstWhere(
        (MethodBundle b) => b.id == 'method-bundle-understand',
      );

      expect(understand.profileIdFor(ItemType.declarative), 'method-feynman');
      expect(understand.profileIdFor(ItemType.procedural), 'method-deliberate');
      expect(understand.profileIdFor(ItemType.skill), 'method-shadowing');
    });
  });

  group('appliesTo 匹配', () {
    test('未给的键不构成限制，给了的键逐项相符才通过（SPEC-PLAN-020）', () {
      final LoadedPack pack = _pack();
      final Item declarative = pack.itemOf('i-dec')!;
      final Item procedural = pack.itemOf('i-proc')!;

      expect(appliesToItem(<String, Object?>{}, space: pack.space, item: declarative), isTrue);
      expect(
        appliesToItem(
          <String, Object?>{'type': 'declarative'},
          space: pack.space,
          item: declarative,
        ),
        isTrue,
      );
      expect(
        appliesToItem(
          <String, Object?>{'type': 'declarative'},
          space: pack.space,
          item: procedural,
        ),
        isFalse,
      );
    });

    test('数组取任一命中，单值需相符（SPEC-PLAN-020）', () {
      final LoadedPack pack = _pack();

      expect(
        appliesToItem(
          <String, Object?>{
            'type': <String>['declarative', 'procedural'],
          },
          space: pack.space,
          item: pack.itemOf('i-proc')!,
        ),
        isTrue,
      );
    });

    test('六轴键已不再被接受：传 sixAxis 直接抛，不静默忽略（SPEC-PLAN-020 修订，笔 5b）', () {
      // 旧实现把 `sixAxis` 当**软约束**（项未标该轴则跳过）。`ADR-0005` 把六轴降为
      // 「三条容器轴 + 四类标签」之后，项身上不再有「每轴单值」，那个软约束恒真 ——
      // 留着它等于留一个永远返回 `true` 的分支，而读者会以为约束还在生效。
      //
      // 所以它现在落在「未认的键」那条判据上：**抛错，不静默放过**。这条用例验的
      // 正是「移除真的生效了」—— 若哪天有人把键悄悄加回来，它会红。
      final LoadedPack pack = _pack();
      expect(
        () => appliesToItem(
          <String, Object?>{
            'sixAxis': <String, Object?>{'stack': 'Python'},
          },
          space: pack.space,
          item: pack.itemOf('i-dec')!,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('别的空间直接不适用（SPEC-PLAN-006）', () {
      final LoadedPack pack = _pack();

      expect(
        appliesToItem(
          <String, Object?>{'spaceId': 'java'},
          space: pack.space,
          item: pack.itemOf('i-dec')!,
        ),
        isFalse,
      );
    });

    test('未认的键报错，不静默忽略（无 SPEC：`entity-fields` 未列可用键，本笔补在附注里）', () {
      final LoadedPack pack = _pack();

      expect(
        () => appliesToItem(
          <String, Object?>{'relevance': 'high'},
          space: pack.space,
          item: pack.itemOf('i-dec')!,
        ),
        throwsFormatException,
      );
    });
  });
}

Item? _firstItemOfType(LoadedPack pack, ItemType type) {
  for (final Item item in pack.items) {
    if (item.type == type) {
      return item;
    }
  }
  return null;
}
