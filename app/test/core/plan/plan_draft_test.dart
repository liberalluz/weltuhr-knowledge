/// 草稿组装（`composePlanDraft`）的回归。
///
/// ## 笔 5c 把三条判据改反了
///
/// 旧实现里 `composePlanDraft` 自己从包里读 `spaceId` / `spaceVersion`，还收一个
/// `PlanTarget` 把范围解析结果一并落进草稿。新本体下这两件事都不成立：
///
/// - **版本组合由调用方给**（`PackVersions`）：`PackContent` 只装一个包，骨架版本
///   不在它里面，在这里拼一个单包版本会让多包场景静默少记。
/// - **范围只落 `subtreeRoot`**（`Plan.subtreeRoot`）：`resolved` 是派生值，存下来
///   就会出现「参照集合指向已卸载的节点」。
///
/// 所以下面验的不再是「草稿抄了包什么」，而是「草稿**没抄**什么」—— 少抄一份是
/// 判据，多抄一份是 bug，而两者在只验正例的用例里长得一模一样。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/plan_draft.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';
import 'package:project_knowledge/core/plan/preview.dart';
import 'package:project_knowledge/core/plan/scope.dart';

import '../../support/pack_fixture.dart';

const String _scopeRoot = 'python:lex';

/// 圈内 2 项 + 圈外 1 项，体系把三项都列进去。
///
/// 圈外那一项是关键：它既不该进项数，也不该进分母 —— 少了它，下面两条「圈外项
/// 被挡住」的用例都会变成恒真。笔 5c 之前它是 `FixtureItem(inScope: false)`；
/// 现在是**父挂在子树外**（`inScope` 是派生值，`ADR-0007` 决策 2）。
PackContent _pack() => fixturePack(
  <FixtureNode>[
    const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    const FixtureNode(
      'python:lex',
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    const FixtureNode(
      'python:ctl',
      '控制',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    const FixtureNode('py-a', '变量', parentId: _scopeRoot),
    const FixtureNode('py-b', '函数', parentId: _scopeRoot),
    // 父在同一棵树的另一个分支下 ⇒ 不在 `_scopeRoot` 的子树里。
    const FixtureNode('py-out', '邻项', parentId: 'python:ctl'),
  ],
  schemes: <String, List<String>>{
    'sch-full': <String>['py-a', 'py-b', 'py-out'],
  },
  sources: const <String, String>{'src-official': '官方文档'},
);

const PackVersions _versions = PackVersions(
  skeleton: '1.0.0',
  payloads: <String, String>{'python': '0.1.0'},
);

MethodBundle get _bundle => platformMethodBundles.first;

/// 除 `schemeId` 外全用默认值 —— 六个必填入参里只有一个是被测维度时，逐处重复
/// 那五行会把用例的差异淹掉。
PlanDraft _draft({
  PackContent? pack,
  String spaceId = 'python',
  String subtreeRoot = _scopeRoot,
  String schemeId = 'sch-full',
}) => composePlanDraft(
  pack: pack ?? _pack(),
  spaceId: spaceId,
  subtreeRoot: subtreeRoot,
  primaryAxis: Axis.major,
  packVersions: _versions,
  sourceId: 'src-official',
  schemeId: schemeId,
  bundle: _bundle,
);

void main() {
  group('composePlanDraft', () {
    test('TC-PLAN-050 项数与预览同源（无 SPEC：PLAN-015 的项数就是这次要走的量）', () {
      final PackContent pack = _pack();
      final PlanScope scope = resolvePlanScope(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        schemeId: 'sch-full',
      );
      final PlannerPreview preview = computePlannerPreview(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        schemeId: 'sch-full',
      );

      expect(<String>[for (final node in scope.nodes) node.id], <String>[
        'py-a',
        'py-b',
      ]);
      expect(scope.nodes.length, preview.itemCount);
      // 分母不受体系影响 —— 计划要走的量变了，范围规模没变。
      expect(preview.denominator, 2);
    });

    test('TC-PLAN-051 圈外项不进范围（SPEC-PLAN-015 圈外项不进计划）', () {
      final PackContent pack = _pack();
      final PlanScope scope = resolvePlanScope(
        pack: pack,
        subtreeRoot: _scopeRoot,
        parents: pack.parents,
        schemeId: 'sch-full',
      );

      expect(
        <String>[for (final node in scope.nodes) node.id],
        isNot(contains('py-out')),
        reason: '体系把它列进去了，但它在子树外 —— 圈外是邻项，不能落点',
      );
      expect(scope.nodes, hasLength(2));
    });

    test('TC-PLAN-052 sourcePolicy 只落 primary，不写空的 byType / exceptions（无 SPEC：P-6 口径）', () {
      final PlanDraft draft = _draft();

      expect(draft.sourcePolicy, <String, Object?>{'primary': 'src-official'});
      expect(draft.sourcePolicy.containsKey('byType'), isFalse);
      expect(draft.sourcePolicy.containsKey('exceptions'), isFalse);
    });

    test('TC-PLAN-053 spaceId 只进信封、packVersions 原样进 payload（无 SPEC：entity-fields §8）', () {
      // 笔 5c 之前这里验的是「草稿自己从包里读 spaceId / spaceVersion」。
      // 现在两者都由调用方给，判据随之反过来：**不许**从包里抄第二份。
      final PlanDraft draft = _draft(spaceId: 'python');
      final Map<String, Object?> payload = draft.toPayload();

      expect(draft.spaceId, 'python');
      expect(
        payload.containsKey('spaceId'),
        isFalse,
        reason: '信封上已有 `Event.spaceId`，payload 再写一份就是两处真相',
      );
      expect(draft.packVersions.skeleton, '1.0.0');
      expect(draft.packVersions.payloads, <String, String>{'python': '0.1.0'});
      expect(
        (payload['packVersions']! as Map<String, Object?>)['payloads'],
        <String, String>{'python': '0.1.0'},
        reason: '多包版本组合必须整份落盘 —— 换成单值就会静默少记',
      );
      expect(draft.methodProfileId, _bundle.id);
      expect(draft.subtreeRoot, _scopeRoot, reason: '范围只落根节点，不落解析结果');
    });

    test('TC-PLAN-054 体系 id 不存在时当场抛（无 SPEC：与 resolvePlanScope 同口径）', () {
      // 草稿不重算范围（落盘形态是 `subtreeRoot`），但它同样要拦住坏 id：
      // 否则会落下一份指向不存在体系的计划，而它读回来时看起来只是
      // 「这套体系没覆盖任何东西」—— 一份空计划与一个拿错的 id 分不开。
      expect(
        () => _draft(schemeId: 'sch-不存在'),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('sch-不存在'),
          ),
        ),
      );
    });
  });
}
