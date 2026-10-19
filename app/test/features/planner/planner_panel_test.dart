/// Planner 面板骨架的 Widget 回归（`SPEC-PLAN-014` / `015` / `019`）。
///
/// 夹具刻意做成「两条源各覆盖两项、两套体系一全一窄」：
///
/// ```
/// i1 i2 ── src-a        sch-full : i1 i2 i3 i4
/// i3 i4 ── src-b        sch-part : i1 i2
/// ```
///
/// 这样「选源后体系不筛空」「选体系后源会收窄」「两者不相容时需重选」三件
/// 都能在同一个包上验，不必各造一份夹具。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/features/planner/planner_panel.dart';

import '../../support/pack_fixture.dart';

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

LoadedPack _pack() => fixturePack(
      <FixtureItem>[
        const FixtureItem('i1', '一', sourceRefs: <String>['src-a']),
        const FixtureItem('i2', '二', sourceRefs: <String>['src-a']),
        const FixtureItem('i3', '三', sourceRefs: <String>['src-b']),
        const FixtureItem('i4', '四', sourceRefs: <String>['src-b']),
      ],
      schemes: <String, List<String>>{
        'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
        'sch-part': <String>['i1', 'i2'],
      },
      excerpts: <Map<String, Object?>>[
        _source('src-a'),
        _source('src-b'),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  String? source,
  String? scheme,
  PlanTarget? target,
  void Function(PlanDraft draft)? onCreate,
}) async {
  // 四段竖排在 800×600 下面要滚动，滚动会让 `find` 与坐标断言都失真 ——
  // 直接把视口撑高，验的是**顺序**而不是「能不能滚」。
  await tester.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlannerPanel(
          pack: _pack(),
          target: target,
          initialSourceId: source,
          initialSchemeId: scheme,
          onCreate: onCreate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-PLAN-036 四段按「源 → 体系 → 方法 → 确认」竖排（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

    expect(
      y('planner-title-source'),
      lessThan(y('planner-title-scheme')),
      reason: '源在体系之上',
    );
    expect(
      y('planner-title-scheme'),
      lessThan(y('planner-title-method')),
      reason: '体系在方法之上',
    );
    expect(
      y('planner-title-method'),
      lessThan(y('planner-title-confirm')),
      reason: '确认段在最后',
    );
  });

  testWidgets('TC-PLAN-037 先选源不筛空，选体系后源按覆盖收窄（SPEC-PLAN-014 修订）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    // 先选源：体系候选不得清空 —— 单向依赖下这里会剩 0 条。
    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-scheme-sch-full')), findsOneWidget);
    expect(find.byKey(const Key('planner-scheme-sch-part')), findsOneWidget);
    expect(find.byKey(const Key('planner-empty-scheme')), findsNothing);

    // 再选窄体系：源里不该再有覆盖 0 的 src-b。
    await tester.tap(find.byKey(const Key('planner-scheme-sch-part')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-source-src-a')), findsOneWidget);
    expect(
      find.byKey(const Key('planner-source-src-b')),
      findsNothing,
      reason: 'src-b 覆盖 sch-part 的 0/2，必须被筛掉',
    );
  });

  testWidgets('TC-PLAN-038 预填两端互不相容 ⇒ 被筛掉那段标「需重选」且拦住确认（SPEC-PLAN-019）', (
    WidgetTester tester,
  ) async {
    // 重入场景：上次存的是 src-b + sch-part，而 src-b 对 sch-part 覆盖 0。
    await _pump(tester, source: 'src-b', scheme: 'sch-part');

    expect(
      find.byKey(const Key('planner-reselect-source')),
      findsOneWidget,
      reason: '静默保留会造出「界面上选着、实际不存在」的组合',
    );
    expect(
      find.textContaining('需重选'),
      findsWidgets,
    );
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('planner-confirm-button')),
      ).onPressed,
      isNull,
      reason: '需重选时不许建计划',
    );
  });

  testWidgets('TC-PLAN-039 右栏只有三项读数，分母不随体系变（SPEC-PLAN-015）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('preview-items')), findsOneWidget);
    expect(find.byKey(const Key('preview-denominator')), findsOneWidget);
    expect(find.byKey(const Key('preview-minutes')), findsOneWidget);

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    expect(textOf('preview-items'), '项数 4', reason: '未选体系 ⇒ 圈内全量');
    expect(textOf('preview-denominator'), '分母 4');

    await tester.tap(find.byKey(const Key('planner-scheme-sch-part')));
    await tester.pumpAndSettle();

    expect(textOf('preview-items'), '项数 2', reason: '体系只有 2 个节点');
    expect(
      textOf('preview-denominator'),
      '分母 4',
      reason: '分母是圈内项数，不随体系覆盖度变化',
    );
  });

  testWidgets('TC-PLAN-040 三段没选齐时确认按钮禁用并说明原因（SPEC-PLAN-014 ④段）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    final Finder button = find.byKey(const Key('planner-confirm-button'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('三段选齐才能建计划'), findsOneWidget);
  });

  testWidgets('TC-PLAN-041 三段选齐后可建，且确认段列出三个名字（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-method-method-bundle-memory')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('planner-confirm-button')),
      ).onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('planner-blocked')), findsNothing);

    expect(find.textContaining('src-a'), findsWidgets);
    expect(find.textContaining('sch-full'), findsWidgets);
    expect(find.textContaining('记忆优先'), findsWidgets);
  });

  testWidgets('TC-PLAN-046 面板把 target 接进预览：项数收窄、分母不动（SPEC-PLAN-015）', (
    WidgetTester tester,
  ) async {
    // `Z3` 圈定两项 i1 / i3 —— 空间圈内仍 4 项。
    await _pump(
      tester,
      target: const PlanTarget(
        selector: <String, Object?>{'kind': 'items'},
        resolved: <String>['i1', 'i3'],
      ),
    );

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    expect(textOf('preview-items'), '项数 2', reason: '只数 target 圈定的两项');
    expect(
      textOf('preview-denominator'),
      '分母 4',
      reason: '分母是空间规模，target 只收窄「这次走多少」',
    );
  });

  testWidgets('TC-PLAN-061 点「建计划」把草稿交出去，target 透传且 resolved 按当前包重算（SPEC-PLAN-019）', (
    WidgetTester tester,
  ) async {
    PlanDraft? captured;
    await _pump(
      tester,
      target: const PlanTarget(
        // 选择式取**合法**的一种（`PLAN-016` 的四 kind 之一）：`P-6` 时
        // 结构未定、这里曾写 `{'kind': 'items'}`，那是当时编的假 schema。
        selector: <String, Object?>{'kind': 'item', 'itemId': 'i1'},
        // 旧 resolved 里混一个不存在的项：草稿必须按当前包重算，不能照抄。
        resolved: <String>['i1', 'i3', 'ghost'],
      ),
      onCreate: (PlanDraft draft) => captured = draft,
    );

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-method-method-bundle-memory')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull, reason: '按钮可点就必须真的交出去');
    expect(captured!.spaceId, 'python');
    expect(captured!.schemeId, 'sch-full');
    expect(captured!.methodProfileId, 'method-bundle-memory');
    expect(captured!.sourcePolicy, <String, Object?>{'primary': 'src-a'});
    expect(
      captured!.target.selector,
      <String, Object?>{'kind': 'item', 'itemId': 'i1'},
      reason: '选择式原样保留 —— 它记录的是用户当时怎么圈的',
    );
    expect(
      captured!.target.resolved,
      <String>['i1', 'i3'],
      reason: 'ghost 不在包里，必须被重算掉',
    );
  });
}
