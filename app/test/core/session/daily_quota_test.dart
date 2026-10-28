/// 当日两池用量（`SPEC-STEP-028`）：按「当天已判分」折，日界由时区偏移定。
///
/// 本文件只验计量，不验截断 —— 截断在 `session_queue_test.dart`，显示在
/// `overview_screen_test.dart`。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/session/daily_quota.dart';

/// 东八区。写成 `Duration` 而不是让被测函数自己读系统时区 —— 测试机可能是任何时区。
const Duration _cst = Duration(hours: 8);

/// 「今天」= 本地 2026-10-28 12:00。
final DateTime _asOf = DateTime.utc(2026, 10, 28, 4);

Event _graded(String id, DateTime at, {String itemId = 'py:a'}) => Event(
  id: id,
  type: EventType.itemGraded,
  hlc: Hlc(physical: at.millisecondsSinceEpoch, counter: 0, deviceId: 'dev-a'),
  spaceId: 'python',
  userId: 'u-a',
  itemId: itemId,
  at: at,
  payload: const <String, Object?>{'score': 'pass'},
);

Event _passed(String id, DateTime at, {String itemId = 'py:a'}) => Event(
  id: id,
  type: EventType.itemPassed,
  hlc: Hlc(physical: at.millisecondsSinceEpoch, counter: 0, deviceId: 'dev-a'),
  spaceId: 'python',
  userId: 'u-a',
  itemId: itemId,
  at: at,
);

Event _skipped(String id, DateTime at, {String itemId = 'py:a'}) => Event(
  id: id,
  type: EventType.itemSkipped,
  hlc: Hlc(physical: at.millisecondsSinceEpoch, counter: 0, deviceId: 'dev-a'),
  spaceId: 'python',
  userId: 'u-a',
  itemId: itemId,
  at: at,
);

void main() {
  group('dailyQuotaUsage', () {
    test('TC-STEP-071 当天首次判分、此前没学过 ⇒ 计新学（SPEC-STEP-028）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: <Event>[_graded('e1', DateTime.utc(2026, 10, 28, 3))],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.learned, 1);
      expect(usage.reviewed, 0);
    });

    test('TC-STEP-072 判分之前该项已学过 ⇒ 计复习（SPEC-STEP-028）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: <Event>[
          _passed('e1', DateTime.utc(2026, 10, 27, 3)),
          _graded('e2', DateTime.utc(2026, 10, 28, 3)),
        ],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.reviewed, 1);
      expect(usage.learned, 0);
    });

    test('TC-STEP-073 昨天的判分不算今天 —— 跨日即重置（SPEC-STEP-028）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: <Event>[
          _passed('e0', DateTime.utc(2026, 10, 26, 3)),
          _graded('e1', DateTime.utc(2026, 10, 27, 3)),
          _graded('e2', DateTime.utc(2026, 10, 28, 3), itemId: 'py:b'),
        ],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.reviewed, 0);
      expect(usage.learned, 1);
    });

    test('TC-STEP-074 同一项当天判分两次只算一项，按第一次的性质归池（SPEC-STEP-028）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: <Event>[
          // 第一次判分前没学过 ⇒ 归新学；随后写了 `item_passed`，第二次判分
          // 虽然「之前已学过」，也不该再吃一份复习额度。
          _graded('e1', DateTime.utc(2026, 10, 28, 2)),
          _passed('e2', DateTime.utc(2026, 10, 28, 2, 30)),
          _graded('e3', DateTime.utc(2026, 10, 28, 3)),
        ],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.learned, 1);
      expect(usage.reviewed, 0);
    });

    test('TC-STEP-075 日界按传入的时区偏移切 —— 同一份事件换个偏移就落到另一天（SPEC-STEP-028）', () {
      // UTC 10-27 20:00 = 东八区 10-28 04:00。按 +8 是今天，按 UTC 是昨天。
      final List<Event> events = <Event>[
        _graded('e1', DateTime.utc(2026, 10, 27, 20)),
      ];
      final DailyQuotaUsage inCst = dailyQuotaUsage(
        events: events,
        asOf: _asOf,
        utcOffset: _cst,
      );
      final DailyQuotaUsage inUtc = dailyQuotaUsage(
        events: events,
        asOf: _asOf,
        utcOffset: Duration.zero,
      );
      expect(inCst.learned, 1);
      expect(inUtc.learned, 0);
    });

    test('TC-STEP-076 跳过与步骤完成不占额度 —— 只有判分才算「做了」（SPEC-STEP-028）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: <Event>[
          _skipped('e1', DateTime.utc(2026, 10, 28, 2)),
          _skipped('e2', DateTime.utc(2026, 10, 28, 3)),
        ],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.learned, 0);
      expect(usage.reviewed, 0);
    });

    test('TC-STEP-077 空日志 ⇒ 两池都用 0（无 SPEC：STEP-028 未写空态，本批按「没事件就没用量」定）', () {
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: const <Event>[],
        asOf: _asOf,
        utcOffset: _cst,
      );
      expect(usage.learned, 0);
      expect(usage.reviewed, 0);
      expect(quotaRemaining(cap: 20, used: usage.reviewed), 20);
      expect(quotaRemaining(cap: 5, used: usage.learned), 5);
    });

    test('TC-STEP-078 剩余额度不会算成负数（无 SPEC：STEP-028 只说上限，未写超限时的读数）', () {
      expect(quotaRemaining(cap: 5, used: 7), 0);
      expect(quotaRemaining(cap: 5, used: 5), 0);
      expect(quotaRemaining(cap: 5, used: 3), 2);
    });
  });
}
