/// 今日概览页（`SPEC-STEP-016`）：范围、读数、入口，以及「不显示没有来源的行」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/event_store.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/session/session_events.dart';
import 'package:project_knowledge/features/runner/overview_screen.dart';

import '../../support/pack_fixture.dart';

class _MemoryStore implements EventStore {
  _MemoryStore([List<Event>? seed]) : _events = <Event>[...?seed];

  final List<Event> _events;

  List<Event> get events => List<Event>.unmodifiable(_events);

  @override
  Future<void> append(Event event) async {
    _events.add(event);
  }

  @override
  Stream<Event> readAll({String? spaceId}) =>
      Stream<Event>.fromIterable(<Event>[
        for (final Event event in _events)
          if (spaceId == null || event.spaceId == spaceId) event,
      ]);

  @override
  Future<Event?> byId(String id) async {
    for (final Event event in _events) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }
}

const List<EntryStep> _steps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读一遍'),
];

const List<Criterion> _criteria = <Criterion>[
  Criterion(id: 'c1', statement: '能说明'),
];

const List<QuizItem> _quiz = <QuizItem>[
  QuizItem(
    id: 'q1',
    criterionId: 'c1',
    type: QuizType.freeform,
    prompt: '说说看',
    answer: '标准答案',
    judge: QuizJudge.self,
  ),
];

PackContent _pack() => fixturePack(<FixtureNode>[
  const FixtureNode('py:sys', 'Python', slot: LevelSlot.system),
  const FixtureNode(
    'py:a',
    '甲',
    parentId: 'py:sys',
    steps: _steps,
    criteria: _criteria,
    quiz: _quiz,
  ),
  const FixtureNode(
    'py:b',
    '乙',
    parentId: 'py:sys',
    steps: _steps,
    criteria: _criteria,
    quiz: _quiz,
  ),
]);

Event _passed(String itemId) => buildItemPassed(
  spaceId: 'python',
  itemId: itemId,
  gradedEventId: 'graded-$itemId',
  clock: HlcClock(deviceId: 'test-device'),
  now: DateTime.utc(2026, 10, 28, 3),
  userId: 'local',
);

/// 判一次。`minute` 用来把两条判定的 HLC 拉开，免得同 `(physical, counter)`
/// 让定序落到 id 兜底上 —— 那样测的就不是时间序了。
Event _graded(String itemId, Grade score, {required int minute}) =>
    buildItemGraded(
      spaceId: 'python',
      itemId: itemId,
      score: score,
      progressKind: ProgressKind.checked,
      clock: HlcClock(deviceId: 'test-device'),
      now: DateTime.utc(2026, 10, 28, 3, minute),
      userId: 'local',
    );

Future<void> _pump(WidgetTester tester, EventStore? store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OverviewScreen(content: _pack(), eventStore: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-STEP-025 概览只报有来源的那一行：新学 N 项，没有「复习」（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.text('新学 2 项'), findsOneWidget);
    expect(find.byKey(const Key('overview-start')), findsOneWidget);
    // 本笔只有体系序一源 —— 另外两行不该拿 0 凑数。
    expect(find.textContaining('复习'), findsNothing);
    expect(find.textContaining('缺口'), findsNothing);
  });

  testWidgets('TC-STEP-026 已学的项不计入新学数（门槛只认 item_passed）（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore(<Event>[_passed('py:a')]));
    expect(find.text('新学 1 项'), findsOneWidget);
  });

  testWidgets('TC-STEP-027 包内没写时长 ⇒ 不显示「预计 0 分钟」（无 SPEC：时长缺失的呈现方式未入册）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.textContaining('预计时长未知'), findsOneWidget);
    expect(find.textContaining('预计 0 分钟'), findsNothing);
  });

  testWidgets('TC-STEP-028 存储未接入 ⇒ 开始按钮不可用，且如实说明（无 SPEC：存储未接入时的降级形态未入册）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, null);
    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('overview-start')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('事件存储未接入'), findsWidgets);
  });

  testWidgets('TC-STEP-029 点「开始」进全屏 Runner（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    await tester.tap(find.byKey(const Key('overview-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('runner-position')), findsOneWidget);
  });

  testWidgets('TC-STEP-054 连续两次未过 ⇒ 出「缺口」行，且不计入新学（SPEC-STEP-021）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        _graded('py:a', Grade.fail, minute: 1),
        _graded('py:a', Grade.fail, minute: 2),
      ]),
    );
    expect(find.byKey(const Key('overview-gaps')), findsOneWidget);
    expect(find.text('缺口 1 项（回补）'), findsOneWidget);
    // 甲 是缺口、不算新学；剩下只有 乙。
    expect(find.text('新学 1 项'), findsOneWidget);
    expect(find.textContaining('复习'), findsNothing);
  });

  testWidgets('TC-STEP-055 中间有过合格 ⇒ 不出「缺口」行（清零，不按历史累计）（SPEC-STEP-021）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        _graded('py:a', Grade.fail, minute: 1),
        _graded('py:a', Grade.pass, minute: 2),
        _graded('py:a', Grade.fail, minute: 3),
      ]),
    );
    expect(find.byKey(const Key('overview-gaps')), findsNothing);
    expect(find.text('新学 2 项'), findsOneWidget);
  });
}
