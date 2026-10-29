/// 定位浮层的显示与选择（`SPEC-VIEW-024` / `026` / `027` / `028` / `033`）。
///
/// 这里**不验跳转**：浮层不认识档位与筛选，它只把「用户选了哪一条」交出去。
/// 「选了之后世界怎么变」在 `universe_screen_test.dart` 里验 —— 分成两处，
/// 是因为它们失败时的含义完全不同（一处是列错了，一处是跳错了）。
///
/// ## 笔 5c：整份改用自己的小包
///
/// 旧版靠 `loadAlphaPack()`（`support/alpha_pack.dart`，已随 `pack_parse.dart` 删除）。
/// 新本体下「圈内」是**派生值**（`ADR-0007` 决策 2）：没有 `inScope` 字段可填，
/// 要造圈外项就得把它的父挂到 `subtreeRoot` 之外 —— 见 [_outside]。
///
/// 档位也变了：`system` / `planet` 这些骨架槽位取代了旧的「门类 / 类 / 中类」
/// 标签，`locateKindOf` 只把 `group`/`galaxy`/`cluster` 读成域、`planet` 读成项。
/// 所以这里只造 `system`（子树根，自己不参与落点）与 `planet`（项）两种。
library;

// `Axis` 两边都有（Flutter 的绘制轴 / `core/enums.dart` 的知识轴），这里要后者。
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';

import '../../support/pack_fixture.dart';

/// 子树根：所有**圈内**的项都挂在它下面。
///
/// 它自己是个 `system` 槽位的结构节点 —— `locateKindOf` 对它返回 `null`，
/// 所以「子树根」不会作为落点出现在结果列表里（它是容器，不是内容）。
const String _root = 'py/fn';

/// 另一颗在子树之外的容器：用它挂「圈外项」。
///
/// `inScopeOf` 判的是「是不是 [subtreeRoot] 自己或它的后裔」，父挂在别人
/// 名下就自然落在圈外 —— 不需要、也没有 `inScope: false` 这种字段可填。
const String _outside = 'py/other';

void main() {
  late PackContent pack;

  setUpAll(() {
    pack = _basePack();
  });

  /// 与浮层内部同口径地定位。
  ///
  /// **不直接 `Locator.single(pack)`**：那样 `subtreeRoot` 为 `null`，每条命中
  /// 都算圈内 —— 拿它去算 `hit` 再找 `Key`，在「圈外项」的用例里会算出浮层
  /// 根本不会渲染的那一条（假红/假绿都由此而来）。
  LocateResult locateIn(
    PackContent target,
    String query, {
    String? subtreeRoot = _root,
  }) => Locator(<PackContent>[target], subtreeRoot: subtreeRoot).locate(query);

  Future<void> pump(
    WidgetTester tester, {
    required void Function(LocateResult, LocateHit) onPick,
    void Function(String nodeId)? onPickNear,
    bool withPack = true,
    String? domainId,
    PackContent? packOverride,
    List<PackContent> otherPacks = const <PackContent>[],
    String? scopePluginId,
    VoidCallback? onDismiss,
    void Function(LocateResult result)? onPlanHere,
    void Function(Axis axis)? onPickAxis,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: LocateOverlay(
              pack: withPack ? (packOverride ?? pack) : null,
              subtreeRoot: _root,
              otherPacks: otherPacks,
              scopePluginId: scopePluginId,
              domainId: domainId,
              onPick: onPick,
              onPickNear: onPickNear ?? (String _) {},
              onDismiss: onDismiss ?? () {},
              onPlanHere: onPlanHere,
              onPickAxis: onPickAxis,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(locateFieldKey), text);
    await tester.pump();
  }

  testWidgets('打开即有一段说明，不空着（SPEC-VIEW-024）', (WidgetTester tester) async {
    await pump(tester, onPick: (_, _) {});
    expect(find.byKey(locateOverlayKey), findsOneWidget);
    expect(find.byKey(locateHintKey), findsOneWidget);
    expect(find.byKey(locateResultsKey), findsNothing);
  });

  testWidgets('完整标题 ⇒ 唯一命中，给一行「回车直接定位」（SPEC-VIEW-027）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '装饰器');

    final LocateResult result = locateIn(pack, '装饰器');
    expect(result.state, LocateState.located, reason: '前提：这个包里它是唯一精确命中');

    expect(find.textContaining('唯一命中'), findsOneWidget);
    expect(find.byKey(locateRowKey(result.hits.first)), findsOneWidget);
  });

  testWidgets('回车把最强的那条交出去（SPEC-VIEW-027）', (WidgetTester tester) async {
    LocateHit? picked;
    await pump(tester, onPick: (_, LocateHit hit) => picked = hit);
    await type(tester, '装饰器');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.label, '装饰器');
    expect(picked!.kind, LocateKind.item);
  });

  testWidgets('点结果行交出去的是该行，不是第一条（SPEC-VIEW-029）', (WidgetTester tester) async {
    LocateHit? picked;
    await pump(tester, onPick: (_, LocateHit hit) => picked = hit);
    // 「抽象」既是某一项的完整标题，又是另一项标题的前缀 ⇒ 多条命中。
    await type(tester, '抽象');

    final LocateResult result = locateIn(pack, '抽象');
    expect(result.hits.length, greaterThan(1), reason: '前提：这句输入给多条命中');

    final LocateHit second = result.hits[1];
    await tester.tap(find.byKey(locateRowKey(second)));
    await tester.pump();
    expect(picked?.target, second.target);
  });

  testWidgets('轴取值命中带「轴值」徽标，跟落点类长得不一样（SPEC-VIEW-028）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    // 三轴的标签固定（`axisLabels`）：`major` = 「专业」。
    await type(tester, '专业');

    final LocateResult result = locateIn(pack, '专业');
    expect(result.hits.first.kind, LocateKind.axis, reason: '前提：「专业」是轴值');

    final Finder row = find.byKey(locateRowKey(result.hits.first));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('轴值')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('筛选')),
      findsOneWidget,
      reason: '同一行还要说清按下去的效果是筛选',
    );
  });

  testWidgets('TC-TREE-067 轴命中行给「按此轴看」，点了交出那条轴（SPEC-TREE-010）', (
    WidgetTester tester,
  ) async {
    Axis? picked;
    await pump(
      tester,
      onPick: (_, _) {},
      onPickAxis: (Axis axis) => picked = axis,
    );
    await type(tester, '专业');

    expect(
      find.byKey(locateAxisHereKey(Axis.major.name)),
      findsOneWidget,
      reason: '轴落点没有界面入口，用户在浮层里就没有「按这条轴去看」这条路',
    );
    // 一条行上两个动作各自可达：整行是筛选（`VIEW-028`），按钮是换根。
    expect(find.text('筛选'), findsOneWidget);

    await tester.tap(find.byKey(locateAxisHereKey(Axis.major.name)));
    await tester.pump();
    expect(picked, Axis.major, reason: '交出去的是那条轴，不是「命中了」这件事');
  });

  testWidgets('TC-TREE-068 没有上层接收 ⇒ 不渲染「按此轴看」（SPEC-TREE-010）', (
    WidgetTester tester,
  ) async {
    // 不传 `onPickAxis`：按下去没人接，按钮就不该出现（与 `TC-PLAN-078` 同口径）。
    await pump(tester, onPick: (_, _) {});
    await type(tester, '专业');

    expect(find.byKey(locateAxisHereKey(Axis.major.name)), findsNothing);
    expect(
      find.text('筛选'),
      findsOneWidget,
      reason: '没有换根入口时，这一行仍是可用的筛选入口 —— 不能连它一起消失',
    );
  });

  testWidgets('Esc 关闭浮层（SPEC-VIEW-026）', (WidgetTester tester) async {
    int dismissed = 0;
    await pump(tester, onPick: (_, _) {}, onDismiss: () => dismissed += 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('无命中先给分诊，不直接给新增入口（SPEC-VIEW-030）', (WidgetTester tester) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '虚拟环境');

    expect(find.byKey(locateResultsKey), findsNothing, reason: '没有命中就不该有结果列表');
    expect(
      find.byKey(locateTriageKey),
      findsOneWidget,
      reason: '「没有」不是一种状态，是四类',
    );
    expect(
      find.text('新增这一项'),
      findsNothing,
      reason: '①不知道往哪个域放（无域上下文）②还没有候选可给 —— 两样都没有就只剩需求信号',
    );
    expect(find.byKey(locateFormKey), findsNothing);
  });

  testWidgets('同名跨空间才写前缀，单空间不重复写空间名（SPEC-VIEW-033）', (
    WidgetTester tester,
  ) async {
    final PackContent here = _toyPack(
      pluginId: 'python',
      packName: 'Python',
      itemId: 'py/decorator',
      itemName: '装饰器',
    );
    final PackContent there = _toyPack(
      pluginId: 'go',
      packName: 'Go',
      itemId: 'go/decorator',
      itemName: '装饰器',
    );

    // 只有本空间：一条命中，不写前缀 —— 每行都写一遍同样的空间名是噪音。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      scopePluginId: 'python',
    );
    await type(tester, '装饰器');
    final LocateHit only = locateIn(here, '装饰器').hits.first;
    expect(
      find.descendant(
        of: find.byKey(locateRowKey(only)),
        matching: find.text('装饰器'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(locateSpaceSeparator),
      findsNothing,
      reason: '单空间不该有前缀分隔符',
    );

    // 放宽到全部空间：两个空间各有同名项 ⇒ 两条都带各自的空间名。
    // 判据取自命中集本身，不由调用方注入「该不该写」。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      otherPacks: <PackContent>[there],
      scopePluginId: 'python',
    );
    await type(tester, '装饰器');
    await tester.tap(find.byKey(locateSearchAllKey));
    await tester.pump();
    expect(find.text('Python$locateSpaceSeparator装饰器'), findsOneWidget);
    expect(find.text('Go$locateSpaceSeparator装饰器'), findsOneWidget);
  });

  testWidgets('窄作用域才给「在全部空间中搜索」，Z0 与单空间都不给（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    final PackContent here = _toyPack(
      pluginId: 'python',
      packName: 'Python',
      itemId: 'py/decorator',
      itemName: '装饰器',
    );
    final PackContent there = _toyPack(
      pluginId: 'go',
      packName: 'Go',
      itemId: 'go/closure',
      itemName: '闭包',
    );

    // 窄作用域 + 还有别的空间 ⇒ 给。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      otherPacks: <PackContent>[there],
      scopePluginId: 'python',
    );
    await type(tester, '装饰器');
    expect(find.byKey(locateSearchAllKey), findsOneWidget);

    // 本空间没有命中时也要给 —— 那一刻它比「新增」更值得先给。
    await type(tester, '闭包');
    expect(find.byKey(locateTriageKey), findsOneWidget);
    expect(
      find.byKey(locateSearchAllKey),
      findsOneWidget,
      reason: '本空间搜不到时，正是最该放宽作用域的时刻',
    );

    // Z0（作用域为 null）本来就是全部空间 ⇒ 不给。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      otherPacks: <PackContent>[there],
    );
    await type(tester, '闭包');
    expect(find.byKey(locateSearchAllKey), findsNothing);

    // 只有一个空间 ⇒ 不给：按下去什么也不会变的按钮比没有更糟。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      scopePluginId: 'python',
    );
    await type(tester, '闭包');
    expect(find.byKey(locateSearchAllKey), findsNothing);
  });

  testWidgets('跨空间的命中照样交给 onPick，且带着它自己的包（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    final PackContent here = _toyPack(
      pluginId: 'python',
      packName: 'Python',
      itemId: 'py/decorator',
      itemName: '装饰器',
    );
    final PackContent there = _toyPack(
      pluginId: 'go',
      packName: 'Go',
      itemId: 'go/closure',
      itemName: '闭包',
    );

    LocateHit? picked;
    await pump(
      tester,
      onPick: (_, LocateHit hit) => picked = hit,
      packOverride: here,
      otherPacks: <PackContent>[there],
    );
    await type(tester, '闭包');
    // 多包时浮层把圈定根置空（别的包的树根不可能在这个子树下），这里同口径。
    final LocateHit foreign = locateIn(
      there,
      '闭包',
      subtreeRoot: null,
    ).hits.first;
    await tester.tap(find.byKey(locateRowKey(foreign)));
    await tester.pump();

    expect(picked, isNotNull, reason: '多根之后拦下来就成了「搜得到却点不动」—— 换根是屏幕层的事');
    expect(picked!.packId, 'go', reason: '命中带着包 id，调用方才换得对根');
    expect(picked!.target, 'go/closure');
    expect(find.byKey(locateNoticeKey), findsNothing, reason: '能跳就不该给一句「做不到」');
  });

  testWidgets('没有内容包时浮层照样打开并说明原因（SPEC-FND-014）', (WidgetTester tester) async {
    await pump(tester, onPick: (_, _) {}, withPack: false);
    expect(find.byKey(locateHintKey), findsOneWidget);
    expect(find.textContaining('没有内容包'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('类 ④ 无域上下文：只给「记下这个需求」，按下如实说没落库（SPEC-VIEW-030）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '虚拟环境');

    expect(find.text('记下这个需求'), findsOneWidget);
    expect(find.textContaining('不承诺'), findsOneWidget);

    await tester.tap(find.byKey(locateTriageActionKey));
    await tester.pump();
    expect(find.byKey(locateNoticeKey), findsOneWidget);
    expect(
      find.textContaining('没有写入任何数据'),
      findsOneWidget,
      reason: '审核队列在 B4 才接入 —— 不能把没写成的说成已提交',
    );
  });

  testWidgets('类 ②：先给邻近候选，点候选就走落点（SPEC-VIEW-030）', (WidgetTester tester) async {
    String? nearId;
    await pump(
      tester,
      onPick: (_, _) {},
      onPickNear: (String id) => nearId = id,
    );
    await type(tester, '装饰器参数');

    expect(find.text('都不对'), findsOneWidget);
    expect(
      find.text('新增这一项'),
      findsNothing,
      reason: '新增入口只能挂在「已给过候选且用户说都不对」之后',
    );
    expect(find.byKey(locateNearRowKey('py/fn-decorator')), findsOneWidget);

    await tester.tap(find.byKey(locateNearRowKey('py/fn-decorator')));
    await tester.pump();
    expect(nearId, 'py/fn-decorator');
  });

  testWidgets('类 ②「都不对」：有域上下文才展开表单，标题预填输入（SPEC-VIEW-030）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {}, domainId: _root);
    await type(tester, '装饰器参数');
    await tester.tap(find.byKey(locateTriageActionKey));
    await tester.pump();

    expect(find.byKey(locateFormKey), findsOneWidget);
    expect(find.textContaining(_root), findsOneWidget);
    final TextField title = tester.widget<TextField>(
      find.byKey(locateFormTitleKey),
    );
    expect(title.controller?.text, '装饰器参数', reason: '预填用户刚才打的词');
  });

  testWidgets('没有域上下文时「都不对」不给表单，只记需求（SPEC-VIEW-030）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '装饰器参数');
    await tester.tap(find.byKey(locateTriageActionKey));
    await tester.pump();

    expect(find.byKey(locateFormKey), findsNothing, reason: '表单第一格就得说放哪个域');
    expect(find.byKey(locateNoticeKey), findsOneWidget);
  });

  testWidgets('表单是死的一次性查询：填它不改外层输入、提交也不留筛选（SPEC-VIEW-032）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {}, domainId: _root);
    await type(tester, '虚拟环境');
    expect(find.text('新增这一项'), findsOneWidget);

    await tester.tap(find.byKey(locateTriageActionKey));
    await tester.pump();
    await tester.enterText(find.byKey(locateFormTitleKey), '虚拟环境与 venv');
    await tester.pump();

    final TextField field = tester.widget<TextField>(
      find.byKey(locateFieldKey),
    );
    expect(field.controller?.text, '虚拟环境', reason: '表单是另一次查询，不回头改搜索词');

    await tester.tap(find.byKey(locateFormSubmitKey));
    await tester.pump();
    expect(find.byKey(locateNoticeKey), findsOneWidget);
    expect(find.textContaining('没有写入任何数据'), findsOneWidget);
  });

  testWidgets('类 ①：圈外项不列成结果，只给「申请纳入」（SPEC-VIEW-030）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '元类');

    expect(find.byKey(locateResultsKey), findsNothing);
    expect(find.textContaining('唯一命中'), findsNothing, reason: '圈外项跳过去是一片空白');
    expect(find.textContaining('都不在圈内'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(locateTriageKey),
        matching: find.text('元类'),
      ),
      findsOneWidget,
      reason: '要说清是哪一项在圈外 —— 只写「圈外」用户不知道它到底存不存在',
    );
    expect(find.text('申请纳入'), findsOneWidget);
  });

  testWidgets('TC-PLAN-076 有落点类命中 ⇒ 底部「按此范围建计划」（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    LocateResult? handed;
    await pump(
      tester,
      onPick: (_, _) {},
      onPlanHere: (LocateResult result) => handed = result,
    );
    await type(tester, '协程');

    expect(find.byKey(locatePlanHereKey), findsOneWidget);
    await tester.tap(find.byKey(locatePlanHereKey));
    expect(handed?.query, '协程', reason: '交出去的是整次定位结果 —— 范围由查询词唯一确定，与点了哪一行无关');
  });

  testWidgets('TC-PLAN-077 只命中筛选类 ⇒ 不给「按此范围建计划」（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {}, onPlanHere: (LocateResult _) {});
    await type(tester, '专业');

    expect(
      find.byKey(locateResultsKey),
      findsOneWidget,
      reason: '轴命中照旧列出来（它是筛选入口），只是不能拿来圈范围',
    );
    expect(
      find.byKey(locatePlanHereKey),
      findsNothing,
      reason: '轴值不是范围，按它圈不出任何项 —— 那会是一份 0 项的计划',
    );
  });

  testWidgets('TC-PLAN-078 没有上层接收 ⇒ 不渲染这个入口（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '协程');

    expect(find.byKey(locateResultsKey), findsOneWidget);
    expect(
      find.byKey(locatePlanHereKey),
      findsNothing,
      reason: '按下没反应的按钮比没有这个按钮更糟',
    );
  });
}

/// 基础包：一个子树根、一个子树外的容器、以及几颗可学的项。
///
/// 「元类」的父是 [_outside] ⇒ 在库里、也对得上，但不在圈内（类 ① 的素材）。
PackContent _basePack() => fixturePack(
  const <FixtureNode>[
    FixtureNode(_root, '函数', slot: LevelSlot.system),
    FixtureNode(_outside, '别处', slot: LevelSlot.system),
    FixtureNode('py/fn-decorator', '装饰器', parentId: _root),
    FixtureNode('py/fn-metaclass', '元类', parentId: _outside),
    FixtureNode('py/lex-keyword', '关键字', parentId: _root),
    FixtureNode('py/abst', '抽象', parentId: _root),
    FixtureNode('py/abst-class', '抽象类', parentId: _root),
    FixtureNode('py/async', '协程', parentId: _root),
  ],
  pluginId: 'python',
  packName: 'Python 语法分层',
);

/// 只有一个根 + 一个项的小包，用来造「两个空间各有一处同名项」。
///
/// 根 id 固定成 [_root]：单包搜索时浮层会拿它判圈内，包内根若另起 id，
/// 这里造出来的项会一律被判成圈外，于是「同名前缀」用例会红在毫不相干的地方。
PackContent _toyPack({
  required String pluginId,
  required String packName,
  required String itemId,
  required String itemName,
}) => fixturePack(
  <FixtureNode>[
    FixtureNode(_root, '$packName 根', slot: LevelSlot.system),
    FixtureNode(itemId, itemName, parentId: _root),
  ],
  pluginId: pluginId,
  packName: packName,
);
