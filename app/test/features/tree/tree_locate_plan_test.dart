/// 树界面 → 定位 → 按此范围建计划 的接线回归（`SPEC-PLAN-016` 第三入口）。
///
/// 三件事各验一次，正好对上本批的验收：
/// 1. 标题栏上有「定位」，点开就是浮层（入口不再是一段死代码）；
/// 2. 命中集在同一子树下时，底部出现「按此范围建计划」；
/// 3. 命中集跨轴时**按钮不出现** —— 不是「出现但点了没反应」；
/// 4. 点下去真的进 Planner，且范围是命中集的公共根、主轴是那个根所在的轴。
library;

import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/plan_entry.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';
import 'package:project_knowledge/features/planner/planner_screen.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';

import '../../support/pack_fixture.dart';

/// 骨架：一条 major 轴，`sk:sys` 下挂着 量表一 / 量表二。
///
/// [withInterest] 再加一条 interest 轴 + 一个同名系词 —— 用来造「命中集跨轴」。
PackContent _skeleton({bool withInterest = false}) => fixturePack(
  <FixtureNode>[
    const FixtureNode('sk:root', '学科', slot: LevelSlot.star),
    const FixtureNode(
      'sk:sys',
      '系',
      slot: LevelSlot.system,
      parentId: 'sk:root',
    ),
    const FixtureNode('sk:a', '量表一', parentId: 'sk:sys'),
    const FixtureNode('sk:b', '量表二', parentId: 'sk:sys'),
    if (withInterest) ...<FixtureNode>[
      const FixtureNode(
        'sk:root-i',
        '兴趣',
        slot: LevelSlot.star,
        axis: Axis.occupation,
      ),
      const FixtureNode(
        'sk:sys-i',
        '兴趣系',
        slot: LevelSlot.system,
        parentId: 'sk:root-i',
        axis: Axis.occupation,
      ),
      const FixtureNode(
        'sk:d',
        '量表三',
        parentId: 'sk:sys-i',
        axis: Axis.occupation,
      ),
    ],
  ],
  pluginId: skeletonPluginId,
  packName: '骨架',
  kinds: const <String>[],
  attachTo: '',
);

/// 一个载荷包。只用来让「在全部空间中搜索」那一行出现（它是跨包的前提）。
PackContent _payload() => fixturePack(
  const <FixtureNode>[FixtureNode('py:x', '戊', parentId: 'sk:sys')],
  pluginId: 'python',
  packName: 'Python',
);

Future<void> _pump(WidgetTester tester, List<PackContent> contents) async {
  // 树的列与树行在 800×600 下会溢出；这里验的是「有没有这个控件」，
  // 撑高视口让 overflow 的报错不盖住断言。
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: TreeScreen(contents: contents)));
  await tester.pump();
}

Future<void> _openLocate(WidgetTester tester) async {
  await tester.tap(find.byKey(treeLocateKey));
  await tester.pump();
  expect(find.byKey(locateOverlayKey), findsOneWidget);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(locateFieldKey), text);
  await tester.pump();
}

void main() {
  testWidgets('标题栏有「定位」，点开是浮层（SPEC-PLAN-016）', (WidgetTester tester) async {
    await _pump(tester, <PackContent>[_skeleton()]);
    expect(find.byKey(treeLocateKey), findsOneWidget);
    await _openLocate(tester);
  });

  testWidgets('同一子树下的命中 ⇒ 底部出现「按此范围建计划」（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <PackContent>[_skeleton()]);
    await _openLocate(tester);
    await _type(tester, '量表');

    expect(find.byKey(locatePlanHereKey), findsOneWidget);
  });

  testWidgets('跨轴的命中 ⇒ 按钮不出现（SPEC-PLAN-016）', (WidgetTester tester) async {
    // 树的作用域是**当前根**：跨轴那一条先被判成圈外，本来就进不了 CTA。
    // 要让两条轴真正同时出现在命中集里，得先按「在全部空间中搜索」
    // （`SPEC-VIEW-031`）把作用域放宽 —— 那正是这里的场景。
    await _pump(tester, <PackContent>[
      _skeleton(withInterest: true),
      _payload(),
    ]);
    await _openLocate(tester);
    await _type(tester, '量表');

    // 作用域还窄时，跨轴那一条是圈外、不进 CTA —— 按钮在。
    expect(find.byKey(locatePlanHereKey), findsOneWidget);

    // 放宽到全部包后，两条轴同时进入命中集，范围圈不出来。
    await tester.tap(find.byKey(locateSearchAllKey));
    await tester.pump();

    expect(find.byKey(locateResultsKey), findsOneWidget);
    expect(find.byKey(locatePlanHereKey), findsNothing);
  });

  testWidgets('点「按此范围建计划」进 Planner，范围与主轴来自公共根（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <PackContent>[_skeleton()]);
    await _openLocate(tester);
    await _type(tester, '量表');

    await tester.tap(find.byKey(locatePlanHereKey));
    await tester.pumpAndSettle();

    final PlannerScreen screen = tester.widget<PlannerScreen>(
      find.byType(PlannerScreen),
    );
    expect(screen.subtreeRoot, 'sk:sys');
    expect(screen.primaryAxis, Axis.major);
    expect(screen.spaceId, skeletonPluginId);
    expect(screen.packVersions.skeleton, isNotEmpty);
  });
}
