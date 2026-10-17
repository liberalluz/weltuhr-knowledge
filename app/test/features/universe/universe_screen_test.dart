import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/tree.dart';
import 'package:project_knowledge/core/view/zoom.dart';
import 'package:project_knowledge/features/detail/detail_panel.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';
import 'package:project_knowledge/features/universe/tree_view.dart';
import 'package:project_knowledge/features/universe/universe_screen.dart';

import '../../support/alpha_pack.dart';

Future<void> _pump(WidgetTester tester) async {
  // 场景缓慢自转 ⇒ `repeat()` 永不停，`pumpAndSettle` 永远等不到静止，
  // 只能用定长 pump 推进若干帧。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  // 再推过 `C-22` 交叉淡入的上界：`AnimatedSwitcher` 在过渡期间**同时持有**
  // 新旧两个 child，不推完就去断言「树还在不在」，问的其实是「淡出进行到哪了」。
  await tester.pump(Duration(milliseconds: viewTransitionMaxMs));
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  LoadedPack? pack,
  ViewMode mode = ViewMode.universe,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UniverseScreen(
        scene: buildSyntheticScene(),
        pack: pack,
        initialMode: mode,
      ),
    ),
  );
  await _pump(tester);
}

void main() {
  group('宇宙视图的 HUD 七区块（SPEC-VIEW-018）', () {
    testWidgets('默认 Z1：①③⑤⑥⑦ 在，② 与 ④ 不在（SPEC-VIEW-018）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.byKey(hudBreadcrumbKey), findsOneWidget);
      expect(find.byKey(hudScopeSettingsKey), findsOneWidget);
      expect(find.byKey(hudFocusStarKey), findsOneWidget);
      expect(find.byKey(hudAxisCompassKey), findsOneWidget);
      expect(find.byKey(hudZoomScaleKey), findsOneWidget);

      expect(
        find.byKey(hudFilterChipsKey),
        findsNothing,
        reason: '② 是状态栏，激活才出现（VIEW-019）',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: '④ 详情只在 Z4 出现（VIEW-013）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('切到 Z4 ⇒ ④ 出现、面包屑含 Z4（SPEC-VIEW-018）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('Z4 单星'));
      await _pump(tester);

      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(find.text('宇宙 › Z4 单星'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('五档刻度全在，且当前档可反复切换不崩（SPEC-VIEW-001）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      for (final ZoomLevel level in ZoomLevel.values) {
        expect(find.text('${level.code} ${level.label}'), findsOneWidget);
      }
      for (final ZoomLevel level in ZoomLevel.values.reversed) {
        await tester.tap(find.text('${level.code} ${level.label}'));
        await _pump(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('宇宙 ⇄ 树的切换（SPEC-VIEW-009 / 010 / 011 / 012）', () {
    testWidgets('交叉淡入时长落在 C-22 区间内，而非随手取一个数（C-22）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(
        switcher.duration.inMilliseconds,
        inInclusiveRange(viewTransitionMinMs, viewTransitionMaxMs),
      );
      expect(
        switcher.transitionBuilder,
        isNotNull,
        reason: '默认就是 FadeTransition —— 不做形态过渡（VIEW-010）',
      );
    });

    testWidgets('切到树 ⇒ 树视图出现，罗盘 ⑥ 与焦点星 ⑤ 不渲染（SPEC-VIEW-011）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, pack: loadAlphaPack());

      await tester.tap(find.text('树'));
      await _pump(tester);

      expect(find.byKey(treeViewKey), findsOneWidget);
      expect(find.text('树 › 全空间'), findsOneWidget);
      expect(
        find.byKey(hudAxisCompassKey),
        findsNothing,
        reason: '二维没有方位，罗盘留着就是假控件',
      );
      expect(find.byKey(hudFocusStarKey), findsNothing, reason: '树里选中行就是焦点');
      expect(tester.takeException(), isNull);
    });

    testWidgets('树里详情常驻右栏，不必推到 Z4（SPEC-VIEW-012）', (WidgetTester tester) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, mode: ViewMode.tree);

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '树干上点行就等于聚焦，沿用「Z4 才滑出」会让点一次没反应',
      );
      expect(find.byKey(detailPanelKey), findsOneWidget);
      expect(find.text('未选中知识项'), findsOneWidget, reason: '还没选行 ⇒ 空态，但面板在位');
    });

    testWidgets('树里选行 ⇒ 详情填上该行，再切回宇宙按 φ 定档（SPEC-VIEW-009）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, mode: ViewMode.tree);

      final Map<String, int> levels = phiLevelsOf(pack);
      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: pack.space.domainIds.toSet(),
        expandToPhi: initialExpandPhi(maxPhiOf(pack)),
      );
      // 选一个「有后继」的项：有子树 ⇒ 定档走 φ，不落 Z4。
      final TreeRow row = rows.firstWhere(
        (TreeRow r) =>
            r.kind == TreeRowKind.item &&
            pack.edges.any((Edge e) => e.from == r.id),
      );

      await tester.tap(find.byKey(treeRowKey(row)));
      await _pump(tester);
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text(row.label),
        ),
        findsWidgets,
        reason: '点行后详情页头应是这一项的标题',
      );

      await tester.tap(find.text('宇宙'));
      await _pump(tester);

      final ZoomLevel expected = zoomForPhi(levels[row.id]!, hasChildren: true);
      expect(
        find.text('宇宙 › ${expected.code} ${expected.label}'),
        findsOneWidget,
      );
      expect(find.byKey(treeViewKey), findsNothing, reason: '回宇宙后树不该还留着');
      expect(tester.takeException(), isNull);
    });

    testWidgets('树里点刻度 ⇒ 回宇宙并定到该档（SPEC-VIEW-001）', (WidgetTester tester) async {
      await _pumpScreen(tester, pack: loadAlphaPack(), mode: ViewMode.tree);

      await tester.tap(find.text('Z2 星云'));
      await _pump(tester);

      expect(find.text('宇宙 › Z2 星云'), findsOneWidget);
      expect(find.byKey(treeViewKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有包时树照样能进去，报「没有可展开的树」而不是崩（SPEC-FND-014）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('树'));
      await _pump(tester);

      expect(find.byKey(treeEmptyKey), findsOneWidget);
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
