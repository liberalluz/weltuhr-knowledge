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

/// 面包屑的段数（`VIEW-018` 修订 2：段数 = 走到第几层）。
///
/// **末段没有 key** —— 它是纯文字、点了没有去处，所以数到的 key 个数是
/// `段数 - 1`。这条接口本身就是「末段不可点」的证据：末段若哪天也带上 key，
/// 这个 helper 会多算一段，用例立刻红。
int _crumbCount(WidgetTester tester) {
  int n = 0;
  while (find.byKey(hudCrumbKey(n)).evaluate().isNotEmpty) {
    n++;
  }
  return n + 1;
}

/// 面包屑里有没有某段文字。诊断行也在 ① 里，所以必须限定在面包屑的
/// **段**上 —— 用 `Text` 全搜会把「Python · 153 项 · …」也数进来。
bool _crumbHas(WidgetTester tester, String text) => find
    .descendant(of: find.byKey(hudBreadcrumbKey), matching: find.text(text))
    .evaluate()
    .isNotEmpty;

/// 某一档对应的段数（`VIEW-018` 修订 2 的段数表）。
///
/// `Z3` 与 `Z4` **同形**（`VIEW-001`：4 段），区分靠抽屉在不在。
int _crumbsFor(ZoomLevel level) => switch (level) {
  ZoomLevel.z0 => 1,
  ZoomLevel.z1 => 2,
  ZoomLevel.z2 => 3,
  ZoomLevel.z3 || ZoomLevel.z4 => 4,
};

void main() {
  group('宇宙视图的 HUD 七区块（SPEC-VIEW-018）', () {
    testWidgets('默认 Z1：①③⑤⑥ 在，②④⑦ 不在（SPEC-VIEW-018 修订）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.byKey(hudBreadcrumbKey), findsOneWidget);
      expect(find.byKey(hudScopeSettingsKey), findsOneWidget);
      expect(find.byKey(hudFocusStarKey), findsOneWidget);
      expect(find.byKey(hudAxisCompassKey), findsOneWidget);
      expect(
        find.byKey(hudZoomScaleKey),
        findsNothing,
        reason: '⑦ 已作废（VIEW-018 修订 1）—— 那一格留白，不是换成别的东西',
      );

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

    testWidgets('⑦ 作废后底部没有任何档位按钮（SPEC-VIEW-018 修订 1）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      // 五枚按钮没了：`VIEW-001` 的导航层级改由面包屑承担。这里逐档查字面，
      // 而不是只查 `hudZoomScaleKey` —— 前者证明「少了功能」，后者只证明
      // 「少了一块面板」，两个不同的结论。
      for (final ZoomLevel level in ZoomLevel.values) {
        expect(
          find.text('${level.code} ${level.label}'),
          findsNothing,
          reason: '${level.code} 的刻度按钮已随 ⑦ 一起作废',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z0 面包屑只有一段「知识」，不写空间名（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        zoom: ZoomLevel.z0,
      );

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z0));
      expect(
        _crumbHas(tester, '知识'),
        isTrue,
        reason: '第 1 段是位置名，不是模式名（原先写的是「宇宙」）',
      );
      expect(
        _crumbHas(tester, 'Python'),
        isFalse,
        reason: 'Z0 是宇宙层：并列的是全部空间，没有「进去了哪一个」',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z1 面包屑两段：知识 › Python（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z1));
      expect(_crumbHas(tester, '知识'), isTrue);
      expect(
        _crumbHas(tester, 'Python'),
        isTrue,
        reason: '用 space.id 首字母大写，不用 space.name（VIEW-036 的标注口径）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z2 面包屑三段：加上域名（SPEC-VIEW-018 修订 2 / VIEW-028）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      // 域落点是 `Z2` 唯一的正式入口（`_jumpToDomain`）。点星系下钻要等 `V-1b`。
      final String domainId = pack.space.domainIds.first;
      await _search(tester, domainId);
      final LocateHit domain = Locator.single(pack)
          .locate(domainId)
          .hits
          .firstWhere((LocateHit h) => h.kind == LocateKind.domain);
      await tester.tap(find.byKey(locateRowKey(domain)));
      await _pump(tester);

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z2));
      expect(
        _crumbHas(tester, domainId),
        isTrue,
        reason: '包里没有中文域名（只有 domainId），面包屑如实显示 id',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z4 面包屑四段、且有抽屉（SPEC-VIEW-001 / 018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      await _search(tester, '装饰器');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pump(tester);

      // `Z3` 与 `Z4` 同形（4 段）⇒ 段数不能区分它们，抽屉才能。`Z3` 的入口
      // 随 `V-1d`（恒星系下钻）出现，届时在同一张段数表上补一行。
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(
        _crumbHas(tester, '装饰器'),
        isTrue,
        reason: '第 4 段是项标题 —— 末段就是「此刻看的这一项」',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: 'Z4 的判据是抽屉，不是段数（VIEW-001）',
      );
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

      await tester.tap(find.byKey(hudModeIconKey));
      await _pump(tester);

      expect(find.byKey(treeViewKey), findsOneWidget);
      expect(
        _crumbCount(tester),
        2,
        reason: '树的面包屑与宇宙同构：知识 › 空间（VIEW-006 修订 / 018 修订 2）',
      );
      expect(
        _crumbHas(tester, '知识'),
        isTrue,
        reason: '首段是位置名而不是「树」—— 原先写的是「树 › 全空间」',
      );
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

      await tester.tap(find.byKey(hudModeIconKey));
      await _pump(tester);

      final ZoomLevel expected = zoomForPhi(levels[row.id]!, hasChildren: true);
      expect(
        _crumbCount(tester),
        _crumbsFor(expected),
        reason: '段数 = 档位 —— 切回宇宙后走 φ 定档（VIEW-009），面包屑跟着它',
      );
      expect(find.byKey(treeViewKey), findsNothing, reason: '回宇宙后树不该还留着');
      expect(tester.takeException(), isNull);
    });

    testWidgets('树里点面包屑第 1 段 ⇒ 回 Z0 并切回宇宙（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, pack: loadAlphaPack(), mode: ViewMode.tree);

      // ⑦ 作废之后，树 → 宇宙只剩这一个入口：面包屑前段。
      await tester.tap(find.byKey(hudCrumbKey(0)));
      await _pump(tester);

      expect(find.byKey(treeViewKey), findsNothing, reason: '树没有 Z0 形态');
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有包时树照样能进去，报「没有可展开的树」而不是崩（SPEC-FND-014）', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(hudModeIconKey));
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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '筛选是收窄视野，不换档（VIEW-028）—— 面包屑仍是两段',
      );
      expect(
        _crumbHas(tester, 'Python'),
        isTrue,
        reason: '筛选也不换根 —— 第 2 段还是同一个空间',
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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z4),
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
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
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
    testWidgets('六轴罗盘六个轴名排在同一行（无 SPEC：布局口径，2026-10-18 提出）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);

      // 判据是**纵坐标相同**，不是「找得到六个按钮」—— 换行时六个按钮照样都
      // 找得到，所以「找得到」这件事本身证明不了一行。这条用例挡的是
      // `_compassMinWidth` / `_compassMaxWidth` 被调窄、或某个轴名变长之后
      // 悄悄折成两行。
      final Set<double> tops = <double>{
        for (final String axisKey in sixAxisKeys)
          tester.getTopLeft(find.byKey(compassAxisKey(axisKey))).dy,
      };
      expect(tops, hasLength(1), reason: '六个轴名必须在同一行：折行后「技术栈」孤零零落在第二行');
      expect(tester.takeException(), isNull);
    });

    testWidgets('两个轴都筛过、按钮带 ·N 后仍排在一行（无 SPEC：布局口径，2026-10-18 提出）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack);

      // α 包里**只有 `subject` 与 `ability` 有取值**（`role` / `industry` /
      // `topic` / `stack` 全空），所以两个 `·N` 只能落在这两个轴上 ——
      // 只测收起态会漏掉 `·N` 这一截宽度，而那正是收窄面板后最先炸的地方。
      for (final String axisKey in <String>['subject', 'ability']) {
        await tester.tap(find.byKey(compassAxisKey(axisKey)));
        await _pump(tester);
        await tester.tap(
          find.byKey(
            compassValueKey(axisKey, axisValuesOf(pack, axisKey).first),
          ),
        );
        await _pump(tester);
      }

      final Set<double> tops = <double>{
        for (final String axisKey in sixAxisKeys)
          tester.getTopLeft(find.byKey(compassAxisKey(axisKey))).dy,
      };
      expect(tops, hasLength(1), reason: '`·N` 不该把按钮挤到第二行');
      expect(tester.takeException(), isNull);
    });

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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z4),
        reason: '点星与搜索落点同一条路径 ⇒ 面包屑也到四段',
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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '退回出发地 ⇒ 面包屑也跟着回到两段',
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

    testWidgets('空间命中 ⇒ 换根到它并推到 Z1，选中项清空（SPEC-VIEW-001 / 027 / 031）', (
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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '空间落点推到 Z1（VIEW-027 / 031 修订）：Z0 现在是宇宙层，'
            '落到单个空间应当是「进去了」',
      );
      expect(_crumbHas(tester, 'Go'), isTrue, reason: '第 2 段是目标空间');
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
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '筛选类不改档位（VIEW-028）—— 改的只是根',
      );
      expect(
        _crumbHas(tester, 'Go'),
        isTrue,
        reason: '换根之后第 2 段是 Go；域属于旧空间，已随换根清掉（仍在两段）',
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

      // 在 Go 里再搜：`Z1` 默认只搜本空间 ⇒ 另一个空间的项要先点浮层顶部那行
      // 放宽。⚠️ 换根后落到的是 `Z1` 而不是 `Z0`（`VIEW-027` / `031` 修订：
      // `Z0` 变成宇宙层，「落到某个空间」= 进去了），作用域因此跟着收窄。
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
        findsNothing,
        reason: 'Z1 只搜本空间（VIEW-031），另一个空间的项默认不列',
      );

      await tester.tap(find.byKey(locateSearchAllKey));
      await _pump(tester);
      expect(
        find.byKey(locateRowKey(remote)),
        findsOneWidget,
        reason: '点「在全部空间中搜索」之后它才出现 —— 那一行就是作用域的出口',
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

      await tester.tap(find.byKey(hudModeIconKey));
      await _pump(tester);

      expect(
        find.textContaining('树 · 1 项'),
        findsOneWidget,
        reason: '树读的是 `_pack` —— 换根之后它必须跟着换',
      );
      expect(find.text('闭包'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('换根 chips 已撤：① 右侧不再有一排空间按钮（SPEC-VIEW-018 修订 3）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[_goPack()],
      );

      // `B3` 收尾时加过这排 chips（PR #59），作为「星系不可点」的替代入口。
      // 现在星系本身是入口（`VIEW-036`），chips 与它语义重复，且 chips 落 `Z0`
      // 与「点星系 ⇒ `Z1`」直接冲突 —— 整排删除，不留开关。
      expect(find.byKey(hudSpaceSwitchKey), findsNothing);
      expect(
        find.text('go'),
        findsNothing,
        reason: '另一个空间的名字（小写 id）不该出现在 ① 里',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('① 面包屑与图标（SPEC-VIEW-018 修订 2 · V-1a）', () {
    testWidgets('前段可点：点「知识」回 Z0（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z1));

      await tester.tap(find.byKey(hudCrumbKey(0)));
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z0),
        reason: '点第 1 段 = 退到宇宙层，面包屑跟着收成一段',
      );
      expect(_crumbHas(tester, 'Python'), isFalse, reason: 'Z0 不写空间名');
      expect(tester.takeException(), isNull);
    });

    testWidgets('末段不可点：点「Python」什么都不变（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      // 末段是纯文字、**没有 key** —— `_crumbCount` 依赖这一点，所以「点它」
      // 只能按文本点。点完段数不变即证明它没有去处。
      await tester.tap(find.text('Python'));
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '已在的位置点了没有去处；退层会让它变成一段',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('图标命中盒 44 px：盒外不切、盒内切（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      // 图形只有 14 px，命中盒 44 px（半径 22）。两个采样点分别落在盒外 3 px
      // 与盒内 3 px：若命中区退回图形大小，两点都会「点不中」。
      final Offset center = tester.getCenter(find.byKey(hudModeIconKey));

      await tester.tapAt(center + const Offset(25, 0));
      await _pump(tester);
      expect(
        find.byKey(treeViewKey),
        findsNothing,
        reason: '盒外 25 px（半径 22 之外）不该切换',
      );

      await tester.tapAt(center + const Offset(19, 0));
      await _pump(tester);
      expect(
        find.byKey(treeViewKey),
        findsOneWidget,
        reason: '盒内 19 px 可点 —— 看得见（14 px）与点得中（44 px）是两回事',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z0 有放大镜，点它开浮层（SPEC-VIEW-018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        zoom: ZoomLevel.z0,
      );

      expect(
        find.byKey(hudSearchKey),
        findsOneWidget,
        reason: 'Z0 不出项 ⇒ 搜索是进 Z4 的唯一通路，触屏设备还没有 ⌘K',
      );

      await tester.tap(find.byKey(hudSearchKey));
      await _pump(tester);
      expect(find.byKey(locateOverlayKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('退回上层之后 returnTo 不残留（SPEC-VIEW-015 / 018 修订 2）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final SceneBundle scene = _alphaScene(pack);
      await tester.pumpWidget(
        MaterialApp(home: UniverseScreen.single(scene: scene, pack: pack)),
      );
      await tester.pump();

      final Size viewport = tester.getSize(find.byType(UniverseScreen));
      final Offset star = _findPoint(
        scene,
        viewport,
        hit: true,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      await tester.tapAt(star);
      await _pump(tester);
      expect(find.byKey(detailBackKey), findsOneWidget, reason: '前提：点星进了详情');

      // 面包屑给了「不用返回按钮、直接退到上层」这条新路（`V-1a`）。
      await tester.tap(find.byKey(hudCrumbKey(0)));
      await _pump(tester);
      expect(find.byKey(hudDetailDrawerKey), findsNothing);

      // 再点同一颗星进详情，然后按返回：必须回到 **Z0**（本轮进详情的出发地），
      // 不是「上一颗星的 `Z4`」。残留的 `returnTo` 会让后者发生，而它看起来完全
      // 正常 —— 抽屉还开着，只是内容换了一颗星。
      await tester.tapAt(star);
      await _pump(tester);
      expect(find.byKey(detailBackKey), findsOneWidget, reason: '刚进详情 ⇒ 有出发地可回');

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'VIEW-015：返回的是出发地（Z0），不是上一颗星的 Z4',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z0));
      expect(tester.takeException(), isNull);
    });
  });
}
