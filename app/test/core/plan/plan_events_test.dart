import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1792400000000, isUtc: true);

PlanDraft _draft() => const PlanDraft(
  spaceId: 'python',
  spaceVersion: '0.1.0',
  target: PlanTarget(
    selector: <String, Object?>{},
    resolved: <String>['py-a', 'py-b'],
  ),
  sourcePolicy: <String, Object?>{'primary': 'src-official'},
  schemeId: 'sch-full',
  methodProfileId: 'method-bundle-understand',
);

void main() {
  group('plan_created', () {
    test('TC-PLAN-047 载荷齐全，且刻意不写 spaceId / planId / version（无 SPEC：event-types.md §二 B）', () {
      final Event event = buildPlanCreated(
        draft: _draft(),
        clock: HlcClock(deviceId: 'dev-a'),
        now: _now,
        userId: 'u-a',
      );

      expect(event.type, EventType.planCreated);
      expect(event.spaceId, 'python', reason: '空间过滤维度在信封上');
      expect(event.userId, 'u-a');
      expect(event.itemId, isNull, reason: '计划不是项级事实');

      expect(event.payload['spaceVersion'], '0.1.0');
      expect(event.payload['schemeId'], 'sch-full');
      expect(event.payload['methodProfileId'], 'method-bundle-understand');
      expect(event.payload['sourcePolicy'], <String, Object?>{'primary': 'src-official'});
      expect(event.payload['target'], <String, Object?>{
        'selector': <String, Object?>{},
        'resolved': <String>['py-a', 'py-b'],
      });

      // 三个「本可以写、但写了就是第二份真相」的字段。
      expect(event.payload.containsKey('spaceId'), isFalse, reason: '信封已承载');
      expect(event.payload.containsKey('planId'), isFalse, reason: '身份就是这条事件的 id');
      expect(event.payload.containsKey('version'), isFalse, reason: '版本由 fold 数条数得出');
    });

    test('TC-PLAN-048 同毫秒连发两条：id 不撞，hlc 仍严格递增（无 SPEC：HLC 全序）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final Event created = buildPlanCreated(
        draft: _draft(),
        clock: clock,
        now: _now,
        userId: 'u-a',
      );
      final Event revised = buildPlanRevised(
        planId: created.id,
        draft: _draft(),
        clock: clock,
        now: _now,
        userId: 'u-a',
      );

      expect(revised.id, isNot(created.id));
      expect(revised.hlc.compareTo(created.hlc), greaterThan(0));
      expect(revised.at, created.at, reason: '同一毫秒，人读时间相同；先后归 hlc');
    });

    test('TC-PLAN-049 plan_revised 的 payload 带 planId，其余与创建同形（无 SPEC：PLAN-003 需区分同空间多份）', () {
      final Event event = buildPlanRevised(
        planId: 'dev-a:1792400000000:0',
        draft: _draft(),
        clock: HlcClock(deviceId: 'dev-a'),
        now: _now,
        userId: 'u-a',
      );

      expect(event.type, EventType.planRevised);
      expect(event.payload['planId'], 'dev-a:1792400000000:0');
      expect(event.payload['schemeId'], 'sch-full');
      // `version` 仍不写 —— 重规划了几次由 fold 数，不由写事件的人自报。
      expect(event.payload.containsKey('version'), isFalse);
    });
  });
}
