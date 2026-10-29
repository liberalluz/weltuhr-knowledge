/// 学习执行类事件的形状（`event-types.md` §二 A）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/session/session_events.dart';

final DateTime _now = DateTime.utc(2026, 10, 28, 3);

HlcClock _clock() => HlcClock(deviceId: 'test-device');

Event _step(HlcClock clock, {int index = 0}) => buildStepCompleted(
  spaceId: 'python',
  itemId: 'python:lex-keyword',
  stepIndex: index,
  operator: ExecutionOperator.recall,
  clock: clock,
  now: _now,
  userId: 'local',
);

void main() {
  group('session_events', () {
    test('TC-STEP-020 step_completed 写 stepIndex 与 operator 的线上取值（无 SPEC：payload 形状由 event-types §二 A 定，非 STEP 卷）', () {
      final Event event = _step(_clock(), index: 2);
      expect(event.type, EventType.stepCompleted);
      expect(event.payload['stepIndex'], 2);
      expect(event.payload['operator'], 'recall');
    });

    test('TC-STEP-021 item_graded 是唯一判定点：三档 + progressKind + scaffold（SPEC-STEP-017）', () {
      final Event event = buildItemGraded(
        spaceId: 'python',
        itemId: 'python:lex-keyword',
        score: Grade.pass,
        progressKind: ProgressKind.checked,
        checkin: false,
        scaffold: ScaffoldLevel.answer,
        clock: _clock(),
        now: _now,
        userId: 'local',
      );
      expect(event.type, EventType.itemGraded);
      expect(event.payload['score'], 'pass');
      expect(event.payload['progressKind'], 'checked');
      expect(event.payload['scaffold'], 'answer');
    });

    test('TC-STEP-022 scaffold 默认 none —— 没看过答案就不该被记成看过（SPEC-STEP-022）', () {
      final Event event = buildItemGraded(
        spaceId: 'python',
        itemId: 'python:lex-keyword',
        score: Grade.fail,
        progressKind: ProgressKind.checked,
        checkin: false,
        clock: _clock(),
        now: _now,
        userId: 'local',
      );
      expect(event.payload['scaffold'], 'none');
    });

    test('TC-STEP-023 先 graded 后 passed：passed 指向的那条在事件流里更早（无 SPEC：item_passed 的 payload 由 event-types §二 A 定）', () {
      final HlcClock clock = _clock();
      final Event graded = buildItemGraded(
        spaceId: 'python',
        itemId: 'python:lex-keyword',
        score: Grade.pass,
        progressKind: ProgressKind.checked,
        checkin: false,
        clock: clock,
        now: _now,
        userId: 'local',
      );
      final Event passed = buildItemPassed(
        spaceId: 'python',
        itemId: 'python:lex-keyword',
        gradedEventId: graded.id,
        clock: clock,
        now: _now,
        userId: 'local',
      );
      expect(passed.payload['gradedEventId'], graded.id);
      expect(passed.hlc.compareTo(graded.hlc), greaterThan(0));
      expect(passed.id, isNot(graded.id));
    });

    test('TC-STEP-024 信封落 spaceId / userId / itemId，payload 不重复 spaceId（无 SPEC：信封字段由 event-types §一 定）', () {
      final Event event = _step(_clock());
      expect(event.spaceId, 'python');
      expect(event.userId, 'local');
      expect(event.itemId, 'python:lex-keyword');
      expect(event.payload.containsKey('spaceId'), isFalse);
      expect(event.toJson()['itemId'], 'python:lex-keyword');
    });
  });
}
