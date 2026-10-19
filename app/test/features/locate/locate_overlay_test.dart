/// 定位浮层的显示与选择（`SPEC-VIEW-024` / `026` / `027` / `028` / `033`）。
///
/// 这里**不验跳转**：浮层不认识档位与筛选，它只把「用户选了哪一条」交出去。
/// 「选了之后世界怎么变」在 `universe_screen_test.dart` 里验 —— 分成两处，
/// 是因为它们失败时的含义完全不同（一处是列错了，一处是跳错了）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

void main() {
  late LoadedPack pack;

  setUpAll(() {
    pack = loadAlphaPack();
  });

  Future<void> pump(
    WidgetTester tester, {
    required void Function(LocateResult, LocateHit) onPick,
    void Function(String itemId)? onPickNear,
    bool withPack = true,
    String? domainId,
    LoadedPack? packOverride,
    List<LoadedPack> otherSpaces = const <LoadedPack>[],
    String? scopeSpaceId,
    VoidCallback? onDismiss,
    void Function(LocateResult result)? onPlanHere,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: LocateOverlay(
              pack: withPack ? (packOverride ?? pack) : null,
              otherSpaces: otherSpaces,
              scopeSpaceId: scopeSpaceId,
              domainId: domainId,
              onPick: onPick,
              onPickNear: onPickNear ?? (String _) {},
              onDismiss: onDismiss ?? () {},
              onPlanHere: onPlanHere,
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

    final LocateResult result = Locator.single(pack).locate('装饰器');
    expect(result.state, LocateState.located, reason: '前提：α 包里这是唯一精确命中');

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
    // 「抽象」在 α 包里既是能力轴的取值，又是某标题的子串 ⇒ 多条命中。
    await type(tester, '抽象');

    final LocateResult result = Locator.single(pack).locate('抽象');
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
    await type(tester, '计算机科学');

    final LocateResult result = Locator.single(pack).locate('计算机科学');
    expect(result.hits.first.kind, LocateKind.axis, reason: '前提：α 包里这是轴值');

    final Finder row = find.byKey(locateRowKey(result.hits.first));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('轴值')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('筛选')),
      findsOneWidget,
      reason: '同一行还要说清按下去的效果是筛选',
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
    final LoadedPack here = fixturePack(
      const <FixtureItem>[FixtureItem('p1', '装饰器')],
      spaceId: 'python',
      spaceName: 'Python',
    );
    final LoadedPack there = fixturePack(
      const <FixtureItem>[FixtureItem('g1', '装饰器')],
      spaceId: 'go',
      spaceName: 'Go',
    );

    // 只有本空间：一条命中，不写前缀 —— 每行都写一遍同样的空间名是噪音。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      scopeSpaceId: 'python',
    );
    await type(tester, '装饰器');
    final LocateHit only = Locator.single(here).locate('装饰器').hits.first;
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
      otherSpaces: <LoadedPack>[there],
      scopeSpaceId: 'python',
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
    final LoadedPack here = fixturePack(
      const <FixtureItem>[FixtureItem('p1', '装饰器')],
      spaceId: 'python',
      spaceName: 'Python',
    );
    final LoadedPack there = fixturePack(
      const <FixtureItem>[FixtureItem('g1', '闭包')],
      spaceId: 'go',
      spaceName: 'Go',
    );

    // 窄作用域 + 还有别的空间 ⇒ 给。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      otherSpaces: <LoadedPack>[there],
      scopeSpaceId: 'python',
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
      otherSpaces: <LoadedPack>[there],
    );
    await type(tester, '闭包');
    expect(find.byKey(locateSearchAllKey), findsNothing);

    // 只有一个空间 ⇒ 不给：按下去什么也不会变的按钮比没有更糟。
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: here,
      scopeSpaceId: 'python',
    );
    await type(tester, '闭包');
    expect(find.byKey(locateSearchAllKey), findsNothing);
  });

  testWidgets('跨空间的命中照样交给 onPick，且带着它自己的空间（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    final LoadedPack here = fixturePack(
      const <FixtureItem>[FixtureItem('p1', '装饰器')],
      spaceId: 'python',
      spaceName: 'Python',
    );
    final LoadedPack there = fixturePack(
      const <FixtureItem>[FixtureItem('g1', '闭包')],
      spaceId: 'go',
      spaceName: 'Go',
    );

    LocateHit? picked;
    await pump(
      tester,
      onPick: (_, LocateHit hit) => picked = hit,
      packOverride: here,
      otherSpaces: <LoadedPack>[there],
    );
    await type(tester, '闭包');
    final LocateHit foreign = Locator.single(there).locate('闭包').hits.first;
    await tester.tap(find.byKey(locateRowKey(foreign)));
    await tester.pump();

    expect(
      picked,
      isNotNull,
      reason: '多根之后拦下来就成了「搜得到却点不动」—— 换根是屏幕层的事',
    );
    expect(picked!.spaceId, 'go', reason: '命中带着空间，调用方才换得对根');
    expect(picked!.target, 'g1');
    expect(
      find.byKey(locateNoticeKey),
      findsNothing,
      reason: '能跳就不该给一句「做不到」',
    );
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
    expect(find.byKey(locateNearRowKey('python/fn-decorator')), findsOneWidget);

    await tester.tap(find.byKey(locateNearRowKey('python/fn-decorator')));
    await tester.pump();
    expect(nearId, 'python/fn-decorator');
  });

  testWidgets('类 ②「都不对」：有域上下文才展开表单，标题预填输入（SPEC-VIEW-030）', (
    WidgetTester tester,
  ) async {
    await pump(tester, onPick: (_, _) {}, domainId: 'python/func');
    await type(tester, '装饰器参数');
    await tester.tap(find.byKey(locateTriageActionKey));
    await tester.pump();

    expect(find.byKey(locateFormKey), findsOneWidget);
    expect(find.textContaining('python/func'), findsOneWidget);
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
    await pump(tester, onPick: (_, _) {}, domainId: 'python/func');
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
    final LoadedPack fixed = fixturePack(const <FixtureItem>[
      FixtureItem('python/fn-metaclass', '元类', inScope: false),
      FixtureItem('python/lex-keyword', '关键字'),
    ]);
    await pump(tester, onPick: (_, _) {}, packOverride: fixed);
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
    final LoadedPack fixed = fixturePack(const <FixtureItem>[
      FixtureItem('python/async', '协程'),
    ]);
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: fixed,
      onPlanHere: (LocateResult result) => handed = result,
    );
    await type(tester, '协程');

    expect(find.byKey(locatePlanHereKey), findsOneWidget);
    await tester.tap(find.byKey(locatePlanHereKey));
    expect(
      handed?.query,
      '协程',
      reason: '交出去的是整次定位结果 —— 范围由查询词唯一确定，与点了哪一行无关',
    );
  });

  testWidgets('TC-PLAN-077 只命中筛选类 ⇒ 不给「按此范围建计划」（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    final LoadedPack fixed = fixturePack(const <FixtureItem>[
      FixtureItem('python/async', '协程', ability: '基础语法'),
    ]);
    await pump(
      tester,
      onPick: (_, _) {},
      packOverride: fixed,
      onPlanHere: (LocateResult _) {},
    );
    await type(tester, '基础语法');

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
    final LoadedPack fixed = fixturePack(const <FixtureItem>[
      FixtureItem('python/async', '协程'),
    ]);
    await pump(tester, onPick: (_, _) {}, packOverride: fixed);
    await type(tester, '协程');

    expect(find.byKey(locateResultsKey), findsOneWidget);
    expect(
      find.byKey(locatePlanHereKey),
      findsNothing,
      reason: '按下没反应的按钮比没有这个按钮更糟',
    );
  });
}
