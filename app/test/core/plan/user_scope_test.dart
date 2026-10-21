/// 自建的体系 / 方法能不能真的进解算与预览（`SPEC-PLAN-007` / `011` / `015`）。
///
/// 这一组盯的是**接线**，不是算法：`loadCandidates` 从 `P-2` 起就收自建档，
/// 而 `resolvePlanScope` / `computePlannerPreview` / `composePlanDraft` 一直只认
/// 包里的东西。不接的话会得到一个特别难查的现象 —— 自建体系建出来了、在候选
/// 列表里选得上，一选就抛「不存在的体系 id」；自建方法建出来了，预览报
/// 「未覆盖 N 项」把确认拦住。
///
/// ## 笔 5c：三个函数都多收两样
///
/// `subtreeRoot` + `parents`。旧实现里「圈内」是包数据上的一个布尔字段，新本体
/// 改成派生（`ADR-0007` 决策 2），所以每次解算都得把范围根与树索引带进来。
/// 顺带 `scope.items` 变 `scope.nodes`、`draft.target.resolved` 变
/// `resolvePlanScope(...).nodes` —— 后者不再落盘，只作为**同一个算法的读数**
/// 与预览对齐。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/entities/scheme.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/plan_draft.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/core/plan/preview.dart';
import 'package:project_knowledge/core/plan/scope.dart';
import 'package:project_knowledge/core/plan/user_content.dart';

import '../../support/pack_fixture.dart';

const String _scopeRoot = 'python:lex';

/// 四项：两项陈述、两项程序。混类型是为了让「按类型派生」可观测。
PackContent _pack() => fixturePack(
  <FixtureNode>[
    const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    const FixtureNode(
      _scopeRoot,
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    const FixtureNode('i1', '一', parentId: _scopeRoot),
    const FixtureNode('i2', '二', parentId: _scopeRoot),
    const FixtureNode(
      'i3',
      '三',
      parentId: _scopeRoot,
      type: LearnableType.procedural,
    ),
    const FixtureNode(
      'i4',
      '四',
      parentId: _scopeRoot,
      type: LearnableType.procedural,
    ),
  ],
  schemes: <String, List<String>>{
    'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
  },
  sources: const <String, String>{'src-a': 'A 材料'},
);

PlanScope _scope(PackContent pack, {String? schemeId, List<Scheme> user = const <Scheme>[]}) =>
    resolvePlanScope(
      pack: pack,
      subtreeRoot: _scopeRoot,
      parents: pack.parents,
      schemeId: schemeId,
      userSchemes: user,
    );

List<String> _ids(PlanScope scope) => <String>[
  for (final node in scope.nodes) node.id,
];

void main() {
  group('自建体系进解算', () {
    test('TC-PLAN-087 自建体系能被解算，不传就抛（SPEC-PLAN-007）', () {
      final PackContent pack = _pack();
      final Scheme user = buildUserScheme(
        id: 'user:sch:倒着学',
        name: '倒着学',
        // 故意乱序：解算结果的次序恒按 `pack.nodes`，**不按 `nodes`**
        // （学习次序住在 `Scheme.nodes`，落点列表不是它）。
        nodes: <String>['i3', 'i1'],
        authorityLevel: AuthorityLevel.textbook,
      );

      expect(
        () => _scope(pack, schemeId: user.id),
        throwsA(isA<ArgumentError>()),
        reason: '不传 userSchemes 时必须抛 —— 静默回落成全量会让人以为它覆盖了全部',
      );
      // 上一行是「调用写法错」，不是「结果错」；下面才是正解。
      expect(
        _ids(_scope(pack, schemeId: user.id, user: <Scheme>[user])),
        <String>['i1', 'i3'],
      );
    });

    test('TC-PLAN-088 自建体系与包内同 id ⇒ 自建优先（无 SPEC：与 mergeByOrigin 同序，属实现一致性）', () {
      final PackContent pack = _pack();
      final Scheme override = buildUserScheme(
        id: 'sch-full',
        name: '我改的',
        nodes: <String>['i4'],
        authorityLevel: AuthorityLevel.reference,
      );

      final PlanScope scope = _scope(
        pack,
        schemeId: 'sch-full',
        user: <Scheme>[override],
      );
      expect(
        _ids(scope),
        <String>['i4'],
        reason: '同 id 时自建覆盖包内，与候选合并的 user > pack 同一条优先级',
      );
      expect(scope.denominator, 4, reason: '分母是圈内节点数，不因体系变');
    });
  });

  group('自建方法进预览', () {
    test('TC-PLAN-089 自建分支不传进预览 ⇒ 全被判未覆盖，传了就为 0（SPEC-PLAN-011）', () {
      final PackContent pack = _pack();
      final ({MethodProfile profile, MethodBundle bundle}) built =
          buildUserMethod(
            UserMethodDraft(
              id: 'user:method:只陈述',
              name: '只陈述',
              type: LearnableType.declarative,
              steps: const <EntryStep>[
                EntryStep(operator: ExecutionOperator.read, instruction: '读'),
                EntryStep(operator: ExecutionOperator.recall, instruction: '忆'),
              ],
            ),
          );

      final PlannerPreview without = computePlannerPreview(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        bundle: built.bundle,
      );
      expect(
        without.uncoveredItems,
        4,
        reason: '分支 id 不在平台档里 ⇒ 四项全都找不到可走的路',
      );

      final PlannerPreview withUser = computePlannerPreview(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        bundle: built.bundle,
        userProfiles: <MethodProfile>[built.profile],
      );
      expect(
        withUser.uncoveredItems,
        2,
        reason: '只覆盖陈述类 ⇒ 两项陈述有路，两项流程仍无路',
      );
      expect(withUser.usingDefaultMethod, isFalse);
      expect(withUser.itemCount, 4);
    });

    test('TC-PLAN-090 草稿与预览用同一份自建体系 ⇒ 解算结果与项数一致（SPEC-PLAN-015）', () {
      final PackContent pack = _pack();
      final Scheme user = buildUserScheme(
        id: 'user:sch:两把刀',
        name: '两把刀',
        nodes: <String>['i4', 'i2'],
        authorityLevel: AuthorityLevel.textbook,
      );
      final ({MethodProfile profile, MethodBundle bundle}) method =
          buildUserMethod(
            UserMethodDraft(
              id: 'user:method:通用',
              name: '通用',
              type: LearnableType.declarative,
              steps: const <EntryStep>[
                EntryStep(operator: ExecutionOperator.recall, instruction: '忆'),
              ],
            ),
          );

      final PlanDraft draft = composePlanDraft(
        pack: pack,
        spaceId: 'python',
        subtreeRoot: _scopeRoot,
        primaryAxis: Axis.major,
        packVersions: const PackVersions(
          skeleton: '1.0.0',
          payloads: <String, String>{'python': '0.1.0'},
        ),
        sourceId: 'src-a',
        schemeId: user.id,
        bundle: method.bundle,
        userSchemes: <Scheme>[user],
      );
      final PlanScope scope = _scope(
        pack,
        schemeId: user.id,
        user: <Scheme>[user],
      );
      final PlannerPreview preview = computePlannerPreview(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        schemeId: user.id,
        bundle: method.bundle,
        userProfiles: <MethodProfile>[method.profile],
        userSchemes: <Scheme>[user],
      );

      // 草稿不再存解析结果，所以这里比的不是「它抄对了没有」，而是
      // **同一份输入在两个入口上给出同一个读数** —— 两处各写一遍必然分叉。
      expect(
        scope.nodes.length,
        preview.itemCount,
        reason: '预览报的项数与解算出的节点表答的是同一个问题',
      );
      expect(_ids(scope), <String>['i2', 'i4']);
      expect(draft.subtreeRoot, _scopeRoot);
      expect(draft.methodProfileId, method.bundle.id);
    });
  });
}
