import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/fold.dart';
import 'package:project_knowledge/core/session/gaps.dart';

Event _graded(
  String id,
  int physical,
  String score, {
  String itemId = 'py-a',
}) => Event(
  id: id,
  type: EventType.itemGraded,
  hlc: Hlc(physical: physical, counter: 0, deviceId: 'dev-a'),
  spaceId: 'python',
  userId: 'u-a',
  itemId: itemId,
  at: DateTime.fromMillisecondsSinceEpoch(physical, isUtc: true),
  payload: <String, Object?>{'score': score},
);

void main() {
  group('缺口阈值（C-09）', () {
    test('TC-STEP-040 差一次不判缺口（SPEC-STEP-021）', () {
      expect(isGapStreak(failStreakToGap - 1), isFalse);
    });

    test('TC-STEP-041 刚好达阈值即判缺口（SPEC-STEP-021）', () {
      expect(isGapStreak(failStreakToGap), isTrue);
    });

    test('TC-STEP-042 超过阈值仍是缺口，不是一次性开关（SPEC-STEP-021）', () {
      expect(isGapStreak(failStreakToGap + 3), isTrue);
    });
  });

  group('从折叠结果挑缺口项', () {
    test('TC-STEP-043 连续两次未过的项被挑出（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail'),
        _graded('e2', 1001, 'fail'),
      ]);
      expect(gapItemIds(state), <String>{'py-a'});
    });

    test('TC-STEP-044 只一次未过不挑（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[_graded('e1', 1000, 'fail')]);
      expect(gapItemIds(state), isEmpty);
    });

    test('TC-STEP-045 中间合格过的不挑（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail'),
        _graded('e2', 1001, 'pass'),
        _graded('e3', 1002, 'fail'),
      ]);
      expect(gapItemIds(state), isEmpty);
    });

    test('TC-STEP-046 合格过一次之后再连续两次未过，仍然算缺口（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'pass'),
        _graded('e2', 1001, 'fail'),
        _graded('e3', 1002, 'fail'),
      ]);
      expect(gapItemIds(state), <String>{'py-a'});
    });

    test('TC-STEP-047 零事件得空集，不抛错（SPEC-STEP-021）', () {
      expect(gapItemIds(fold(const <Event>[])), isEmpty);
    });
  });
}
