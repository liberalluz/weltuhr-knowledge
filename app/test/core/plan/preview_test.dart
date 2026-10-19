/// Planner 右栏预览的回归（`SPEC-PLAN-015`）。
///
/// 三件事要分开验，因为它们的取值来源完全不同：
/// - **项数** 随体系变（选了体系 = 节点数）
/// - **分母** 不随体系变（圈内项数）—— 这条最容易被写成「跟项数一起动」
/// - **时长** 按类型派生后累加 —— 「先乘平均再乘项数」与「逐项派生」在
///   单一类型的夹具上结果**相同**，所以夹具必须混类型，否则这条验不出来
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/method_bundle.dart';
import 'package:project_knowledge/core/plan/platform_candidates.dart';
import 'package:project_knowledge/core/plan/preview.dart';

import '../../support/pack_fixture.dart';

/// 四项：两项陈述、两项程序。混类型是为了让「按类型派生」这件事可观测。
LoadedPack _mixedPack({Map<String, List<String>>? schemes}) {
  return fixturePack(
    <FixtureItem>[
      const FixtureItem('i1', '一', sourceRefs: <String>['src-a']),
      const FixtureItem('i2', '二', sourceRefs: <String>['src-a']),
      const FixtureItem('i3', '三', sourceRefs: <String>['src-b']),
      const FixtureItem('i4', '四', sourceRefs: <String>['src-b']),
    ],
    schemes: schemes ??
        <String, List<String>>{
          'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
          'sch-part': <String>['i1', 'i2'],
        },
    excerpts: <Map<String, Object?>>[
      _source('src-a'),
      _source('src-b'),
    ],
  );
}

Map<String, Object?> _source(String id) => <String, Object?>{
      'id': id,
      'name': id,
      'authorityLevel': 'L1',
      'version': '1.0',
      'segments': <Map<String, Object?>>[
        <String, Object?>{
          'text': '节选',
          'locator': 'p.1',
          'license': 'CC-BY-4.0',
        },
      ],
      'appliesTo': <String, Object?>{},
    };

/// 程序类项要单独造一个包 —— 夹具的 `itemType` 是全包统一值。
LoadedPack _packOfType(String type) => fixturePack(
      <FixtureItem>[
        const FixtureItem('i1', '一', sourceRefs: <String>['src-a']),
        const FixtureItem('i2', '二', sourceRefs: <String>['src-a']),
      ],
      itemType: type,
      excerpts: <Map<String, Object?>>[_source('src-a')],
    );

void main() {
  test('TC-PLAN-032 项数随体系变，分母不变（SPEC-PLAN-015）', () {
    final LoadedPack pack = _mixedPack();

    final PlannerPreview full =
        computePlannerPreview(pack: pack, schemeId: 'sch-full');
    final PlannerPreview part =
        computePlannerPreview(pack: pack, schemeId: 'sch-part');
    final PlannerPreview none = computePlannerPreview(pack: pack);

    expect(full.itemCount, 4);
    expect(part.itemCount, 2);
    expect(none.itemCount, 4, reason: '没选体系 ⇒ 圈内全量');
    expect(
      <int>[full.denominator, part.denominator, none.denominator],
      <int>[4, 4, 4],
      reason: '分母是圈内项数，不随体系覆盖度变化',
    );
  });

  test('TC-PLAN-033 时长逐项按 Item.type 派生后累加（SPEC-PLAN-015）', () {
    // 「理解优先」：陈述 → 费曼（读 3 + 忆 1 + 讲 5 = 9）；程序 → 刻意练习。
    final PlannerPreview declarative = computePlannerPreview(
      pack: _packOfType('declarative'),
      bundle: platformMethodBundles.first,
    );
    final PlannerPreview procedural = computePlannerPreview(
      pack: _packOfType('procedural'),
      bundle: platformMethodBundles.first,
    );

    expect(declarative.minutes, 18, reason: '2 项 × 9 分钟');
    expect(
      procedural.minutes,
      isNot(declarative.minutes),
      reason: '同一套方法对不同类型给不同步骤 —— 这条不成立就说明没按类型派生',
    );
  });

  test('TC-PLAN-034 未选方法时按平台默认组合估，并标出来（SPEC-PLAN-015）', () {
    final PlannerPreview preview = computePlannerPreview(pack: _mixedPack());

    expect(preview.usingDefaultMethod, isTrue);
    expect(preview.minutes, greaterThan(0), reason: '没选方法也要给得出一版估算');
  });

  test('TC-PLAN-035 方法未覆盖的类型计进 uncoveredItems（SPEC-PLAN-010 口径）', () {
    // 只覆盖陈述类的组合：程序类两项必然落空。
    const MethodBundle declarativeOnly = MethodBundle(
      id: 'bundle-declarative-only',
      name: '只覆盖陈述',
      origin: CandidateOrigin.platform,
      byType: <ItemType, String>{ItemType.declarative: 'method-feynman'},
    );

    final PlannerPreview preview = computePlannerPreview(
      pack: fixturePack(
        <FixtureItem>[
          const FixtureItem('i1', '一'),
          const FixtureItem('i2', '二'),
        ],
        itemType: 'procedural',
      ),
      bundle: declarativeOnly,
    );

    expect(preview.itemCount, 2);
    expect(preview.uncoveredItems, 2, reason: '两项都是程序类，这套方法没有分支');
    expect(preview.minutes, 0, reason: '没有可用步骤就不该凭空空出时长');
  });
}
