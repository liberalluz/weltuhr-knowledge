import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/method_bundle.dart';
import 'package:project_knowledge/core/plan/plan_draft.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';
import 'package:project_knowledge/core/plan/preview.dart';

import '../../support/pack_fixture.dart';

/// 圈内 2 项 + 圈外 1 项，体系把三项都列进去。
///
/// 圈外那一项是关键：它既不该进分母，也不该进 `resolved` —— 少了它，下面两条
/// 「圈外项被挡住」的用例都会变成恒真。
LoadedPack _pack() => fixturePack(
  <FixtureItem>[
    const FixtureItem('py-a', '变量', sourceRefs: <String>['src-official']),
    const FixtureItem('py-b', '函数', sourceRefs: <String>['src-official']),
    const FixtureItem('py-out', '邻项', inScope: false),
  ],
  schemes: <String, List<String>>{
    'sch-full': <String>['py-a', 'py-b', 'py-out'],
  },
);

MethodBundle get _bundle => platformMethodBundles.first;

void main() {
  group('composePlanDraft', () {
    test('TC-PLAN-050 resolved 与预览的项数同源（无 SPEC：PLAN-015 的项数就是这次要走的量）', () {
      final LoadedPack pack = _pack();
      const PlanTarget target = PlanTarget(
        selector: <String, Object?>{},
        resolved: <String>['py-a'],
      );

      final PlanDraft draft = composePlanDraft(
        pack: pack,
        sourceId: 'src-official',
        schemeId: 'sch-full',
        bundle: _bundle,
        target: target,
      );
      final PlannerPreview preview = computePlannerPreview(
        pack: pack,
        schemeId: 'sch-full',
        target: target,
        bundle: _bundle,
      );

      expect(draft.target.resolved, <String>['py-a']);
      expect(draft.target.count, preview.itemCount);
      // 分母不受 target 影响 —— 计划要走的量变了，空间规模没变。
      expect(preview.denominator, 2);
    });

    test('TC-PLAN-051 圈外项不进 resolved（SPEC-PLAN-015 圈外项不进计划）', () {
      final PlanDraft draft = composePlanDraft(
        pack: _pack(),
        sourceId: 'src-official',
        schemeId: 'sch-full',
        bundle: _bundle,
      );

      expect(draft.target.resolved, <String>['py-a', 'py-b']);
      expect(draft.target.resolved, isNot(contains('py-out')));
    });

    test('TC-PLAN-052 sourcePolicy 只落 primary，不写空的 byType / exceptions（无 SPEC：P-6 口径）', () {
      final PlanDraft draft = composePlanDraft(
        pack: _pack(),
        sourceId: 'src-official',
        schemeId: 'sch-full',
        bundle: _bundle,
      );

      expect(draft.sourcePolicy, <String, Object?>{'primary': 'src-official'});
      expect(draft.sourcePolicy.containsKey('byType'), isFalse);
      expect(draft.sourcePolicy.containsKey('exceptions'), isFalse);
    });

    test('TC-PLAN-053 空间与包版本取自包本身，不另传（无 SPEC：entity-fields §8）', () {
      final PlanDraft draft = composePlanDraft(
        pack: _pack(),
        sourceId: 'src-official',
        schemeId: 'sch-full',
        bundle: _bundle,
      );

      expect(draft.spaceId, 'python');
      expect(draft.spaceVersion, '0.1.0');
      expect(draft.methodProfileId, _bundle.id);
    });

    test('TC-PLAN-054 传了 target 就沿用它的 selector（无 SPEC：selector 结构归 PLAN-016）', () {
      final PlanDraft draft = composePlanDraft(
        pack: _pack(),
        sourceId: 'src-official',
        schemeId: 'sch-full',
        bundle: _bundle,
        target: const PlanTarget(
          selector: <String, Object?>{'rootItemId': 'py-a'},
          resolved: <String>['py-a'],
        ),
      );

      expect(draft.target.selector, <String, Object?>{'rootItemId': 'py-a'});
      expect(draft.target.resolved, <String>['py-a'], reason: 'resolved 按当前包重算，不抄旧值');
    });
  });
}
