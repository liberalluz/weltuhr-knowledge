import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/source.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/applies_to.dart';
import 'package:project_knowledge/core/plan/candidates.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';

import '../../support/node_fixture.dart';
import '../../support/pack_fixture.dart';

/// 四类各一项：让「按 `LearnableType` 派生」有四种对象可指。
///
/// `sourceRefs` 刻意做成**不全**：`i-skill` / `i-tacit` 不引用任何源 ——
/// 「覆盖 > 0 才进候选」这条如果写成「全在」，就测不出筛掉的那一半。
///
/// 三条源里有一条 `kind = catalog`：它绑 `Node.catalog_refs`，不该混进候选卡
/// （`entity-fields` §11 注记）。旧夹具用「另一个空间的源」造这个形状，
/// 那条判据随 `spaceId` 一起废了 —— 现在同一条规则由 `kind` 表达。
PackContent _pack() => fixturePack(
  const <FixtureNode>[
    FixtureNode(
      'python:lex',
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    FixtureNode(
      'i-dec',
      '陈述项',
      parentId: 'python:lex',
      type: LearnableType.declarative,
      sourceRefs: <String>['src-a'],
    ),
    FixtureNode(
      'i-proc',
      '流程项',
      parentId: 'python:lex',
      type: LearnableType.procedural,
      sourceRefs: <String>['src-b'],
    ),
    FixtureNode(
      'i-skill',
      '技能项',
      parentId: 'python:lex',
      type: LearnableType.skill,
    ),
    FixtureNode(
      'i-tacit',
      '默会项',
      parentId: 'python:lex',
      type: LearnableType.tacit,
    ),
  ],
  schemes: <String, List<String>>{
    'scheme-all': <String>['i-dec', 'i-proc', 'i-skill', 'i-tacit'],
    'scheme-dec-only': <String>['i-dec'],
  },
  sources: const <String, String>{
    'src-a': 'A 材料',
    'src-b': 'B 材料',
    'src-catalog': '研究生目录',
  },
  catalogSources: const <String>{'src-catalog'},
);

/// 自建源：整条记录来自用户，等级取最低一档。
SourceRef _userSource(String id, String name) => SourceRef.fromJson(
  <String, Object?>{
    'id': id,
    'name': name,
    'kind': 'material',
    'authority_level': 'community',
    'version': '1.0',
    'appliesTo': <String, Object?>{
      'axes': <String>['major'],
      'node_scope': <String>[],
    },
  },
);

void main() {
  group('三段候选装载', () {
    test('不给体系与源时，源候选是包内全部（`catalog` 除外），覆盖按全包项数算（SPEC-PLAN-006）', () {
      final CandidateSet set = loadCandidates(_pack());

      expect(
        set.sources.map((SourceCandidate c) => c.id),
        <String>['src-a', 'src-b'],
        reason: '`catalog` 源不进候选 —— 它回答「按下哪份文件」而不是「去哪学」',
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
      // 覆盖的是整条记录，自建版写的等级也一起生效，不是只换了个名字。
      final CandidateSet set = loadCandidates(
        _pack(),
        userSources: <SourceRef>[_userSource('src-a', '自建版 A')],
      );

      final SourceCandidate merged = set.sources.firstWhere(
        (SourceCandidate c) => c.id == 'src-a',
      );
      expect(merged.name, '自建版 A');
      expect(merged.origin, CandidateOrigin.user);
      expect(
        merged.authorityLevel,
        AuthorityLevel.community,
        reason: '自建版声明的等级生效 ⇒ 它从第一掉到最后，而 `src-b` 顶上来',
      );
      expect(
        set.sources.where((SourceCandidate c) => c.id == 'src-a').length,
        1,
      );
      expect(set.sources.first.id, 'src-b');
    });

    test('不存在的体系 id 抛错，不返回空列表（无 SPEC：静默空表会被读成「零覆盖」）', () {
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
      final Map<String, MethodProfile> index = platformMethodProfileIndex();

      for (final MethodBundle bundle in platformMethodBundles) {
        expect(
          bundle.byType.length,
          LearnableType.values.length,
          reason: '组合 `${bundle.id}` 缺类型 —— 缺的那类会落到「无方法可用」',
        );
        bundle.byType.forEach((LearnableType type, String profileId) {
          final MethodProfile? profile = index[profileId];
          expect(
            profile,
            isNotNull,
            reason: '组合 `${bundle.id}` 指向了不存在的方法 `$profileId`',
          );
          expect(
            appliesToNode(
              profile!.appliesTo,
              node: learnableNode(type: type),
            ),
            isTrue,
            reason: '方法 `$profileId` 的 appliesTo 声明不覆盖 `${type.name}`',
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

      expect(understand.profileOf(LearnableType.declarative), 'method-feynman');
      expect(understand.profileOf(LearnableType.procedural), 'method-deliberate');
      expect(understand.profileOf(LearnableType.skill), 'method-shadowing');
    });
  });
}
