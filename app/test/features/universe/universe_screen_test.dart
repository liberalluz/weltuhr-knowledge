import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/filter.dart';
import 'package:project_knowledge/core/view/tree.dart';
import 'package:project_knowledge/core/view/zoom.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/features/detail/detail_panel.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';
import 'package:project_knowledge/features/universe/filter_chips.dart';
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

  group('快速定位与筛选（SPEC-VIEW-024 / 026 / 027 / 028）', () {
    Future<void> openLocate(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pump(tester);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(locateFieldKey), text);
      await tester.pump();
    }

    testWidgets('Ctrl+K 打开定位浮层，Esc 关掉（SPEC-VIEW-026）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, pack: loadAlphaPack());
      expect(find.byKey(locateOverlayKey), findsNothing, reason: '不常驻');

      await openLocate(tester);
      expect(find.byKey(locateOverlayKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pump(tester);
      expect(find.byKey(locateOverlayKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('轴值命中只写筛选：② 出现、视距不动（SPEC-VIEW-028）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      await openLocate(tester);
      await type(tester, '计算机科学');

      final LocateHit hit = Locator(pack).locate('计算机科学').hits.first;
      expect(hit.kind, LocateKind.axis, reason: '前提：α 包里这是轴值');

      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);

      expect(find.byKey(hudFilterChipsKey), findsOneWidget);
      expect(find.byKey(locateOverlayKey), findsNothing, reason: '选完即关');
      expect(
        find.text('宇宙 › Z1 星系'),
        findsOneWidget,
        reason: '筛选是收窄视野，不换根（VIEW-028）',
      );
      expect(
        find.byKey(
          filterChipKey(AxisFilterChip(axisKey: 'subject', value: '计算机科学')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('删掉唯一的 chip ⇒ ② 整块消失（SPEC-VIEW-019）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      await openLocate(tester);
      await type(tester, '计算机科学');
      final LocateHit hit = Locator(pack).locate('计算机科学').hits.first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);
      expect(find.byKey(hudFilterChipsKey), findsOneWidget);

      await tester.tap(find.text('×'));
      await _pump(tester);
      expect(
        find.byKey(hudFilterChipsKey),
        findsNothing,
        reason: '筛空了就没有 ② —— 「激活才出现」是双向的',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('落点命中 ⇒ 跳到该项，详情页头是它的标题（SPEC-VIEW-027）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      await openLocate(tester);
      await type(tester, '装饰器');

      // 唯一精确命中 ⇒ 回车即跳（`VIEW-027`：不必先在列表里再点一次）。
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pump(tester);

      final LocateHit hit = Locator(pack).locate('装饰器').hits.first;
      expect(find.byKey(locateOverlayKey), findsNothing);
      expect(
        find.text('宇宙 › Z4 单星'),
        findsOneWidget,
        reason: '搜索的落点是这一项本身，不是它所在的星云（VIEW-027）',
      );
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text(hit.label),
        ),
        findsWidgets,
        reason: '落点之后详情必须指向这一项',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('筛选后树里只剩匹配的项（SPEC-VIEW-021）', (WidgetTester tester) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, mode: ViewMode.tree);
      await openLocate(tester);
      await type(tester, '计算机科学');
      final LocateHit hit = Locator(pack).locate('计算机科学').hits.first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);

      // `计算机科学` 是全空间共有的取值 ⇒ 一项都没筛掉，标题里的项数不变。
      expect(find.textContaining('树 · ${pack.items.length} 项'), findsOneWidget);

      // 换一个真会筛掉东西的取值：某个 ability。
      final String ability = pack.items
          .firstWhere((Item item) => item.sixAxis['ability'] != null)
          .sixAxis['ability']!;
      final int kept = pack.items
          .where((Item item) => item.sixAxis['ability'] == ability)
          .length;
      await openLocate(tester);
      await type(tester, ability);
      final LocateHit abilityHit = Locator(pack)
          .locate(ability)
          .hits
          .firstWhere((LocateHit h) => h.kind == LocateKind.axis);
      await tester.tap(find.byKey(locateRowKey(abilityHit)));
      await _pump(tester);

      expect(find.textContaining('树 · $kept 项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
