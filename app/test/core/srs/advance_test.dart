/// `advanceSrs` 的判据：它是 `fold` 与判分写入点**共用的一份递推**（`B6` 笔 2）。
///
/// 这条用例的价值不在「算得对」（那是 `fsrs_test` 的事），而在**两条路径给出
/// 同一个数**。反证方式：把 `fold` 改回自己写一遍递推，下面那条 `expect` 会在
/// 隔天复习那一支上分叉（同日 / 冻结两条分支的先后判断不同）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/fold.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/session/session_events.dart';
import 'package:project_knowledge/core/srs/advance.dart';

const String _space = 'python';
const String _item = 'py-a';
const String _user = 'u-a';

Event _graded(
  HlcClock clock,
  Grade grade,
  DateTime at, {
  bool checkin = false,
}) => buildItemGraded(
  spaceId: _space,
  itemId: _item,
  score: grade,
  progressKind: ProgressKind.checked,
  checkin: checkin,
  clock: clock,
  now: at,
  userId: _user,
);

void main() {
  group('S 的单一算法（B6 笔 2）', () {
    test('TC-QUANT-034 advanceSrs 与 fold 对同一事件序给出同一 S（SPEC-QUANT-004）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final DateTime t0 = DateTime.utc(2026, 10, 28, 3);
      final List<Event> events = <Event>[
        _graded(clock, Grade.pass, t0),
        _graded(clock, Grade.pass, t0.add(const Duration(days: 1))),
        _graded(clock, Grade.proficient, t0.add(const Duration(days: 3))),
      ];

      final FoldedState folded = fold(events, spaceId: _space, userId: _user);

      SrsAdvance? acc;
      for (final Event event in events) {
        acc = advanceSrs(
          previous: acc,
          grade: Grade.fromWire(event.payload['score']! as String),
          at: event.at,
        );
      }

      expect(acc!.stability, folded.srsOf(_item)!.stability);
      expect(acc.difficulty, folded.srsOf(_item)!.difficulty);
      expect(acc.reps, folded.srsOf(_item)!.reps);
    });

    test('TC-QUANT-035 打卡式冻结也走同一份：十次判分后两边都停在初值（SPEC-QUANT-007）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final DateTime t0 = DateTime.utc(2026, 10, 28, 3);
      final List<Event> events = <Event>[
        for (int i = 0; i < 10; i++)
          _graded(clock, Grade.pass, t0.add(Duration(days: i)), checkin: true),
      ];

      final FoldedState folded = fold(events, spaceId: _space, userId: _user);

      SrsAdvance? acc;
      for (final Event event in events) {
        acc = advanceSrs(
          previous: acc,
          grade: Grade.fromWire(event.payload['score']! as String),
          at: event.at,
          checkedOnly: true,
        );
      }

      expect(acc!.stability, folded.srsOf(_item)!.stability);
    });
  });
}
