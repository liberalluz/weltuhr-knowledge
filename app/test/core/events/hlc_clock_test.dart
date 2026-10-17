import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';

void main() {
  group('发号', () {
    test('首条：物理时间取当前毫秒，counter 从 0 起（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final Hlc issued = clock.next(DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
      expect(issued.physical, 1000);
      expect(issued.counter, 0);
      expect(issued.deviceId, 'dev-a');
    });

    test('同一毫秒连发：physical 不变、counter 递增（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final DateTime now = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final Hlc first = clock.next(now);
      final Hlc second = clock.next(now);
      final Hlc third = clock.next(now);
      expect(second.physical, first.physical);
      expect(second.counter, first.counter + 1);
      expect(third.counter, second.counter + 1);
      expect(first.compareTo(second), lessThan(0));
      expect(second.compareTo(third), lessThan(0));
    });

    test('物理时间前进：counter 归零（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
      clock.next(DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
      final Hlc later = clock.next(DateTime.fromMillisecondsSinceEpoch(1001, isUtc: true));
      expect(later.physical, 1001);
      expect(later.counter, 0);
    });

    test('时钟回拨：physical 不倒退，counter 顶上（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final Hlc high = clock.next(DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
      // 用户把系统时钟调回 1970 附近：新事件仍必须排在旧事件之后。
      final Hlc rolledBack = clock.next(DateTime.fromMillisecondsSinceEpoch(5, isUtc: true));
      expect(rolledBack.physical, high.physical);
      expect(rolledBack.counter, high.counter + 1);
      expect(high.compareTo(rolledBack), lessThan(0));
    });

    test('连发 1000 条严格递增、无重复（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      final Set<Hlc> seen = <Hlc>{};
      Hlc? previous;
      for (int i = 0; i < 1000; i++) {
        // 一半前进一半持平，覆盖两条分支。
        final int physical = 1000 + i ~/ 2;
        final Hlc issued = clock.next(DateTime.fromMillisecondsSinceEpoch(physical, isUtc: true));
        if (previous != null) {
          expect(previous.compareTo(issued), lessThan(0));
        }
        expect(seen.add(issued), isTrue);
        previous = issued;
      }
    });

    test('发出的 deviceId 恒为本地，seed 别人的 HLC 也不继承（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(
        deviceId: 'dev-local',
        seed: const Hlc(physical: 5000, counter: 7, deviceId: 'dev-remote'),
      );
      final Hlc issued = clock.next(DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true));
      expect(issued.deviceId, 'dev-local');
      expect(issued.physical, 5000);
      expect(issued.counter, 8);
    });
  });

  group('观测远端', () {
    test('远端更晚：跳到远端 physical，counter = 远端 + 1（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
      final Hlc after = clock.observe(const Hlc(physical: 2000, counter: 4, deviceId: 'dev-b'));
      expect(after.physical, 2000);
      expect(after.counter, 5);
      expect(after.deviceId, 'dev-a');
    });

    test('远端更早：本地不倒退，counter 加一（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
      final Hlc after = clock.observe(const Hlc(physical: 1000, counter: 99, deviceId: 'dev-b'));
      expect(after.physical, 2000);
      expect(after.counter, 1);
    });

    test('同 physical 且远端 counter 更大：取 max + 1（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
      final Hlc after = clock.observe(const Hlc(physical: 2000, counter: 9, deviceId: 'dev-b'));
      expect(after.physical, 2000);
      expect(after.counter, 10);
    });

    test('同 physical 且远端 counter 更小：仍取本地 + 1（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
      clock.next(DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
      final Hlc after = clock.observe(const Hlc(physical: 2000, counter: 0, deviceId: 'dev-b'));
      expect(after.physical, 2000);
      expect(after.counter, 2);
    });
  });

  group('重启', () {
    test('构造时 seed：接着库里最后一条往下走（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(
        deviceId: 'dev-a',
        seed: const Hlc(physical: 9000, counter: 3, deviceId: 'dev-remote'),
      );
      final Hlc issued = clock.next(DateTime.fromMillisecondsSinceEpoch(8000, isUtc: true));
      expect(issued.physical, 9000);
      expect(issued.counter, 4);
    });

    test('reseed 传入更低水位是空操作（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.next(DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true));
      clock.reseed(const Hlc(physical: 100, counter: 2, deviceId: 'dev-a'));
      expect(clock.last.physical, 5000);
      expect(clock.last.counter, 0);
    });

    test('reseed 只在前进时生效（SPEC-FND-011）', () {
      final HlcClock clock = HlcClock(deviceId: 'dev-a');
      clock.reseed(const Hlc(physical: 7000, counter: 2, deviceId: 'dev-a'));
      expect(clock.last.physical, 7000);
      expect(clock.last.counter, 2);
      final Hlc issued = clock.next(DateTime.fromMillisecondsSinceEpoch(6000, isUtc: true));
      expect(issued.physical, 7000);
      expect(issued.counter, 3);
    });
  });
}
