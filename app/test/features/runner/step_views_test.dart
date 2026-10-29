/// 「读」步的正文渲染（`SPEC-STEP-012`：读 = 滚动文本 + 「读完了」）。
///
/// 这一支测的是**正文从哪来**：正文取 `entry.body`，缺失退回 `entry.summary`，
/// 两者皆空就只留指令。包内英语 / 德语 80 项都没有 `entries`，所以第三态不是
/// 边角情形 —— 它是那两个包里每一次「读」的样子。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/features/runner/step_views.dart';

const EntryStep _readStep = EntryStep(
  operator: ExecutionOperator.read,
  instruction: '读一遍',
);

/// 一项的正文与摘要都可缺 —— 两种缺失是不同的界面，不能合成一种。
NodeEntry _entry({String? body, String? summary}) => NodeEntry(
  nodeId: 'py:a',
  summary: summary,
  outcomes: const <String>[],
  resources: const <Resource>[],
  aliases: const <String>[],
  keywords: const <String>[],
  body: body,
  steps: const <EntryStep>[_readStep],
  selfCheck: const <String>[],
  criteria: const <Criterion>[],
  quiz: const <QuizItem>[],
  sourceRefs: const <String>[],
);

Future<void> _pump(WidgetTester tester, NodeEntry entry) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StepBody(
          step: _readStep,
          entry: entry,
          controller: TextEditingController(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TC-STEP-088 读步把 entry.body 当正文渲染，摘要不顶替它（SPEC-STEP-012）', (
    WidgetTester tester,
  ) async {
    const String body = 'BaseException\n├── SystemExit\n└── Exception';
    await _pump(tester, _entry(body: body, summary: '一句话摘要'));

    expect(find.byKey(const Key('step-reading')), findsOneWidget);
    // 正文区自己带滚动体 —— 长正文在区内滚，指令与主按钮都不动（`SPEC-STEP-010`）。
    expect(find.byKey(const Key('step-reading-scroll')), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    // 正文在时摘要不出现 —— 两者都摆出来，读者会以为摘要也是正文的一部分。
    expect(find.text('一句话摘要'), findsNothing);
    expect(find.text('读一遍'), findsOneWidget);
  });

  testWidgets('TC-STEP-089 没有正文 ⇒ 退回摘要，不留空框（SPEC-STEP-012）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _entry(summary: '一句话摘要'));

    expect(find.byKey(const Key('step-reading')), findsOneWidget);
    expect(find.text('一句话摘要'), findsOneWidget);
  });

  testWidgets('TC-STEP-090 正文与摘要都缺 ⇒ 不出正文区，只留指令（SPEC-STEP-012）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _entry());

    // 空框会被读成「没加载出来」，比没有正文更糟。
    expect(find.byKey(const Key('step-reading')), findsNothing);
    expect(find.text('读一遍'), findsOneWidget);
  });

  testWidgets('TC-STEP-091 正文里的空串与纯空白按缺失处理（SPEC-STEP-012）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _entry(body: '   ', summary: '一句话摘要'));

    // 一个只有空白的正文区与没有正文区在屏幕上一样，但前者还占着一块边框。
    expect(find.text('一句话摘要'), findsOneWidget);
  });
}
