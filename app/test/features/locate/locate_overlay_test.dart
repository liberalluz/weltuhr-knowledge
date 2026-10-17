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

void main() {
  late LoadedPack pack;

  setUpAll(() {
    pack = loadAlphaPack();
  });

  Future<void> pump(
    WidgetTester tester, {
    required void Function(LocateResult, LocateHit) onPick,
    bool withPack = true,
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
              pack: withPack ? pack : null,
              spacePrefix: spacePrefix,
              onPick: onPick,
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

  testWidgets('无命中只说没有，不出现新增入口（SPEC-VIEW-030）', (WidgetTester tester) async {
    await pump(tester, onPick: (_, _) {});
    await type(tester, '这个词包里一定没有');

    expect(find.byKey(locateResultsKey), findsNothing);
    final String hint = tester.widget<Text>(find.textContaining('没有命中')).data!;
    expect(hint.contains('新增'), isFalse, reason: '新增入口不能挂在「搜不到」上');
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
}
