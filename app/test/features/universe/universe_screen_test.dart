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
import 'package:project_knowledge/features/universe/galaxy_map.dart';
import 'package:project_knowledge/features/universe/nebula_map.dart';
import 'package:project_knowledge/features/universe/nebula_painter.dart';
import 'package:project_knowledge/features/universe/scene_pick.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';
import 'package:project_knowledge/features/universe/spiral_map.dart';
import 'package:project_knowledge/features/universe/spiral_painter.dart';
import 'package:project_knowledge/features/universe/star_closeup.dart';
import 'package:project_knowledge/features/universe/star_closeup_painter.dart';
import 'package:project_knowledge/features/universe/star_map.dart';
import 'package:project_knowledge/features/universe/star_painter.dart';
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
          SceneResolution(bundle: scene ?? buildSyntheticScene(), pack: pack),
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

/// `Z1` 盘面上某个域点的**窗口坐标**。
///
/// 重算同一份盘面布局（`layoutSpiral` 是纯函数，入参与画布一致），而不是从
/// widget 树里反推位置 —— 与 `_findPoint` 同一个做法：位置由几何唯一决定，
/// 两边各算一次、算错就会红。
Offset _domainPoint(
  WidgetTester tester,
  LoadedPack pack, {
  String? domainId,
  Size? window,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  final SpiralLayout layout = layoutSpiral(
    pack: pack,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
  final DomainMark mark = domainId == null
      ? layout.marks.first
      : layout.markOf(domainId)!;
  // 画布坐标 → 窗口坐标：降采样时画布比窗口小，乘 `scale` 才落回手指的位置。
  return mark.primary * plan.scale;
}

/// 进 `Z1` 盘面上的第一个域（点域点 ⇒ `Z2`，`VIEW-037`）。
///
/// `V-1c` 起 `Z1` 的项**不可点**（`VIEW-037`：项是背景），所以「点星进详情」
/// 这条既有断言必须先落到 `Z2`。这一步不是绕过新行为 —— 它就是新行为：
/// 域点成为 `Z1` 唯一的入口。
///
/// ⚠️ 这里只推**一帧**（`pump()`，不推时长）。推时长会让 `spin` 走起来，而
/// `_findPoint` 是按 `yaw = 0` 算的位置 —— 走 4.5° 之后 150 个点整体转过去，
/// 预计算的那一点就落在别的星上或落空。换档位不经过 `AnimatedSwitcher`
/// （变的是同一棵子树的 painter），所以一帧足够。
Future<void> _enterDomain(
  WidgetTester tester,
  LoadedPack pack, {
  Size? window,
  String? domainId,
}) async {
  await tester.tapAt(
    _domainPoint(tester, pack, window: window, domainId: domainId),
  );
  await tester.pump();
}

/// `Z2` 云里某一项（默认第一项）的**窗口坐标**。
///
/// 与 `_domainPoint` 同一个做法：`layoutNebula` 是纯函数，入参与画布一致，
/// 位置由几何唯一决定 —— 两边各算一次、算错就会红。
Offset _nebulaItemPoint(
  WidgetTester tester,
  LoadedPack pack, {
  int index = 0,
  Size? window,
  String? domainId,
  bool starOnly = false,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  final NebulaLayout layout = layoutNebula(
    pack: pack,
    domainId: domainId ?? pack.space.domainIds.first,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
  // [starOnly] 时按**拾取几何**挑 —— `layout.items` 里也有亮结的根（它同时是
  // 云里的一颗星），点中它会被 `pickNebulaKnotAt` 先截走 ⇒ 落 `Z3` 而不是 `Z4`。
  final NebulaItem item = starOnly
      ? layout.items.firstWhere(
          (NebulaItem each) =>
              pickNebulaKnotAt(layout: layout, point: each.center) == null,
          orElse: () => throw StateError(
            '这个域里每颗星都落在某个亮结的命中圈内 —— 换一个域或夹具',
          ),
        )
      : layout.items[index];
  return item.center * plan.scale;
}

/// `Z2` 里第一个亮结的**窗口坐标**（`VIEW-038`：亮结可点 ⇒ `Z3`）。
Offset _nebulaKnotPoint(
  WidgetTester tester,
  LoadedPack pack, {
  int index = 0,
  Size? window,
  String? domainId,
  bool multiOnly = false,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  final NebulaLayout layout = layoutNebula(
    pack: pack,
    domainId: domainId ?? pack.space.domainIds.first,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
  // [multiOnly]：单项子树由 `VIEW-038` 直接送 `Z4`，要验 `Z3` 就必须跳过它们
  // （否则断言「进了 Z3」会红在一个跟本笔无关的分支上）。
  final NebulaKnot knot = multiOnly
      ? layout.knots.firstWhere(
          (NebulaKnot each) => !each.isSingle,
          orElse: () => throw StateError(
            '这个域里没有多项子树 —— `Z3` 这条路径无从进入',
          ),
        )
      : layout.knots[index];
  return knot.center * plan.scale;
}

/// `Z2` 里一个「点不中任何东西」的窗口坐标 —— 既不在亮结的 24 px 命中圈里，
/// 也不在项的 8 px 圈里。
///
/// 不复用 `_findPoint(hit: false)`：那一条问的是项投影的拾取，而 `Z2` 现在不
/// 走那条路（`V-1d`）。两种空白定义混用会让「点空白不动选中」在换形态后假绿。
Offset _nebulaBlankPoint(
  WidgetTester tester,
  LoadedPack pack, {
  Size? window,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  final NebulaLayout layout = layoutNebula(
    pack: pack,
    domainId: pack.space.domainIds.first,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
  for (double y = 160; y < size.height - 160; y += 13) {
    for (double x = 40; x < size.width - 420; x += 13) {
      final Offset point = Offset(x, y);
      final Offset inCanvas = point / plan.scale;
      if (pickNebulaKnotAt(layout: layout, point: inCanvas) != null) {
        continue;
      }
      if (pickNebulaItemAt(layout: layout, point: inCanvas) != null) {
        continue;
      }
      return point;
    }
  }
  fail('扫不到「点不中亮结也点不中项」的位置');
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

      // `V-1c` 起 `Z1` 的项不可点（`VIEW-037`）⇒ 先进一个域，到 `Z2` 再点星。
      await _enterDomain(tester, pack);

      // `V-1d` 起 `Z2` 画的是云（`NebulaPainter`）：星的位置由 `layoutNebula`
      // 定，不再是项投影 —— 落点也必须按那一套算。
      await tester.tapAt(_nebulaItemPoint(tester, pack));
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

      // `Z1` 的项不可点（`VIEW-037`）⇒ 先进域到 `Z2`。`V-1d` 起那一档是云，
      // 「点中」与「点空白」都按 `layoutNebula` 的那一套判。
      await _enterDomain(tester, pack);
      await tester.tapAt(_nebulaItemPoint(tester, pack));
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);

      await tester.tapAt(_nebulaBlankPoint(tester, pack));
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

      // `V-1c` 起 `Z1` 画的是盘面（`SpiralPainter`），项不可点 ⇒ 先进域到 `Z2`，
      // 那里才是 `FramePainter` 与可点的星。
      await _enterDomain(tester, pack, window: const Size(3840, 2160));

      // 画布缩到基准面积（4K 逻辑尺寸 = 4 倍面积 ⇒ 线性缩一半）。
      // ⚠️ `V-1d` 起 `Z2` 的 painter 是 `NebulaPainter` —— 这一条问的是**画布
      // 尺寸与铺满**（`C-33`），与画的是什么无关，predicate 跟着形态走。
      final Finder canvas = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint && widget.painter is NebulaPainter,
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
        _nebulaItemPoint(tester, pack, window: const Size(3840, 2160)),
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

  group('⑥ 罗盘跨根取值域（SPEC-VIEW-020 修订 5 · V-1f2）', () {
    /// 与 α 包**学科不同**的第二个根。
    ///
    /// 30 项 / 3 个域是刻意的：`Z0` 的星系盘与 `Z1` 的盘都按规模反解几何，
    /// 1 项的空间会被判成退化（`_z0Space` 的注释记过这件事）。
    LoadedPack languagePack() => fixturePack(
      <FixtureItem>[
        for (int i = 0; i < 30; i++)
          FixtureItem('de-$i', 'De 第 $i 项', domainId: 'de/d${i % 3}'),
      ],
      spaceId: 'german',
      spaceName: '德语',
      subject: '语言',
    );

    /// `Z0` 上某个星系的**窗口坐标**。画布坐标 → 窗口坐标要乘 `plan.scale`。
    Offset galaxyPoint(
      WidgetTester tester,
      LoadedPack here,
      LoadedPack other,
      String spaceId,
    ) {
      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      final GalaxyLayout layout = layoutGalaxies(
        roots: <SceneResolution>[
          SceneResolution(bundle: _alphaScene(here), pack: here),
          SceneResolution(bundle: _alphaScene(other), pack: other),
        ],
        viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
      );
      final GalaxyDisc disc = layout.discOf(spaceId)!;
      return Offset(disc.centerX, disc.centerY) * plan.scale;
    }

    testWidgets('Z0 罗盘的学科列出全部根的取值，不只看当前根（SPEC-VIEW-020）', (
      WidgetTester tester,
    ) async {
      final LoadedPack python = loadAlphaPack();
      final LoadedPack german = languagePack();
      await _pumpScreen(
        tester,
        pack: python,
        scene: _alphaScene(python),
        others: <LoadedPack>[german],
        zoom: ZoomLevel.z0,
      );

      final String pythonSubject = axisValuesOf(python, 'subject').first;
      await tester.tap(find.byKey(compassAxisKey('subject')));
      await _pump(tester);

      expect(
        find.byKey(compassValueKey('subject', pythonSubject)),
        findsOneWidget,
      );
      expect(
        find.byKey(compassValueKey('subject', '语言')),
        findsOneWidget,
        reason: '缺陷本体：站在 α 根上，另一个根的学科也必须能选',
      );
    });

    testWidgets('选别的根的取值 ⇒ 切过去 Z1 照常，域点还能进 Z2（SPEC-VIEW-020）', (
      WidgetTester tester,
    ) async {
      final LoadedPack python = loadAlphaPack();
      final LoadedPack german = languagePack();
      await _pumpScreen(
        tester,
        pack: python,
        scene: _alphaScene(python),
        others: <LoadedPack>[german],
        zoom: ZoomLevel.z0,
      );

      await tester.tap(find.byKey(compassAxisKey('subject')));
      await _pump(tester);
      await tester.tap(find.byKey(compassValueKey('subject', '语言')));
      await _pump(tester);

      await tester.tapAt(galaxyPoint(tester, python, german, 'german'));
      await _pump(tester);

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z1));
      expect(
        find.byKey(hudNoMatchKey),
        findsNothing,
        reason: '语言包的 30 项都声明了「语言」，筛完不该是空',
      );
      expect(find.byKey(domainLabelKey('de/d0')), findsOneWidget);

      await _enterDomain(tester, german, domainId: 'de/d1');
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z2));
    });

    testWidgets('取值在本根无匹配 ⇒ 明示一行小字，且不吞域点的点击（SPEC-VIEW-020）', (
      WidgetTester tester,
    ) async {
      final LoadedPack python = loadAlphaPack();
      final LoadedPack german = languagePack();
      await _pumpScreen(
        tester,
        pack: python,
        scene: _alphaScene(python),
        others: <LoadedPack>[german],
        zoom: ZoomLevel.z0,
      );

      final String pythonSubject = axisValuesOf(python, 'subject').first;
      await tester.tap(find.byKey(compassAxisKey('subject')));
      await _pump(tester);
      await tester.tap(find.byKey(compassValueKey('subject', pythonSubject)));
      await _pump(tester);

      // 换根：筛选跟着过去（`VIEW-028`：筛选是视野状态，不随根重置），
      // 而德语包没有任何一项是「计算机科学」⇒ 这一档一项都画不出来。
      await tester.tapAt(galaxyPoint(tester, python, german, 'german'));
      await _pump(tester);
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z1));

      expect(
        find.byKey(hudNoMatchKey),
        findsOneWidget,
        reason: '筛空时画面与「渲染坏了」长得一样，必须有一行字说清楚',
      );

      // 提示是说明，不是遮罩：域点仍要能点进 `Z2`。
      await _enterDomain(tester, german, domainId: 'de/d0');
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z2));
      expect(find.byKey(hudNoMatchKey), findsOneWidget);
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

      // `V-1c` 起 `Z1` 的项不可点（`VIEW-037`）⇒ 先进域到 `Z2`。
      await _enterDomain(tester, pack);
      await tester.tapAt(_nebulaItemPoint(tester, pack));
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(find.byKey(detailBackKey), findsOneWidget);

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'Z2 没有详情（VIEW-013）⇒ 已经退回来了',
      );
      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z2),
        reason: '退回出发地 ⇒ 面包屑也跟着回到三段（域那一层）',
      );
      expect(find.byKey(detailBackKey), findsNothing, reason: '退无可退之后按钮再次消失');
      expect(tester.takeException(), isNull);
    });

    testWidgets('从 Z3 退回 Z2 再点星 ⇒ 返回仍落在那个域（SPEC-VIEW-015 修订三）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      // 第 **2** 个域：丢了就会退回「第一个域」，而两段的画面都「像」正常 ——
      // 只有内容不对，这正是修订三第 7 条要挡的那类静默错误。
      final String domain = pack.space.domainIds[1];
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      await tester.tapAt(_domainPoint(tester, pack, domainId: domain));
      await tester.pump();
      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z2),
        reason: '前提：已经进了这个域',
      );

      // 点亮结进 `Z3`，再从**面包屑第 3 段**退回 `Z2`。这一步把选中项清空、
      // 域留着 —— 于是「进详情前的选中项」是 `null`，域从选中项**推不出来**。
      await tester.tapAt(
        _nebulaKnotPoint(tester, pack, domainId: domain, multiOnly: true),
      );
      await tester.pump();
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z3), reason: '前提：进了 Z3');
      await tester.tap(find.byKey(hudCrumbKey(2)));
      await tester.pump();
      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z2),
        reason: '前提：退到 Z2 且域还在',
      );

      await tester.tapAt(
        _nebulaItemPoint(tester, pack, domainId: domain, starOnly: true),
      );
      await tester.pump();
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4), reason: '前提：进了详情');

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z2),
        reason: '域进了快照 ⇒ 返回仍是三段；按选中项回推时这里是 null，只剩两段',
      );
      expect(
        _crumbHas(tester, domain),
        isTrue,
        reason: '第 3 段必须是**出发时那个域** —— 不是空白，也不是第一个域',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z3 点行星进详情再返回：域跟着选中项回到 Z3（SPEC-VIEW-015 修订三）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final String domain = pack.space.domainIds[1];
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      await tester.tapAt(_domainPoint(tester, pack, domainId: domain));
      await tester.pump();

      // 直接算亮结位置（同 `_nebulaKnotPoint`），因为下面还要它的 `rootId`
      // 去重算恒星系 —— 少算一遍就少一处可能与拾取不一致的地方。
      final Size size = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        size.width,
        size.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      final NebulaLayout nebula = layoutNebula(
        pack: pack,
        domainId: domain,
        viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
      );
      final NebulaKnot knot = nebula.knots.firstWhere(
        (NebulaKnot each) => !each.isSingle,
      );
      await tester.tapAt(knot.center * plan.scale);
      await tester.pump();

      final StarSystemLayout layout = _starSystemOf(tester, pack, knot.rootId);
      await tester.tapAt(layout.planets.first.center * _pointScaleOf(tester));
      await tester.pump();
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z3),
        reason: '`Z3` 只画该域的链 ⇒ 返回后域必须还在（修订三第 9 条）',
      );
      expect(_crumbHas(tester, domain), isTrue);
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

      // `V-1c` 起 `Z1` 的项不可点（`VIEW-037`）⇒ 先进域到 `Z2`。
      await _enterDomain(tester, pack);
      await tester.tapAt(_nebulaItemPoint(tester, pack));
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
      // `V-1c` 起 `Z1` 的项不可点（`VIEW-037`）⇒ 先进域到 `Z2`。
      await _enterDomain(tester, pack);
      await tester.tapAt(_nebulaItemPoint(tester, pack));
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
        reason:
            '空间落点推到 Z1（VIEW-027 / 031 修订）：Z0 现在是宇宙层，'
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

      expect(find.byKey(hudFilterChipsKey), findsOneWidget, reason: '筛选写进去了');
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
      expect(remote.spaceId, 'python', reason: '命中来自另一个空间 —— 换根之后它成了「别人」');
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

    testWidgets('换根后树里是新根的项（SPEC-VIEW-031 / 021）', (WidgetTester tester) async {
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
      expect(find.text('go'), findsNothing, reason: '另一个空间的名字（小写 id）不该出现在 ① 里');
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
        MaterialApp(
          home: UniverseScreen.single(scene: scene, pack: pack),
        ),
      );
      await tester.pump();

      // `V-1c` 起 `Z1` 的项不可点（`VIEW-037`）⇒ 先进域到 `Z2` 再点星。
      // `V-1d` 起 `Z2` 是云 ⇒ 「同一颗星」按 `layoutNebula` 的那一套算位置。
      await _enterDomain(tester, pack);
      final Offset star = _nebulaItemPoint(tester, pack);
      await tester.tapAt(star);
      await _pump(tester);
      expect(find.byKey(detailBackKey), findsOneWidget, reason: '前提：点星进了详情');

      // 面包屑给了「不用返回按钮、直接退到上层」这条新路（`V-1a`）。
      //
      // 退到 **`Z1`（第 2 段）** 而不是 `Z0`：`Z0` 自 `V-1b` 起是宇宙层、不出项
      // （`VIEW-036`），在那里点不出「同一颗星」—— 点到的是星系，落点变成换根。
      // 这一条验的是 `returnTo` 残留，不是宇宙层的形态，所以退到还能进域的那一层。
      await tester.tap(find.byKey(hudCrumbKey(1)));
      await _pump(tester);
      expect(find.byKey(hudDetailDrawerKey), findsNothing);

      // 再从 `Z1` 进同一个域、点同一颗星。`V-1c` 之后 `Z1` 上没有「同一颗星」
      // 可点（项是背景），所以中间这一步是**重新进域** —— 位置与第一次相同，
      // 因为盘面布局是纯函数。
      await _enterDomain(tester, pack);

      // 按返回：必须回到 **`Z2`**（本轮进详情的出发地），不是「上一颗星的
      // `Z4`」。残留的 `returnTo` 会让后者发生，而它看起来完全正常 ——
      // 抽屉还开着，只是内容换了一颗星。
      await tester.tapAt(star);
      await _pump(tester);
      expect(
        find.byKey(detailBackKey),
        findsOneWidget,
        reason: '刚进详情 ⇒ 有出发地可回',
      );

      await tester.tap(find.byKey(detailBackKey));
      await _pump(tester);
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'VIEW-015：返回的是出发地（Z2），不是上一颗星的 Z4',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Z0 宇宙 = N 个星系（SPEC-VIEW-036 · V-1b）', () {
    /// 与界面同源的一次布局：同一条 `layoutGalaxies`、同一个绘制表面。
    ///
    /// 不把期望坐标写死 —— 写死的话，改了 `C-52` 或哈希就要改测试，而测试改成
    /// 什么样都算「通过」。这里比的是「界面点得中的那个位置，是不是布局算出来的
    /// 那个位置」。
    GalaxyLayout layoutOf(
      WidgetTester tester,
      LoadedPack pack,
      LoadedPack other,
    ) {
      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      return layoutGalaxies(
        roots: <SceneResolution>[
          SceneResolution(bundle: _alphaScene(pack), pack: pack),
          SceneResolution(bundle: _alphaScene(other), pack: other),
        ],
        viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
      );
    }

    testWidgets('一个空间一个星系：标注在屏上，且这一档不出项（SPEC-VIEW-036）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[_z0Space()],
        zoom: ZoomLevel.z0,
      );

      expect(find.byKey(galaxyLabelKey(pack.space.id)), findsOneWidget);
      expect(find.byKey(galaxyLabelKey('go')), findsOneWidget);
      // 标注副行给的是**规模**（`VIEW-035`：不放事件计数）。
      expect(
        find.text('${pack.items.length} 项 · ${pack.space.domainIds.length} 域'),
        findsOneWidget,
      );
      // `Z0` 不出项 ⇒ 没有详情抽屉，面包屑只有第 1 段。
      expect(find.byKey(hudDetailDrawerKey), findsNothing);
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('点星系 ⇒ 换根并落到 Z1（VIEW-036 / VIEW-027 修订）（SPEC-VIEW-036）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      final LoadedPack go = _z0Space();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[go],
        zoom: ZoomLevel.z0,
      );

      final GalaxyLayout layout = layoutOf(tester, pack, go);
      final GalaxyDisc target = layout.discOf('go')!;
      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );

      // 画布坐标 → 窗口坐标：降采样时两者不等，直接用画布坐标会点偏。
      await tester.tapAt(Offset(target.centerX, target.centerY) * plan.scale);
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: '落到单个空间应当是「进去了」⇒ Z1，不是回到 Z0',
      );
      expect(find.byKey(galaxyLabelKey('go')), findsNothing, reason: '已离开宇宙层');
      expect(
        find.textContaining('60 项'),
        findsOneWidget,
        reason: '诊断行跟着换根 —— 它是「现在画的是哪个空间」的唯一出处',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有包就没有星系（不凭空造空间）（SPEC-VIEW-036）', (WidgetTester tester) async {
      // 合成回落的根背后没有 `KnowledgeSpace`。
      await _pumpScreen(tester, zoom: ZoomLevel.z0);

      expect(find.byKey(galaxyLabelKey('python')), findsNothing);
      expect(
        find.byKey(hudZ0DegradedKey),
        findsNothing,
        reason: '空布局不构成退化 —— 退化说的是「盘小到画不出」',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('盘半径触底时把退化说出来（C-53）', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[_z0Space()],
        zoom: ZoomLevel.z0,
      );

      expect(
        find.byKey(hudZ0DegradedKey),
        findsOneWidget,
        reason: 'VIEW-036：k 触底是**可计算的判据**，且必须让人看到',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Z1 星系盘（SPEC-VIEW-037 · V-1c）', () {
    testWidgets('一个域一个标注，且画的是盘面而不是项投影（SPEC-VIEW-037）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      for (final String domainId in pack.space.domainIds) {
        expect(
          find.byKey(domainLabelKey(domainId)),
          findsOneWidget,
          reason: '域 $domainId 在盘上没有落点标注',
        );
      }
      final Finder spiral = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint && widget.painter is SpiralPainter,
      );
      expect(spiral, findsOneWidget, reason: 'Z1 走自己的几何与绘制（VIEW-037）');
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is FramePainter,
        ),
        findsNothing,
        reason: '同一时刻只该有一种几何 —— 两套叠着画会让拾取与画面各说一套',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点域点 ⇒ 落到 Z2，选中该域最浅的一项（SPEC-VIEW-037 / 028）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      await _enterDomain(tester, pack);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z2),
        reason: '域点是唯一可点对象，落点就是「进这个域」',
      );
      expect(_crumbHas(tester, pack.space.domainIds.first), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点项什么都不发生 —— 项是背景（SPEC-VIEW-037）', (WidgetTester tester) async {
      // ⚠️ 用**三个域**的夹具而不是 α 包：α 包十个域挤在 126 px 的盘上，
      // 域点之间只隔 11 px、24 px 命中圈连成一片 —— 那时「点项」落进某个域的
      // 命中圈是**规格内**的行为（「先判域点，再一律不响应」），验不出
      // 「点项无反应」。三个域时段长 37.8 px，段边缘的项确实在圈外。
      final LoadedPack pack = fixturePack(<FixtureItem>[
        for (final String domain in <String>['s/a', 's/b', 's/c'])
          for (int i = 0; i < 4; i++)
            FixtureItem('$domain-$i', '$domain 第 $i 项', domainId: domain),
      ]);
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      final SpiralLayout layout = layoutSpiral(
        pack: pack,
        viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
      );
      // 挑一个在**所有** 12 px 命中圈之外的背景项。
      const double floor = domainMarkMinTapDiameter / 2 + 1;
      final Offset? outside = layout.items
          .where(
            (Offset point) => layout.marks.every(
              (DomainMark mark) => mark.points.every(
                (Offset markPoint) => (markPoint - point).distance > floor,
              ),
            ),
          )
          .firstOrNull;
      expect(outside, isNotNull, reason: '盘上总有圈外的背景项；没有说明布局挤成一团');

      await tester.tapAt(outside! * plan.scale);
      await _pump(tester);

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z1),
        reason: 'VIEW-037：点项不产生任何跳转',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: '连选中都不该发生 —— 暗 = 背景，给软响应就等于让它可点',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有包时不画盘面，只留诊断行（SPEC-FND-014）', (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is SpiralPainter,
        ),
        findsNothing,
        reason: '没有 KnowledgeSpace 就没有域 → 没有盘（不凭空造一个）',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Z2 分子云（SPEC-VIEW-038 · V-1d）', () {
    /// 单域单链：`a → b → c`，外加一个两项的 `vocab` 域。
    LoadedPack cloudPack() => fixturePack(
      const <FixtureItem>[
        FixtureItem('a', '甲'),
        FixtureItem('b', '乙'),
        FixtureItem('c', '丙'),
        FixtureItem('x', '习', domainId: 'python/vocab'),
        FixtureItem('y', '记', domainId: 'python/vocab'),
      ],
      edges: const <List<String>>[
        <String>['a', 'b'],
        <String>['b', 'c'],
        <String>['c', 'x'],
      ],
    );

    /// 只有一个域的包 —— 那个域是**单项子树**（点它要跳过 `Z3`）。
    LoadedPack singleItemPack() => fixturePack(
      const <FixtureItem>[FixtureItem('only', '唯一的项')],
    );

    testWidgets('画的是云而不是项投影，亮结带标注（SPEC-VIEW-038）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = cloudPack();
      await _pumpScreen(tester, pack: pack);
      await _enterDomain(tester, pack);
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is NebulaPainter,
        ),
        findsOneWidget,
        reason: 'VIEW-038：Z2 是一朵分子云',
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is FramePainter,
        ),
        findsNothing,
        reason: '两套几何不能并存 —— 并存时哪一套在上层是运气',
      );
      expect(
        find.byKey(nebulaKnotKey('a')),
        findsOneWidget,
        reason: 'a→b→c 是一棵子树 ⇒ 一个亮结，标注写根项标题',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('亮点结 ⇒ 落到 Z3（SPEC-VIEW-038）', (WidgetTester tester) async {
      final LoadedPack pack = cloudPack();
      await _pumpScreen(tester, pack: pack);
      await _enterDomain(tester, pack);
      await tester.pump();

      await tester.tapAt(_nebulaKnotPoint(tester, pack));
      await tester.pump();

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z3),
        reason: '亮结是容器 ⇒ 进恒星系（VIEW-001：Z2 容器与星都能点）',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'Z3 不是详情 —— 详情只在 Z4',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('单项子树的亮结 ⇒ 直接 Z4，跳过 Z3（SPEC-VIEW-038）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = singleItemPack();
      await _pumpScreen(tester, pack: pack);
      await _enterDomain(tester, pack);
      await tester.pump();

      await tester.tapAt(_nebulaKnotPoint(tester, pack));
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '给只有一颗行星的恒星系画共面轨道是纯粹的空转',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('点云里的星 ⇒ Z4 详情（SPEC-VIEW-014）', (WidgetTester tester) async {
      final LoadedPack pack = cloudPack();
      await _pumpScreen(tester, pack: pack);
      await _enterDomain(tester, pack);
      await tester.pump();

      // 取最后一项：它是链尾，离亮结（质心）最远，不会被容器抢走。
      await tester.tapAt(_nebulaItemPoint(tester, pack, index: 2));
      await tester.pump();

      expect(find.byKey(hudDetailDrawerKey), findsOneWidget, reason: '星是可点对象');
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('跨域边画成出口标记，不画断线（SPEC-VIEW-038）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = cloudPack();
      await _pumpScreen(tester, pack: pack);
      await _enterDomain(tester, pack);
      await tester.pump();

      expect(
        find.byKey(nebulaExitKey('python/vocab')),
        findsOneWidget,
        reason: 'c→x 跨到 vocab ⇒ 云缘一个朝外的箭头 + 一行「→ 进入 vocab」',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('云心的那一项点得中 —— ⑤ 占位不吃点击（SPEC-VIEW-038）', (
      WidgetTester tester,
    ) async {
      // α 包一个域 15 项、全落同一扇区 ⇒ 最内那一项离画面中心不到 10 px，
      // 正好压在 ⑤「焦点星」的占位槽下面。`V-1d` 之前没人点过那里：
      // 占位是个普通 `Container`，它会把手势吃掉，而画面上一切正常。
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));
      await _enterDomain(tester, pack);
      await tester.pump();

      await tester.tapAt(_nebulaItemPoint(tester, pack));
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '占位是纯装饰 —— 它不该接住任何手势（R-08：违反它现在会红）',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('标注避让（V-1d2）', () {
    testWidgets('Z1 十个域的标注两两不相交 —— 真机那对 verb-* 就在里面（SPEC-VIEW-037）', (
      WidgetTester tester,
    ) async {
      // α 包 10 个域落在两条臂上，`verb-conjugation`(513,232) 与
      // `verb-frame`(571,225) 中心距 58 px 而标签宽 120 —— 终端截图里压了约
      // 8 px。`V-1c` 的注释把这件事写成「接受重叠，归终端观感验收」：**十一个**
      // 域挤在一起是取舍，**相邻两个**压在一起只是没做。
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      final List<String> ids = pack.space.domainIds;
      final List<Rect> rects = <Rect>[
        for (final String domainId in ids)
          tester.getRect(find.byKey(domainLabelKey(domainId))),
      ];
      expect(rects, hasLength(ids.length));

      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason:
                '${ids[i]} 与 ${ids[j]} 的标注压在一起：'
                '${rects[i]} vs ${rects[j]}',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z0 三个空间的标注不压在一起，且各离自己那个盘最近 —— 回归护栏（SPEC-VIEW-036）', (
      WidgetTester tester,
    ) async {
      // ⚠️ **这条在旧实现上也是绿的** —— 如实说清，免得它被当成本笔缺陷的证据。
      // 实测：把 `C-70` 归零（等效于 `V-1d` 的「一律正下方」）之后它照样通过，
      // 说明在 α(150) + english(80) + german(80) 这个夹具下，正下方的副行既没
      // 压到别的标注，也没有离别的盘更近。终端截图里 German 的副行确实卡在
      // 与 Python 之间那条 36 px 的缝里，但**复现它需要的那组盘心间距没找到**
      // （`galaxy_map` 的散布由项数反解，夹具改项数就同时改了间距）。
      //
      // 所以这条的定位是**护栏**而不是证据：将来谁改动了 `Z0` 的标注落点或盘的
      // 散布，若把标签挤到别的盘上或别的标注上，它会红。真机那处缝归终端看图，
      // 已记进 `STR` 轮次 `R8` 的未验项。
      tester.view.physicalSize = const Size(1080, 580);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final LoadedPack pack = loadAlphaPack();
      final LoadedPack english = fixturePack(
        <FixtureItem>[
          for (int i = 0; i < 80; i++)
            FixtureItem('en-$i', 'English $i', domainId: 'english/d${i % 8}'),
        ],
        spaceId: 'english',
        spaceName: 'English',
      );
      final LoadedPack german = fixturePack(
        <FixtureItem>[
          for (int i = 0; i < 80; i++)
            FixtureItem('de-$i', 'Deutsch $i', domainId: 'german/d${i % 8}'),
        ],
        spaceId: 'german',
        spaceName: 'Deutsch',
      );
      await _pumpScreen(
        tester,
        pack: pack,
        scene: _alphaScene(pack),
        others: <LoadedPack>[english, german],
        zoom: ZoomLevel.z0,
      );

      const List<String> ids = <String>['python', 'english', 'german'];
      final List<Rect> rects = <Rect>[
        for (final String id in ids)
          tester.getRect(find.byKey(galaxyLabelKey(id))),
      ];
      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '${ids[i]} 与 ${ids[j]} 的标注压在一起：'
                '${rects[i]} vs ${rects[j]}',
          );
        }
      }

      // 更要紧的一条：**标签得离自己那个盘最近**。真机截图里 German 的副行
      // 掉进 German 与 Python 之间那条 36 px 的缝 —— 它没压住任何东西，两个盘
      // 的标注也没互压，但读起来像是 Python 盘的说明。这才是那处观感问题。
      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      final GalaxyLayout layout = layoutGalaxies(
        roots: <SceneResolution>[
          SceneResolution(bundle: _alphaScene(pack), pack: pack),
          SceneResolution(bundle: _alphaScene(english), pack: english),
          SceneResolution(bundle: _alphaScene(german), pack: german),
        ],
        viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
      );
      for (final String id in ids) {
        final Rect r = tester.getRect(find.byKey(galaxyLabelKey(id)));
        final GalaxyDisc own = layout.discOf(id)!;
        final double ownDistance = (r.center - own.center * plan.scale).distance;
        for (final GalaxyDisc other in layout.discs) {
          if (other.spaceId == id) {
            continue;
          }
          expect(
            ownDistance,
            lessThan((r.center - other.center * plan.scale).distance),
            reason:
                '「$id」的标注离「${other.spaceId}」更近 —— '
                '读者会把它读成那个空间的说明',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z2 的亮结与出口标注不互相压 —— V-1d 时它们各落各的（SPEC-VIEW-038）', (
      WidgetTester tester,
    ) async {
      // `V-1d` 里亮结落正下方、出口按箭头方向外让 —— 两段谁也不看谁。放进同一次
      // 避让之后，「同一朵云里抢地方」才有判据。
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));
      await _enterDomain(tester, pack);

      final Size window = tester.getSize(find.byType(UniverseScreen));
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      );
      final Size surface = Size(plan.surfaceWidth, plan.surfaceHeight);
      final String domainId = layoutSpiral(
        pack: pack,
        viewport: surface,
      ).marks.first.domainId;
      final NebulaLayout layout = layoutNebula(
        pack: pack,
        domainId: domainId,
        viewport: surface,
      );

      final List<Rect> rects = <Rect>[
        for (final NebulaKnot knot in layout.knots)
          tester.getRect(find.byKey(nebulaKnotKey(knot.rootId))),
        for (final NebulaExit exit in layout.exits)
          tester.getRect(find.byKey(nebulaExitKey(exit.targetDomainId))),
      ];
      expect(rects.length, greaterThan(1), reason: '这条用例要有东西可压');

      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: 'Z2 的标注 $i 与 $j 压在一起：${rects[i]} vs ${rects[j]}',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('⑤「焦点星」占位不再显示文字，但槽还在（SPEC-VIEW-018）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      expect(
        find.byKey(hudFocusStarKey),
        findsOneWidget,
        reason: '槽要留着 —— 「这里有个格子」得可断言',
      );
      expect(
        find.text('焦点星'),
        findsNothing,
        reason:
            '占位落在屏幕正中，而 Z1 的核球、Z2 的云心也在那里 —— '
            '三个字压上去会被读成一个域名（终端截图已证）',
      );
      expect(tester.getSize(find.byKey(hudFocusStarKey)), Size.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('标注不出视口 —— 平移而不是缩字（SPEC-VIEW-036）', (
      WidgetTester tester,
    ) async {
      // 800×480 下盘半径只有 100.8，靠盘缘的域标注横向会顶出去。
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final LoadedPack pack = loadAlphaPack();
      await _pumpScreen(tester, pack: pack, scene: _alphaScene(pack));

      final Size window = tester.getSize(find.byType(UniverseScreen));
      for (final String domainId in pack.space.domainIds) {
        final Rect r = tester.getRect(find.byKey(domainLabelKey(domainId)));
        expect(r.left, greaterThanOrEqualTo(-0.01), reason: '$domainId 出了左边');
        expect(
          r.right,
          lessThanOrEqualTo(window.width + 0.01),
          reason: '$domainId 出了右边',
        );
        expect(r.top, greaterThanOrEqualTo(-0.01), reason: '$domainId 出了上边');
        expect(
          r.bottom,
          lessThanOrEqualTo(window.height + 0.01),
          reason: '$domainId 出了下边',
        );
        // 内收只平移：宽度仍是 `_domainLabelWidth`，没被压窄。
        expect(r.width, closeTo(120, 0.01), reason: '$domainId 被缩字了');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Z3 恒星系（SPEC-VIEW-039 · V-1e）', () {
    /// 单域单链 `a → b → c` —— `english` / `german` 那种「每域 10 项 9 边」
    /// 的最小版。链是 `VIEW-039` 明写的常态形状。
    LoadedPack starPack() => fixturePack(
      const <FixtureItem>[
        FixtureItem('a', '甲'),
        FixtureItem('b', '乙'),
        FixtureItem('c', '丙'),
      ],
      edges: const <List<String>>[
        <String>['a', 'b'],
        <String>['b', 'c'],
      ],
    );

    testWidgets('从 Z2 点亮结进来，画的是恒星系而不是项投影（SPEC-VIEW-039）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = starPack();
      await _pumpScreen(tester, pack: pack);
      final String rootId = await _enterStarSystem(tester, pack);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is StarPainter,
        ),
        findsOneWidget,
        reason: 'VIEW-039：Z3 是一颗恒星 + 共面轨道',
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is FramePainter,
        ),
        findsNothing,
        reason: '两套几何不能并存 —— 并存时哪一套在上层是运气',
      );
      expect(
        find.byKey(starLabelKey(rootId)),
        findsOneWidget,
        reason: '恒星标名（根项标题），行星不标名',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z3));
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: 'Z3 不是详情 —— 抽屉只在 Z4（VIEW-001）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点行星 ⇒ Z4 详情，选中的是那颗行星（SPEC-VIEW-039 / 014）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = starPack();
      await _pumpScreen(tester, pack: pack);
      final String rootId = await _enterStarSystem(tester, pack);
      final StarSystemLayout layout = _starSystemOf(tester, pack, rootId);
      final StarPlanet planet = layout.planets.first;

      await tester.tapAt(planet.center * _pointScaleOf(tester));
      await tester.pump();

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text('乙'),
        ),
        findsWidgets,
        reason: '点的是 b（乙）—— 抽屉里必须是它，不是恒星',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点恒星 ⇒ Z4，选中的是根项（SPEC-VIEW-039）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = starPack();
      await _pumpScreen(tester, pack: pack);
      final String rootId = await _enterStarSystem(tester, pack);
      final StarSystemLayout layout = _starSystemOf(tester, pack, rootId);

      await tester.tapAt(layout.starCenter * _pointScaleOf(tester));
      await tester.pump();

      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text('甲'),
        ),
        findsWidgets,
        reason: '恒星就是根项 a（甲）—— 点它进的是它自己的特写',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点空白不动选中 —— 详情不会毫无预警地消失（SPEC-VIEW-039 / 014）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = starPack();
      await _pumpScreen(tester, pack: pack);
      final String rootId = await _enterStarSystem(tester, pack);
      final StarSystemLayout layout = _starSystemOf(tester, pack, rootId);

      // 先点一颗行星进 Z4，再退回 Z3 点空白 —— 空白要真的什么都没中就退出
      // 这一步就白测了，所以空白点先按几何验一遍。
      await tester.tapAt(layout.planets.first.center * _pointScaleOf(tester));
      await tester.pump();
      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);

      final Offset blank = _starBlankPoint(tester, layout);
      await tester.tapAt(blank);
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '点歪是常态 —— 不该因为点空白就把抽屉收掉',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('4K 窗口：画布照旧降采样，行星照样点得中（C-33）', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final LoadedPack pack = starPack();
      const Size window = Size(3840, 2160);
      await _pumpScreen(tester, pack: pack);
      final String rootId = await _enterStarSystem(
        tester,
        pack,
        window: window,
      );
      final StarSystemLayout layout = _starSystemOf(
        tester,
        pack,
        rootId,
        window: window,
      );

      await tester.tapAt(layout.planets.first.center * _pointScaleOf(tester));
      await tester.pump();

      expect(
        find.byKey(hudDetailDrawerKey),
        findsOneWidget,
        reason: '降采样时画布比窗口小 —— 坐标不乘 `scale` 就整体偏左上',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Z4 恒星特写（SPEC-VIEW-040 · V-1f 后半）', () {
    /// 与 `Z3` 那组同一份链 —— `Z4` 是它的推近，两档必须看同一个对象。
    LoadedPack closeupPack() => fixturePack(
      const <FixtureItem>[
        FixtureItem('a', '甲'),
        FixtureItem('b', '乙'),
        FixtureItem('c', '丙'),
      ],
      edges: const <List<String>>[
        <String>['a', 'b'],
        <String>['b', 'c'],
      ],
    );

    /// 走到 `Z4`：`Z1` 点域点 → `Z2` 点亮结 → `Z3` → 点第一颗行星。
    Future<StarPlanet> enterCloseup(
      WidgetTester tester,
      LoadedPack pack,
    ) async {
      final String rootId = await _enterStarSystem(tester, pack);
      final StarSystemLayout system = _starSystemOf(tester, pack, rootId);
      final StarPlanet planet = system.planets.first;
      await tester.tapAt(planet.center * _pointScaleOf(tester));
      await tester.pump();
      return planet;
    }

    testWidgets('从 Z3 点行星进 Z4，画的是恒星特写而不是项投影（SPEC-VIEW-040）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = closeupPack();
      await _pumpScreen(tester, pack: pack);
      await enterCloseup(tester, pack);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is StarCloseupPainter,
        ),
        findsOneWidget,
        reason: 'VIEW-040：Z4 是一颗恒星的特写 + 最内 1–2 条轨道',
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is FramePainter,
        ),
        findsNothing,
        reason: '项投影与恒星特写不能并存 —— 并存时哪一套在上层是运气',
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is CustomPaint && widget.painter is StarPainter,
        ),
        findsNothing,
        reason: 'Z3 的恒星系也已不在画面里 —— 这一档只有特写',
      );

      final StarCloseupLayout layout = _starCloseupOf(tester);
      expect(layout.itemId, 'b', reason: '特写的是刚点的那颗行星（b），不是恒星');
      expect(
        layout.starRadius,
        greaterThan(_halfOf(tester) * stellarRadiusRatio * 5),
        reason: 'Z4 的恒星比 Z3 大一个量级 —— 否则「推近」看不出来',
      );
      expect(_crumbCount(tester), _crumbsFor(ZoomLevel.z4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z4 不是「又一档星图」：只露最内两条轨道（SPEC-VIEW-040）', (
      WidgetTester tester,
    ) async {
      // 五项链 ⇒ `Z3` 画四条轨道，`Z4` 只该露两条。
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲'),
          FixtureItem('b', '乙'),
          FixtureItem('c', '丙'),
          FixtureItem('d', '丁'),
          FixtureItem('e', '戊'),
        ],
        edges: const <List<String>>[
          <String>['a', 'b'],
          <String>['b', 'c'],
          <String>['c', 'd'],
          <String>['d', 'e'],
        ],
      );
      await _pumpScreen(tester, pack: pack);
      await enterCloseup(tester, pack);

      final StarCloseupLayout layout = _starCloseupOf(tester);
      expect(
        layout.orbits.length,
        closeupMaxOrbits,
        reason: 'VIEW-040 的边界：「只露能放进画面边缘的 1–2 条」',
      );
      expect(
        layout.orbits.map((StarOrbit each) => each.level).toList(),
        <int>[1, 2],
        reason: '露的是**最内**两条，不是随便两条',
      );
      expect(
        find.byKey(starLabelKey(layout.itemId)),
        findsNothing,
        reason: '这一档不标名 —— 面包屑末段已经是这一项，邻域只靠抽屉文字',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Z4 画布不响应点击：可点对象是「—」（SPEC-VIEW-001）', (
      WidgetTester tester,
    ) async {
      final LoadedPack pack = closeupPack();
      await _pumpScreen(tester, pack: pack);
      final StarPlanet planet = await enterCloseup(tester, pack);
      final StarCloseupLayout layout = _starCloseupOf(tester);

      // 点恒星中心、点空白、再点一次行星该在的位置 —— 三处都不该有反应。
      final Size size = tester.getSize(find.byType(UniverseScreen));
      for (final Offset point in <Offset>[
        layout.starCenter * _pointScaleOf(tester),
        Offset(size.width - 40, 90),
        planet.center * _pointScaleOf(tester),
      ]) {
        await tester.tapAt(point);
        await tester.pump();
      }

      expect(
        _crumbCount(tester),
        _crumbsFor(ZoomLevel.z4),
        reason: 'VIEW-001 的 Z4 行：可点对象「—」，点画布不产生任何跳转',
      );
      expect(
        find.descendant(
          of: find.byKey(detailPanelKey),
          matching: find.text('乙'),
        ),
        findsWidgets,
        reason: '选中项仍是那颗行星 —— 点画布既不该换项，也不该关抽屉',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// `Z0` 用例里的第二个空间：**60 项**而不是 [_goPack] 的 1 项。
///
/// 项数比要留在真实量级（三个真实包是 150 / 80 / 80，比值 1.875）。拿 1 项的
/// 空间去画星系，`C-53` 反解出的 `k` 下限（`40 / √1`）会直接把这一档判成退化
/// —— 那不是要验的东西，是夹具挑错了形状。
LoadedPack _z0Space() => fixturePack(
  <FixtureItem>[
    for (int i = 0; i < 60; i++)
      FixtureItem('go-$i', 'Go 第 $i 项', domainId: 'go/d${i % 4}'),
  ],
  spaceId: 'go',
  spaceName: 'Go 语言',
);

/// 画布坐标 → 窗口坐标的倍数。降采样时画布比窗口小，不乘它整体偏左上。
double _pointScaleOf(WidgetTester tester, {Size? window}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  return planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  ).scale;
}

/// 从 `Z1` 经 `Z2` 点亮结进 `Z3`，返回进去的那棵子树的根 id。
///
/// 走**真实入口**而不是直接 `pumpWidget(initialZoom: z3)`：后者 `_selectedItemId`
/// 是 `null`，`Z3` 拿不到恒星 ⇒ 退回项投影 —— 那样测的就不是 `VIEW-039` 了。
/// 这条路径也正是 `V-1d` 建好的那条（`_jumpToKnot()`）。
Future<String> _enterStarSystem(
  WidgetTester tester,
  LoadedPack pack, {
  Size? window,
}) async {
  await _enterDomain(tester, pack, window: window);
  await tester.pump();

  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  final NebulaLayout nebula = layoutNebula(
    pack: pack,
    domainId: pack.space.domainIds.first,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
  // 非单项子树才会进 `Z3`（单项由 `VIEW-038` 直接送 `Z4`）。
  final NebulaKnot knot = nebula.knots.firstWhere(
    (NebulaKnot each) => !each.isSingle,
  );
  await tester.tapAt(knot.center * plan.scale);
  await tester.pump();
  return knot.rootId;
}

/// 重算 `Z3` 的恒星系布局 —— 与 `_domainPoint` / `_nebulaItemPoint` 同一个做法：
/// `layoutStarSystem` 是纯函数，入参与画布一致，两边各算一次、算错就会红。
StarSystemLayout _starSystemOf(
  WidgetTester tester,
  LoadedPack pack,
  String rootId, {
  Size? window,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    size.width,
    size.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  return layoutStarSystem(
    pack: pack,
    rootId: rootId,
    viewport: Size(plan.surfaceWidth, plan.surfaceHeight),
  );
}

/// `Z3` 里一个「点不中任何东西」的窗口坐标 —— 既不在行星的 12 px 命中圈里，
/// 也不在恒星的命中圈里，且避开了右侧 ④ 详情抽屉。
Offset _starBlankPoint(
  WidgetTester tester,
  StarSystemLayout layout, {
  Size? window,
}) {
  final Size size = window ?? tester.getSize(find.byType(UniverseScreen));
  final double scale = _pointScaleOf(tester, window: window);
  for (double y = 160; y < size.height - 160; y += 13) {
    for (double x = 40; x < size.width - 420; x += 13) {
      final Offset canvas = Offset(x / scale, y / scale);
      if (pickStarPlanetAt(layout: layout, point: canvas) != null) {
        continue;
      }
      if (hitsStarAt(layout: layout, point: canvas)) {
        continue;
      }
      return Offset(x, y);
    }
  }
  throw StateError('扫不出空白点 —— 夹具或视口变了，这条用例需要重挑窗口');
}

/// 取 `Z4` 画布上的特写布局。
///
/// **直接读 painter，不重算**：这一档的入参里有 `visibleIds`（筛选结果），从屏幕
/// 外面重算一次要么漏传、要么传错，两种都会把「画的和算的不一致」藏起来 —— 而
/// 本组要验的正是「画出来的是不是特写」。
StarCloseupLayout _starCloseupOf(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint && widget.painter is StarCloseupPainter,
    ),
  );
  return (paint.painter! as StarCloseupPainter).layout;
}

/// 画布短边的一半（画布坐标）—— `Z4` 的恒星半径按它算。
double _halfOf(WidgetTester tester) {
  final Size window = tester.getSize(find.byType(UniverseScreen));
  final ViewportPlan plan = planViewport(
    window.width,
    window.height,
    devicePixelRatio: tester.view.devicePixelRatio,
  );
  return math.min(plan.surfaceWidth, plan.surfaceHeight) / 2;
}
