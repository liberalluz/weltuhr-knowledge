/// 自建的体系 / 方法能不能真的进解算与预览（`SPEC-PLAN-007` / `011` / `015`）。
///
/// 这一组盯的是**接线**，不是算法：`loadCandidates` 从 `P-2` 起就收自建档，
/// 而 `resolvePlanScope` / `computePlannerPreview` / `composePlanDraft` 一直只认
/// 包里的东西。不接的话会得到一个特别难查的现象 —— 自建体系建出来了、在候选
/// 列表里选得上，一选就抛「不存在的体系 id」；自建方法建出来了，预览报
/// 「未覆盖 N 项」把确认拦住。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/method_bundle.dart';
import 'package:project_knowledge/core/plan/plan_draft.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/core/plan/preview.dart';
import 'package:project_knowledge/core/plan/scope.dart';
import 'package:project_knowledge/core/plan/user_content.dart';

import '../../support/pack_fixture.dart';

LoadedPack _pack() => fixturePack(
      <FixtureItem>[
        const FixtureItem('i1', '一'),
        const FixtureItem('i2', '二'),
        const FixtureItem('i3', '三', type: 'procedural'),
        const FixtureItem('i4', '四', type: 'procedural'),
      ],
      schemes: <String, List<String>>{
        'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
      },
    );

void main() {
  group('自建体系进解算', () {
    test('TC-PLAN-087 自建体系能被解算，不传就抛（SPEC-PLAN-007）', () {
      final LoadedPack pack = _pack();
      final Scheme user = buildUserScheme(
        id: 'user:sch:倒着学',
        name: '倒着学',
        // 故意乱序：`resolved` 的次序恒按 `pack.items`，**不按 `nodes`**
        // （学习次序住在 `Scheme.nodes`，落点列表不是它）。
        nodes: <String>['i3', 'i1'],
        authorityLevel: 'L2',
      );

      expect(
        () => resolvePlanScope(pack: pack, schemeId: user.id),
        throwsA(isA<ArgumentError>()),
        reason: '不传 userSchemes 时必须抛 —— 静默回落成全量会让人以为它覆盖了全部',
      );
      // 上一行是「调用写法错」，不是「结果错」；下面才是正解。
      expect(
        <String>[
          for (final Item item in resolvePlanScope(
            pack: pack,
            schemeId: user.id,
            userSchemes: <Scheme>[user],
          ).items)
            item.id,
        ],
        <String>['i1', 'i3'],
      );
    });

    test('TC-PLAN-088 自建体系与包内同 id ⇒ 自建优先（无 SPEC：与 mergeByOrigin 同序，属实现一致性）', () {
      final LoadedPack pack = _pack();
      final Scheme override = buildUserScheme(
        id: 'sch-full',
        name: '我改的',
        nodes: <String>['i4'],
        authorityLevel: 'L4',
      );

      final PlanScope scope = resolvePlanScope(
        pack: pack,
        schemeId: 'sch-full',
        userSchemes: <Scheme>[override],
      );
      expect(
        <String>[for (final Item item in scope.items) item.id],
        <String>['i4'],
        reason: '同 id 时自建覆盖包内，与候选合并的 user > pack 同一条优先级',
      );
      expect(scope.denominator, 4, reason: '分母是圈内项数，不因体系变');
    });
  });

  group('自建方法进预览', () {
    test('TC-PLAN-089 自建分支不传进预览 ⇒ 全被判未覆盖，传了就为 0（SPEC-PLAN-011）', () {
      final LoadedPack pack = _pack();
      final ({MethodProfile profile, MethodBundle bundle}) built =
          buildUserMethod(
        const UserMethodDraft(
          id: 'user:method:只陈述',
          name: '只陈述',
          type: ItemType.declarative,
          steps: <MethodStep>[
            MethodStep(operator: ExecutionOperator.read),
            MethodStep(operator: ExecutionOperator.recall, criteria: '能复述'),
          ],
        ),
      );

      final PlannerPreview without = computePlannerPreview(
        pack: pack,
        bundle: built.bundle,
      );
      expect(
        without.uncoveredItems,
        4,
        reason: '分支 id 不在平台档里 ⇒ 四项全都找不到可走的路',
      );

      final PlannerPreview withUser = computePlannerPreview(
        pack: pack,
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

    test('TC-PLAN-090 草稿与预览用同一份自建体系 ⇒ resolved 与项数一致（SPEC-PLAN-015）', () {
      final LoadedPack pack = _pack();
      final Scheme user = buildUserScheme(
        id: 'user:sch:两把刀',
        name: '两把刀',
        nodes: <String>['i4', 'i2'],
        authorityLevel: 'L2',
      );
      final ({MethodProfile profile, MethodBundle bundle}) method =
          buildUserMethod(
        const UserMethodDraft(
          id: 'user:method:通用',
          name: '通用',
          type: ItemType.declarative,
          steps: <MethodStep>[
            MethodStep(operator: ExecutionOperator.recall),
          ],
        ),
      );

      final PlanDraft draft = composePlanDraft(
        pack: pack,
        sourceId: 'src-a',
        schemeId: user.id,
        bundle: method.bundle,
        userSchemes: <Scheme>[user],
      );
      final PlannerPreview preview = computePlannerPreview(
        pack: pack,
        schemeId: user.id,
        bundle: method.bundle,
        userProfiles: <MethodProfile>[method.profile],
        userSchemes: <Scheme>[user],
      );

      expect(
        draft.target.resolved.length,
        preview.itemCount,
        reason: '预览报的项数与事件里存的列表答的是同一个问题，两处各写一遍必然分叉',
      );
      expect(draft.target.resolved, <String>['i2', 'i4']);
      expect(draft.methodProfileId, method.bundle.id);
    });
  });
}
