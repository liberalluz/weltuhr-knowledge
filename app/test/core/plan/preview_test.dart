/// Planner 右栏预览的回归（`SPEC-PLAN-015`）。
///
/// 三件事要分开验，因为它们的取值来源完全不同：
/// - **项数** 随体系变（选了体系 = 体系节点 ∩ 圈内）
/// - **分母** 不随体系变（圈内可学节点数）—— 这条最容易被写成「跟项数一起动」
/// - **时长** 按类型派生后累加 —— 「先乘平均再乘项数」与「逐项派生」在
///   单一类型的夹具上结果**相同**，所以夹具必须能混类型，否则这条验不出来
///
/// 笔 5c：`PlanTarget` 没有了（`Plan.subtreeRoot` 取代 `spaceId` + `target`），
/// 所以「按 `target` 收窄」那两条用例改成「按子树收窄」—— 后者会同时收窄分母，
/// 这一点本身就是判据，写进 TC-PLAN-045。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';
import 'package:project_knowledge/core/plan/preview.dart';

import '../../support/pack_fixture.dart';

const String _scopeRoot = 'python:lex';

/// 四项：两项陈述、两项程序。混类型是为了让「按类型派生」这件事可观测。
PackContent _mixedPack({Map<String, List<String>>? schemes}) => fixturePack(
  <FixtureNode>[
    const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    const FixtureNode(
      'python:lex',
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
  schemes:
      schemes ??
      <String, List<String>>{
        'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
        'sch-part': <String>['i1', 'i2'],
      },
  sources: const <String, String>{'src-a': 'A 材料', 'src-b': 'B 材料'},
);

/// 同类型的两项 —— 验「按类型派生」时，包里只能有一种类型，否则读不出差异。
PackContent _packOfType(LearnableType type) => fixturePack(<FixtureNode>[
  const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
  const FixtureNode(
    'python:lex',
    '词法',
    slot: LevelSlot.group,
    parentId: 'python:root',
  ),
  FixtureNode('i1', '一', parentId: _scopeRoot, type: type),
  FixtureNode('i2', '二', parentId: _scopeRoot, type: type),
]);

PlannerPreview _preview(
  PackContent pack, {
  String? schemeId,
  MethodBundle? bundle,
  List<MethodProfile>? profiles,
}) => computePlannerPreview(
  pack: pack,
  subtreeRoot: _scopeRoot,
  parents: pack.parents,
  schemeId: schemeId,
  bundle: bundle,
  profiles: profiles ?? platformMethodProfiles,
);

void main() {
  test('TC-PLAN-032 项数随体系变，分母不变（SPEC-PLAN-015）', () {
    final PackContent pack = _mixedPack();

    final PlannerPreview full = _preview(pack, schemeId: 'sch-full');
    final PlannerPreview part = _preview(pack, schemeId: 'sch-part');
    final PlannerPreview none = _preview(pack);

    expect(full.itemCount, 4);
    expect(part.itemCount, 2);
    expect(none.itemCount, 4, reason: '没选体系 ⇒ 圈内全量');
    expect(
      <int>[full.denominator, part.denominator, none.denominator],
      <int>[4, 4, 4],
      reason: '分母是圈内可学节点数，不随体系覆盖度变化',
    );
  });

  test('TC-PLAN-033 时长逐项按 LearnableType 派生后累加（SPEC-PLAN-015）', () {
    // 「理解优先」：陈述 → 费曼；程序 → 刻意练习。两者步骤数与算子都不同。
    final PlannerPreview declarative = _preview(
      _packOfType(LearnableType.declarative),
      bundle: platformMethodBundles.first,
    );
    final PlannerPreview procedural = _preview(
      _packOfType(LearnableType.procedural),
      bundle: platformMethodBundles.first,
    );

    expect(declarative.minutes, 18, reason: '2 项 × 9 分钟（读 3 + 忆 1 + 讲 5）');
    expect(
      procedural.minutes,
      isNot(declarative.minutes),
      reason: '同一套方法对不同类型给不同步骤 —— 这条不成立就说明没按类型派生',
    );
  });

  test('TC-PLAN-034 未选方法时按平台默认组合估，并标出来（SPEC-PLAN-015）', () {
    final PlannerPreview preview = _preview(_mixedPack());

    expect(preview.usingDefaultMethod, isTrue);
    expect(preview.minutes, greaterThan(0), reason: '没选方法也要给得出一版估算');
  });

  test('TC-PLAN-035 方法未覆盖的类型计进 uncoveredItems（SPEC-PLAN-010 口径）', () {
    // 只覆盖陈述类的组合：程序类两项必然落空。
    const MethodBundle declarativeOnly = MethodBundle(
      id: 'bundle-declarative-only',
      name: '只覆盖陈述',
      origin: CandidateOrigin.platform,
      byType: <LearnableType, String>{
        LearnableType.declarative: 'method-feynman',
      },
    );

    final PlannerPreview preview = _preview(
      _packOfType(LearnableType.procedural),
      bundle: declarativeOnly,
    );

    expect(preview.itemCount, 2);
    expect(preview.uncoveredItems, 2, reason: '两项都是程序类，这套方法没有分支');
    expect(preview.minutes, 0, reason: '没有可用步骤就不该凭空空出时长');
  });

  test('TC-PLAN-042 十项四步估出规格写的 140 分钟（SPEC-PLAN-015 验收向量）', () {
    // 规格验收表原文：「10 项 × 4 步（读 3 + 忆 1 + 练 5 + 讲 5）⇒ 预估 140 分钟」。
    // 这一条不验算法结构，只验**规格里那个数**真的算得出来 —— 平台内置的五套
    // 方法没有一套是「读忆练讲」四步，所以必须自造一份 profile。
    const MethodProfile fourStep = MethodProfile(
      id: 'method-four-step',
      name: '读忆练讲',
      steps: <EntryStep>[
        EntryStep(operator: ExecutionOperator.read, instruction: '读'),
        EntryStep(operator: ExecutionOperator.recall, instruction: '忆'),
        EntryStep(operator: ExecutionOperator.practice, instruction: '练'),
        EntryStep(operator: ExecutionOperator.explain, instruction: '讲'),
      ],
      appliesTo: <String, Object?>{},
      origin: CandidateOrigin.platform,
    );
    const MethodBundle bundle = MethodBundle(
      id: 'bundle-four-step',
      name: '读忆练讲',
      origin: CandidateOrigin.platform,
      byType: <LearnableType, String>{
        LearnableType.declarative: 'method-four-step',
      },
    );

    final PackContent pack = fixturePack(<FixtureNode>[
      const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
      const FixtureNode(
        'python:lex',
        '词法',
        slot: LevelSlot.group,
        parentId: 'python:root',
      ),
      for (int i = 1; i <= 10; i++)
        FixtureNode('i$i', '第 $i 项', parentId: _scopeRoot),
    ]);

    final PlannerPreview preview = _preview(
      pack,
      bundle: bundle,
      profiles: <MethodProfile>[fourStep],
    );

    expect(preview.itemCount, 10);
    expect(
      preview.minutes,
      140,
      reason: '（3 + 1 + 5 + 5）× 10 = 140，与 `PLAN-015` 验收表的读数一致',
    );
  });

  test('TC-PLAN-043 圈外项既不计入分母，也不进项数（SPEC-PLAN-015）', () {
    final PackContent pack = fixturePack(<FixtureNode>[
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
      const FixtureNode('i1', '一', parentId: _scopeRoot),
      const FixtureNode('i2', '二', parentId: _scopeRoot),
      // 挂在另一个域下 ⇒ 不在 `_scopeRoot` 的子树里。
      const FixtureNode('out', '圈外邻项', parentId: 'python:ctl'),
    ],
    schemes: <String, List<String>>{
      'sch-all': <String>['i1', 'i2', 'out'],
    });

    final PlannerPreview none = _preview(pack);
    final PlannerPreview withScheme = _preview(pack, schemeId: 'sch-all');

    expect(none.denominator, 2, reason: '分母只数圈内节点');
    expect(none.itemCount, 2);
    expect(
      withScheme.itemCount,
      2,
      reason: '体系节点含圈外项也不进计划 —— 圈外项是邻项，不能落点',
    );
    expect(
      withScheme.denominator,
      2,
      reason: '项数恒 ≤ 分母：不拦圈外项时这里会变成 3 > 2',
    );
  });

  test('TC-PLAN-045 子树既是范围也是分母 —— 收窄它，两个读数一起收（ADR-0007 决策 2）', () {
    // 旧版这里验的是 `PlanTarget` 收窄项数、分母不动。`PlanTarget` 已废：
    // 范围由 `Plan.subtreeRoot` 唯一给定，而分母的定义就是「这个子树下的可学
    // 节点数」—— 收窄子树必然同时收窄分母。两者仍不同源：分母不随**体系**变。
    final PackContent pack = _mixedPack();
    final PlannerPreview deep = computePlannerPreview(
      pack: pack,
      subtreeRoot: 'i1',
      parents: pack.parents,
    );
    final PlannerPreview wide = _preview(pack);

    expect(deep.itemCount, 1, reason: '子树根自己算圈内');
    expect(deep.denominator, 1);
    expect(wide.denominator, 4);
  });
}
