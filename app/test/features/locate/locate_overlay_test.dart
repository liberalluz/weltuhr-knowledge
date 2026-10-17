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
    String? spacePrefix,
    VoidCallback? onDismiss,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: LocateOverlay(
              pack: withPack ? (packOverride ?? pack) : null,
              spacePrefix: spacePrefix,
              domainId: domainId,
              onPick: onPick,
              onPickNear: onPickNear ?? (String _) {},
              onDismiss: onDismiss ?? () {},
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

    final LocateResult result = Locator(pack).locate('装饰器');
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

    final LocateResult result = Locator(pack).locate('抽象');
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

    final LocateResult result = Locator(pack).locate('计算机科学');
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

  testWidgets('多空间才带前缀，单空间不重复写空间名（SPEC-VIEW-033）', (WidgetTester tester) async {
    await pump(tester, onPick: (_, _) {}, spacePrefix: 'Python');
    await type(tester, '装饰器');
    final LocateHit hit = Locator(pack).locate('装饰器').hits.first;
    expect(
      find.descendant(
        of: find.byKey(locateRowKey(hit)),
        matching: find.text('Python › 装饰器'),
      ),
      findsOneWidget,
    );

    await pump(tester, onPick: (_, _) {});
    await type(tester, '装饰器');
    expect(
      find.descendant(
        of: find.byKey(locateRowKey(hit)),
        matching: find.text('装饰器'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(' › '), findsNothing, reason: '单空间不该有前缀分隔符');
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
}
