import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/detail.dart';
import 'package:project_knowledge/core/view/filter.dart';
import 'package:project_knowledge/core/view/tree.dart';
import 'package:project_knowledge/core/view/viewport.dart';
import 'package:project_knowledge/core/view/zoom.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/features/detail/detail_panel.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';
import 'package:project_knowledge/features/universe/filter_chips.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/frame/scene.dart';
import 'package:project_knowledge/features/universe/frame_painter.dart';
import 'package:project_knowledge/features/universe/scene_pick.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';
import 'package:project_knowledge/features/universe/tree_view.dart';
import 'package:project_knowledge/features/universe/universe_screen.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

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
  SceneBundle? scene,
  ViewMode mode = ViewMode.universe,
  List<LoadedPack> others = const <LoadedPack>[],
  ZoomLevel zoom = ZoomLevel.z1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UniverseScreen(
        roots: <SceneResolution>[
          SceneResolution(
            bundle: scene ?? buildSyntheticScene(),
            pack: pack,
          ),
          // 其它空间按各自的包装场景 —— 换根之后画的必须是**那一份**数据。
          for (final LoadedPack other in others)
            SceneResolution(bundle: _alphaScene(other), pack: other),
        ],
        initialZoom: zoom,
        initialMode: mode,
      ),
    ),
  );
  await _pump(tester);
}

/// 真实包 + 由它构出来的场景（id 与 `Item` 对得上，点星之后详情才有内容）。
SceneBundle _alphaScene(LoadedPack pack) {
  final List<SceneNode> nodes = buildSceneNodes(
    pack,
    sectorCount: spikeSectorCount,
  );
  return SceneBundle(
    origin: SceneOrigin.alphaPack,
    nodes: nodes,
    edges: buildEdgeSpans(pack, nodes),
    radialSegments: pack.space.domainIds.length,
    notes: const <String>[],
  );
}

/// 一个「除 α 包以外」的空间，只用来验换根。一项、零边 —— 与 α 包在项数上
/// 一眼能分开（153 vs 1），诊断行就是换根的证据。
LoadedPack _goPack() => fixturePack(
  const <FixtureItem>[FixtureItem('g1', '闭包')],
  spaceId: 'go',
  spaceName: 'Go 语言',
);

/// 打开浮层并输入 [query]，等结果出来。
///
/// 单独抽出来是因为跨空间用例要重复走这条三步（快捷键 → 输入 → pump），
/// 而每处各写一遍会让「是不是漏了 pump」变成看运气。
Future<void> _search(WidgetTester tester, String query) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _pump(tester);
  await tester.enterText(find.byKey(locateFieldKey), query);
  await _pump(tester);
}

/// 在屏幕中部扫出一个「点得到星」（[hit]）或「点不到星」的**窗口坐标**位置。
///
/// 扫描区间避开了四角 HUD：① 与 ③ 在顶部（高约 60），⑥ 在左下，⑦ 在底部，
/// ④ 详情抽屉占右侧 380 —— 点进这些地方等于点控件，验的就不是拾取了。
///
/// [devicePixelRatio] 必须与 widget 读到的一致：`C-33` 的面积封顶按**物理面积**
/// 判，dpr 变了画布尺寸就变，拾取用的坐标系也跟着变。
Offset _findPoint(
  SceneBundle scene,
  Size window, {
  required bool hit,
  required double devicePixelRatio,
}) {
  final ViewportPlan plan = planViewport(
    window.width,
    window.height,
    devicePixelRatio: devicePixelRatio,
  );
  final Size surface = Size(plan.surfaceWidth, plan.surfaceHeight);
  // 只扫窗口中心 800×600 那一块：4K 窗口下全屏扫描要几万次拾取，而拾取
  // 每次都要重算一帧 —— 用例会慢到没人愿意跑，覆盖却没多一分。
  final double left = math.max(40, window.width / 2 - 400);
  final double right = math.min(window.width - 420, window.width / 2 + 400);
  final double top = math.max(140, window.height / 2 - 300);
  final double bottom = math.min(window.height - 160, window.height / 2 + 300);
  for (double y = top; y < bottom; y += 13) {
    for (double x = left; x < right; x += 13) {
      final Offset point = Offset(x, y);
      final String? id = pickSceneNode(
        scene: scene,
        viewport: surface,
        // 测试里 ticker 只推进了 0 ms，`spin.value == 0` ⇒ 拾取用的偏航 = 0。
        yawRadians: 0,
        point: Offset(x / plan.scale, y / plan.scale),
      );
      if ((id != null) == hit) {
        return point;
      }
    }
  }
  fail('扫描区间里找不到「${hit ? "有星" : "没有星"}」的位置');
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

      final LocateHit hit = Locator.single(pack).locate('计算机科学').hits.first;
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
      final LocateHit hit = Locator.single(pack).locate('计算机科学').hits.first;
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

      final LocateHit hit = Locator.single(pack).locate('装饰器').hits.first;
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

    testWidgets('关掉浮层后 ⌘K 还能再开 —— 焦点不随浮层一起消失（SPEC-VIEW-026）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, pack: loadAlphaPack());

      await openLocate(tester);
      expect(find.byKey(locateOverlayKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pump(tester);
      expect(find.byKey(locateOverlayKey), findsNothing);

      // 浮层里的输入框占过主焦点；它被销毁时若不把焦点收回屏幕根，
      // 第二遍 `⌘K` 就没有节点接着冒泡 —— 表现是「快捷键只灵一次」。
      await openLocate(tester);
      expect(
        find.byKey(locateOverlayKey),
        findsOneWidget,
        reason: '快捷键必须能重复触发，否则「用完即走」就成了「用完就没了」',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('邻近候选点了就是落点，与命中同一条路径（SPEC-VIEW-030）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      await openLocate(tester);
      await type(tester, '装饰器参数');
      expect(find.byKey(locateTriageKey), findsOneWidget, reason: '前提：零命中');

      await tester.tap(find.byKey(locateNearRowKey('python/fn-decorator')));
      await _pump(tester);

      expect(find.byKey(locateOverlayKey), findsNothing);
      expect(find.text('宇宙 › Z4 单星'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text('装饰器'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('表单兜底不写筛选：提交后退出搜索，视图没有被筛过（SPEC-VIEW-032）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      // 先选中一项 —— 域上下文来自选中项，没有它就没有 ③（`VIEW-030`）。
      await openLocate(tester);
      await type(tester, '装饰器');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pump(tester);
      expect(find.byKey(hudFilterChipsKey), findsNothing, reason: '前提：定位不写筛选');

      await openLocate(tester);
      await type(tester, '虚拟环境');
      expect(find.text('新增这一项'), findsOneWidget, reason: '有域上下文 ⇒ 类 ③');
      await tester.tap(find.byKey(locateTriageActionKey));
      await _pump(tester);
      expect(find.byKey(locateFormKey), findsOneWidget);

      await tester.tap(find.byKey(locateFormSubmitKey));
      await _pump(tester);
      expect(find.byKey(locateNoticeKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pump(tester);
      expect(
        find.byKey(hudFilterChipsKey),
        findsNothing,
        reason: '填表是一次性查询 —— 退出搜索后视图还是原样（VIEW-032）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('作用域跟着档位走：Z0 是全部空间，Z1 只搜本空间（SPEC-VIEW-031）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      // 另一个空间只用来验作用域，不进宇宙 —— 换根不在本笔。
      final LoadedPack other = fixturePack(
        const <FixtureItem>[FixtureItem('go/fn-closure', '闭包')],
        spaceId: 'go',
        spaceName: 'Go 语言',
      );
      final SceneBundle scene = _alphaScene(pack);

      // `Z1`：窄作用域 ⇒ 结果区顶部给一行「在全部空间中搜索」。
      await _pumpScreen(
        tester,
        pack: pack,
        scene: scene,
        others: <LoadedPack>[other],
      );
      await openLocate(tester);
      await type(tester, '装饰器');
      expect(find.byKey(locateSearchAllKey), findsOneWidget);

      // `Z0`：本来就是跨空间视角 ⇒ 不给那一行（它按下去不会改变任何东西）。
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpScreen(
        tester,
        pack: pack,
        scene: scene,
        others: <LoadedPack>[other],
        zoom: ZoomLevel.z0,
      );
      await openLocate(tester);
      await type(tester, '装饰器');
      expect(find.byKey(locateSearchAllKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('筛选后树里只剩匹配的项（SPEC-VIEW-021）', (WidgetTester tester) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, mode: ViewMode.tree);
      await openLocate(tester);
      await type(tester, '计算机科学');
      final LocateHit hit = Locator.single(pack).locate('计算机科学').hits.first;
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
      final LocateHit abilityHit = Locator.single(pack)
          .locate(ability)
          .hits
          .firstWhere((LocateHit h) => h.kind == LocateKind.axis);
      await tester.tap(find.byKey(locateRowKey(abilityHit)));
      await _pump(tester);

      expect(find.textContaining('树 · $kept 项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('宇宙的两个输入器（SPEC-VIEW-014 点星 / 019 罗盘）', () {
    testWidgets('点中一颗星 ⇒ 选中它并直接进 Z4 详情（SPEC-VIEW-014）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      // 只推 0 ms：`spin.value` 仍是 0，`_findPoint` 与 `_pickAt` 用同一个偏航。
      await tester.pump();

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      final Offset at = _findPoint(
        scene,
        viewport,
        hit: true,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      await tester.tapAt(at);
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: 'VIEW-013：进详情 = 写选中项并推进到 Z4',
      );
      expect(
        find.descendant(
          of: find.byKey(hudBreadcrumbKey),
          matching: find.textContaining('Z4'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点空白不动选中 —— 详情不会毫无预警地消失（SPEC-VIEW-014）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      await tester.pump();

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      final double dpr = tester.view.devicePixelRatio;
      await tester.tapAt(
        _findPoint(scene, viewport, hit: true, devicePixelRatio: dpr),
      );
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);

      await tester.tapAt(
        _findPoint(scene, viewport, hit: false, devicePixelRatio: dpr),
      );
      await tester.pump();
      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '点歪是常态；靠「点准空白」来取消选中不是一条可用路径',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('⑥ 点轴就地展开取值，点取值写进 ②（SPEC-VIEW-019 / 020）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);

      // 收起态：只有六个轴按钮，没有任何取值行。
      expect(find.byKey(compassAxisKey('ability')), findsOneWidget);
      final String value = axisValuesOf(pack, 'ability').first;
      expect(
        find.byKey(compassValueKey('ability', value)),
        findsNothing,
        reason: 'VIEW-020：就地展开，不点轴就不铺开取值',
      );

      await tester.tap(find.byKey(compassAxisKey('ability')));
      await _pump(tester);
      expect(find.byKey(compassValueKey('ability', value)), findsOneWidget);

      await tester.tap(find.byKey(compassValueKey('ability', value)));
      await _pump(tester);

      expect(
        find.byKey(hudFilterChipsKey),
        findsOneWidget,
        reason: 'VIEW-019：⑥ 负责加，② 是从 ⑥ 的写入里长出来的状态栏',
      );
      expect(
        find.byKey(
          filterChipKey(AxisFilterChip(axisKey: 'ability', value: value)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('⑥ 再点同一取值即取消，② 整块消失（SPEC-VIEW-019）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);
      final String value = axisValuesOf(pack, 'ability').first;

      await tester.tap(find.byKey(compassAxisKey('ability')));
      await _pump(tester);
      await tester.tap(find.byKey(compassValueKey('ability', value)));
      await _pump(tester);
      expect(find.byKey(hudFilterChipsKey), findsOneWidget);

      await tester.tap(find.byKey(compassValueKey('ability', value)));
      await _pump(tester);
      expect(
        find.byKey(hudFilterChipsKey),
        findsNothing,
        reason: 'VIEW-019：⑥ 上再点一次取消，与 ② 的 × 等价',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('4K 窗口：画布缩到 C-33 的面积并铺满窗口，照样能点中（C-33）', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      await tester.pump();

      // 画布缩到基准面积（4K 逻辑尺寸 = 4 倍面积 ⇒ 线性缩一半）。
      final Finder canvas = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint && widget.painter is FramePainter,
      );
      final Size surface = tester.getSize(canvas);
      expect(surface.width, closeTo(frameBenchWidth, 1));
      expect(surface.height, closeTo(frameBenchHeight, 1));

      // 铺满：画布盒在窗口里的全局位置是 (0,0)、被放大 2 倍 —— 若外层没给
      // tight 尺寸，`FittedBox` 会「按比例缩到装得下」，画布居中、四周留底。
      final Rect box = tester.getRect(
        find.ancestor(of: canvas, matching: find.byType(SizedBox)).first,
      );
      expect(box.topLeft, Offset.zero);
      expect(box.width, closeTo(3840, 1));
      expect(box.height, closeTo(2160, 1));

      await tester.tapAt(
        _findPoint(
          scene,
          const Size(3840, 2160),
          hit: true,
          devicePixelRatio: 1,
        ),
      );
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有内容包时罗盘说清原因，不给一排按不动的按钮（SPEC-FND-014）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.byKey(hudAxisCompassKey), findsOneWidget);
      expect(find.textContaining('没有内容包'), findsOneWidget);
      expect(
        find.byKey(compassAxisKey('ability')),
        findsNothing,
        reason: '按不动的控件会被读成「功能坏了」',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('导航记忆（SPEC-VIEW-015 / 016）', () {
    testWidgets('点星进详情后按返回：档位回到进之前，详情消失（SPEC-VIEW-015）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(detailBackKey),
        findsNothing,
        reason: '还没进过详情 ⇒ 没有可退的地方，按钮不渲染',
      );

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      await tester.tapAt(
        _findPoint(
          scene,
          viewport,
          hit: true,
          devicePixelRatio: tester.view.devicePixelRatio,
        ),
      );
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(find.byKey(detailBackKey), findsOneWidget);

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'Z1 没有详情（VIEW-013）⇒ 已经退回来了',
      );
      expect(
        find.descendant(
          of: find.byKey(hudBreadcrumbKey),
          matching: find.textContaining('Z1'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(detailBackKey), findsNothing, reason: '退无可退之后按钮再次消失');
      expect(tester.takeException(), isNull);
    });

    testWidgets('详情里点前置项 ⇒ 返回先退这一项，不是一次跳回原档位（SPEC-VIEW-016）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      await tester.pump();

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      await tester.tapAt(
        _findPoint(
          scene,
          viewport,
          hit: true,
          devicePixelRatio: tester.view.devicePixelRatio,
        ),
      );
      await tester.pump();

      final ItemDetail first = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;
      final List<RelationRow> linked = first.relations
          .where((RelationRow each) => each.itemId != null)
          .toList();
      expect(linked, isNotEmpty, reason: 'α 包里点到的这一项总该至少有一条关系行');
      final RelationRow row = linked.first;

      await tester.ensureVisible(find.byKey(detailRelationRowKey(row)));
      await tester.tap(find.byKey(detailRelationRowKey(row)));
      await tester.pump();

      final ItemDetail second = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;
      expect(second.id, row.itemId, reason: '关系行点下去就是换选中项');

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      final ItemDetail back = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;
      expect(back.id, first.id, reason: 'trail 先退一步 —— 退成「回原档位」会把用户走过的那几步一次作废');
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('从搜索落点进详情，返回时词填回去、结果按当下重算（SPEC-VIEW-015）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pump(tester);
      await tester.enterText(find.byKey(locateFieldKey), '装饰器');
      await _pump(tester);

      final LocateHit hit = Locator.single(pack).locate('装饰器').usableHits.first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      expect(
        find.byKey(locateOverlayKey),
        findsOneWidget,
        reason: 'VIEW-015：快照里存 selector ⇒ 返回时把搜索这一场重新打开',
      );
      expect(
        find.text('装饰器'),
        findsWidgets,
        reason: '词填回输入框，结果按当下重算 —— 不是还给用户一份旧列表',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('一直在详情里、从没离开过 ⇒ 不给返回按钮（SPEC-VIEW-015）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen.single(
            scene: scene,
            pack: pack,
            initialZoom: ZoomLevel.z4,
          ),
        ),
      );
      await tester.pump();

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      await tester.tapAt(
        _findPoint(
          scene,
          viewport,
          hit: true,
          devicePixelRatio: tester.view.devicePixelRatio,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '本来就在 Z4，点星只换选中项',
      );
      expect(
        find.byKey(detailBackKey),
        findsNothing,
        reason: '没有「进详情之前」可言 ⇒ 按下去什么也不会变，所以不给',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('跨空间换根（SPEC-VIEW-031 多根）', () {
    testWidgets('跨空间的项命中 ⇒ 换根、进 Z4，详情来自那个空间（SPEC-VIEW-031）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
      );

      await _search(tester, '闭包');
      // `Z1` 只搜本空间 ⇒ 先按那一行放宽（`VIEW-031` 的作用域跟随档位）。
      expect(find.byKey(locateSearchAllKey), findsOneWidget);
      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);

      final LocateHit hit = Locator(<LoadedPack>[pack, go])
          .locate('闭包')
          .usableHits
          .first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);

      final ItemDetail detail = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;
      expect(detail.id, 'g1', reason: '落到了目标空间的那一项');
      expect(
        find.textContaining('· 1 项'),
        findsOneWidget,
        reason: '诊断行写的是新根（go 包 1 项，α 包 153 项）—— 换根真的换了',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('跨空间跳过去后按返回 ⇒ 回到出发的空间与档位（SPEC-VIEW-015）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
      );

      await _search(tester, '闭包');
      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);
      final LocateHit hit = Locator(<LoadedPack>[pack, go])
          .locate('闭包')
          .usableHits
          .first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      // 返回会按 `selector` 重开浮层（`VIEW-015`）—— 先关掉再看底下的视图。
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pump(tester);

      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: '回到了出发时的 Z1，那里没有详情',
      );
      expect(
        find.textContaining('· ${_alphaScene(pack).itemCount} 项'),
        findsOneWidget,
        reason: '快照带着 spaceId ⇒ 回到 python 这个根，不是停在 Go',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('详情里再跨空间跳 ⇒ 返回先回原空间的那一项（SPEC-VIEW-016）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: UniverseScreen(
            roots: <SceneResolution>[
              SceneResolution(bundle: scene, pack: pack),
              SceneResolution(bundle: _alphaScene(go), pack: go),
            ],
          ),
        ),
      );
      await tester.pump();

      // 点星进详情 —— 这是「出发的那一项」，在 python 空间。
      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      await tester.tapAt(
        _findPoint(
          scene,
          viewport,
          hit: true,
          devicePixelRatio: tester.view.devicePixelRatio,
        ),
      );
      await tester.pump();
      final ItemDetail origin = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;

      // 详情里搜索跨空间命中：`Z4` 的作用域是本空间 ⇒ 先放宽。
      await _search(tester, '闭包');
      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);
      final LocateHit hit = Locator(<LoadedPack>[pack, go])
          .locate('闭包')
          .usableHits
          .first;
      await tester.tap(find.byKey(locateRowKey(hit)));
      await _pump(tester);
      expect(
        tester.widget<DetailPanel>(find.byKey(hudDetailDrawerKey)).detail!.id,
        'g1',
      );

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pump(tester);

      final ItemDetail back = tester
          .widget<DetailPanel>(find.byKey(hudDetailDrawerKey))
          .detail!;
      expect(
        back.id,
        origin.id,
        reason: 'trail 记的是「python 空间的那一项」—— 只存裸 id 会落到另一个空间',
      );
      expect(
        find.textContaining('· ${scene.itemCount} 项'),
        findsOneWidget,
        reason: '退一步就把根也退回去了',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('空间命中 ⇒ 换根到它并推到 Z0，选中项清空（SPEC-VIEW-001 / 031）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
        zoom: ZoomLevel.z0,
      );

      // `Z0` 本就是全部空间 ⇒ 不必点放宽那一行。
      await _search(tester, 'Go 语言');
      final LocateHit space = Locator(<LoadedPack>[pack, go])
          .locate('Go 语言')
          .usableHits
          .first;
      expect(space.kind, LocateKind.space, reason: '前提：命中的是空间本身');
      await tester.tap(find.byKey(locateRowKey(space)));
      await _pump(tester);

      expect(
        find.textContaining('· 1 项'),
        findsOneWidget,
        reason: '换根到 Go —— 画的是它那一项',
      );
      expect(
        find.descendant(
          of: find.byKey(hudBreadcrumbKey),
          matching: find.textContaining('Z0'),
        ),
        findsOneWidget,
        reason: '空间是 Z0 那一层',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: '选中项被清空 —— 旧空间的 id 在新空间里通常不存在，留着会开一个空抽屉',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('跨空间的轴值命中 ⇒ 换根并写筛选，档位不动（SPEC-VIEW-028 的边界）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      // Go 包的轴取值与 α 包不重叠 —— 只在本空间筛它必然是空集。
      final LoadedPack go = fixturePack(
        const <FixtureItem>[
          // 轴取值只在本空间有 ⇒ 不换根就筛出空集。
          FixtureItem('g1', '闭包', ability: '语言特性'),
        ],
        spaceId: 'go',
        spaceName: 'Go 语言',
      );
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
      );

      await _search(tester, '语言特性');
      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);
      final LocateHit axis = Locator(<LoadedPack>[pack, go])
          .locate('语言特性')
          .usableHits
          .firstWhere((LocateHit h) => h.kind == LocateKind.axis);
      await tester.tap(find.byKey(locateRowKey(axis)));
      await _pump(tester);

      expect(
        find.byKey(hudFilterChipsKey),
        findsOneWidget,
        reason: '筛选写进去了',
      );
      expect(
        find.textContaining('· 1 项'),
        findsOneWidget,
        reason: '换根到 Go —— 不换根的话这条取值在 α 包里筛出空集',
      );
      expect(
        find.descendant(
          of: find.byKey(hudBreadcrumbKey),
          matching: find.textContaining('Z1'),
        ),
        findsOneWidget,
        reason: '筛选类不改档位（VIEW-028）—— 改的只是根',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('换根后作用域跟着新根：放宽那一行改报「另有 1 个空间」（SPEC-VIEW-031）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
      );

      // 先换到 Go（空间命中，`Z0` 下不必放宽）。
      await _search(tester, 'Go 语言');
      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);
      final LocateHit space = Locator(<LoadedPack>[pack, go])
          .locate('Go 语言')
          .usableHits
          .first;
      await tester.tap(find.byKey(locateRowKey(space)));
      await _pump(tester);

      // 在 Go 里再搜：`Z0` 不限空间，所以直接能看到 α 包的项。
      await _search(tester, '装饰器');
      final LocateHit remote = Locator(<LoadedPack>[pack, go])
          .locate('装饰器')
          .usableHits
          .first;
      expect(
        remote.spaceId,
        'python',
        reason: '命中来自另一个空间 —— 换根之后它成了「别人」',
      );
      expect(
        find.byKey(locateRowKey(remote)),
        findsOneWidget,
        reason: 'Z0 搜全部空间，另一个空间的项照样列出来',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('换根后树里是新根的项（SPEC-VIEW-031 / 021）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _goPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
        zoom: ZoomLevel.z0,
      );

      await _search(tester, 'Go 语言');
      final LocateHit space = Locator(<LoadedPack>[pack, go])
          .locate('Go 语言')
          .usableHits
          .first;
      await tester.tap(find.byKey(locateRowKey(space)));
      await _pump(tester);

      await tester.tap(find.descendant(
        of: find.byKey(hudModeSwitchKey),
        matching: find.text('树'),
      ));
      await _pump(tester);

      expect(
        find.textContaining('树 · 1 项'),
        findsOneWidget,
        reason: '树读的是 `_pack` —— 换根之后它必须跟着换',
      );
      expect(find.text('闭包'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
