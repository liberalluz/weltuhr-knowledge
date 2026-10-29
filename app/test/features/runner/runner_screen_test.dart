/// 会话界面（`SPEC-STEP-008` / `010` / `011` / `015` / `021`）：一屏一步、
/// 前进写事件、回退不写、验收两档。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/state.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/event_store.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/session/session_queue.dart';
import 'package:project_knowledge/features/runner/runner_screen.dart';

import '../../support/pack_fixture.dart';

class _MemoryStore implements EventStore {
  final List<Event> events = <Event>[];

  @override
  Future<void> append(Event event) async {
    events.add(event);
  }

  @override
  Stream<Event> readAll({String? spaceId}) =>
      Stream<Event>.fromIterable(<Event>[
        for (final Event event in events)
          if (spaceId == null || event.spaceId == spaceId) event,
      ]);

  @override
  Future<Event?> byId(String id) async {
    for (final Event event in events) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }
}

const List<EntryStep> _steps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读一遍'),
  EntryStep(operator: ExecutionOperator.recall, instruction: '回想一下'),
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
]);

/// 把 Runner 推进一层，好让「到点收尾」时的 `pop` 有地方可回。
///
/// [srs] 与 [graduated] 是进会话时的那份快照 —— 判毕业要凭「判分前的 S」，
/// 所以这两项默认空（等于「没学过」）。
Future<void> _pump(
  WidgetTester tester,
  EventStore store, {
  Map<String, SrsState> srs = const <String, SrsState>{},
  Set<String> graduated = const <String>{},
}) async {
  final PackContent pack = _pack();
  final SessionQueue queue = buildSessionQueue(
    pack: pack,
    subtreeRoot: 'py:sys',
    passed: const <String>{},
    // 队列要求显式时钟（它不自己取 `now`）。这里没有到期项 —— `passed` 是空的，
    // 复习池只收学过的项 —— 所以取哪个时刻都不影响本用例。
    now: DateTime.utc(2026, 10, 28, 12),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => RunnerScreen(
                  content: pack,
                  queue: queue,
                  cursors: const <String, int>{},
                  srs: srs,
                  graduated: graduated,
                  eventStore: store,
                ),
              ),
            ),
            child: const Text('进入'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('进入'));
  await tester.pumpAndSettle();
}

/// 一个「差一点就毕业」的记忆状态：判一次合格就会越过 `C-02`。
///
/// 取 179.9 而不是 180：180 已经毕业，测不出「本次判分让它过线」这件事。
SrsState _srsAlmostGraduated() {
  final DateTime now = DateTime.now();
  return SrsState(
    itemId: 'py:a',
    difficulty: 5,
    stability: 179.9,
    lastReviewAt: now.subtract(const Duration(days: 1)),
    due: now,
    failCount: 0,
    reps: 3,
    skipStreak: 0,
  );
}

void main() {
  testWidgets('TC-STEP-030 一屏只显当前步骤，位置条标出第 i/n 步（SPEC-STEP-010）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.text('读一遍'), findsOneWidget);
    expect(find.text('回想一下'), findsNothing);
    expect(find.text('第 1/2 步'), findsOneWidget);
  });

  testWidgets('TC-STEP-031 前进写一条 step_completed，回退不写事件（SPEC-STEP-011）', (
    WidgetTester tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    await _pump(tester, store);

    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    expect(store.events.length, 1);
    expect(store.events.single.type, EventType.stepCompleted);
    expect(store.events.single.payload['stepIndex'], 0);
    expect(store.events.single.payload['operator'], 'read');
    expect(find.text('第 2/2 步'), findsOneWidget);

    await tester.tap(find.byKey(const Key('runner-back')));
    await tester.pumpAndSettle();
    expect(store.events.length, 1);
    expect(find.text('第 1/2 步'), findsOneWidget);
  });

  testWidgets('TC-STEP-032 最后一步走完自动进 ⑤：给题目，可看参考答案（SPEC-STEP-015）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('grade-body')), findsOneWidget);
    expect(find.text('说说看'), findsOneWidget);
    expect(find.text('参考答案'), findsNothing);

    await tester.tap(find.byKey(const Key('grade-show-answer')));
    await tester.pumpAndSettle();
    expect(find.text('参考答案'), findsOneWidget);
  });

  testWidgets(
    'TC-STEP-033 判合格写两条：item_graded 在前、item_passed 指回它（SPEC-STEP-017）',
    (WidgetTester tester) async {
      final _MemoryStore store = _MemoryStore();
      await _pump(tester, store);
      await tester.tap(find.byKey(const Key('runner-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('runner-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grade-show-answer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grade-pass')));
      await tester.pumpAndSettle();

      final List<Event> events = store.events;
      expect(events.length, 4);
      expect(events[2].type, EventType.itemGraded);
      expect(events[2].payload['score'], 'pass');
      expect(events[2].payload['scaffold'], 'answer');
      expect(events[3].type, EventType.itemPassed);
      expect(events[3].payload['gradedEventId'], events[2].id);
    },
  );

  testWidgets('TC-STEP-034 判未过只写 item_graded，项留在原地从头再来（SPEC-STEP-021）', (
    WidgetTester tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    await _pump(tester, store);
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grade-fail')));
    await tester.pumpAndSettle();

    final List<Event> events = store.events;
    expect(events.length, 3);
    expect(events.last.type, EventType.itemGraded);
    expect(events.last.payload['score'], 'fail');
    // 没有 item_passed —— 未过不是「已学」。
    expect(
      events.where((Event event) => event.type == EventType.itemPassed),
      isEmpty,
    );
    // 回到该项第 1 步。
    expect(find.text('第 1/2 步'), findsOneWidget);
    expect(find.text('读一遍'), findsOneWidget);
  });

  testWidgets('TC-STEP-035 没点「看参考答案」时 scaffold 记 none（SPEC-STEP-022）', (
    WidgetTester tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    await _pump(tester, store);
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grade-pass')));
    await tester.pumpAndSettle();

    expect(store.events[2].payload['scaffold'], 'none');
  });

  testWidgets('TC-QUANT-036 判未过不写 graduated：S 再高，未过也不毕业（SPEC-STEP-002）', (
    WidgetTester tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    await _pump(
      tester,
      store,
      srs: <String, SrsState>{'py:a': _srsAlmostGraduated()},
    );
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grade-fail')));
    await tester.pumpAndSettle();

    expect(
      store.events.where((Event event) => event.type == EventType.graduated),
      isEmpty,
    );
  });

  testWidgets(
    'TC-QUANT-037 判分后 S 过线写一条 graduated，payload 带当时的 S（SPEC-QUANT-009 / SPEC-QUANT-018）',
    (WidgetTester tester) async {
      final _MemoryStore store = _MemoryStore();
      await _pump(
        tester,
        store,
        srs: <String, SrsState>{'py:a': _srsAlmostGraduated()},
      );
      await tester.tap(find.byKey(const Key('runner-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('runner-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grade-pass')));
      await tester.pumpAndSettle();

      final List<Event> graduated = store.events
          .where((Event event) => event.type == EventType.graduated)
          .toList();
      expect(graduated, hasLength(1));
      expect(graduated.single.itemId, 'py:a');
      expect(
        graduated.single.payload['sAtGraduation']! as double,
        greaterThanOrEqualTo(180),
      );
      // 顺序固定为 graded → passed → graduated：毕业以「已学」为前提。
      expect(store.events.last.type, EventType.graduated);
    },
  );

  testWidgets('TC-QUANT-038 已毕业的项不再写第二条 graduated（SPEC-STEP-002）', (
    WidgetTester tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    await _pump(
      tester,
      store,
      srs: <String, SrsState>{'py:a': _srsAlmostGraduated()},
      graduated: <String>{'py:a'},
    );
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runner-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grade-pass')));
    await tester.pumpAndSettle();

    expect(
      store.events.where((Event event) => event.type == EventType.graduated),
      isEmpty,
    );
  });
}
