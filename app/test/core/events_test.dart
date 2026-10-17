import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/events/event.dart';

Event _event() => Event(
  id: 'e-1',
  type: EventType.itemPassed,
  hlc: const Hlc(physical: 1760700000000, counter: 3, deviceId: 'dev-a'),
  spaceId: 'python',
  itemId: 'py-lambda',
  at: DateTime.utc(2026, 10, 17, 11, 30),
  payload: <String, Object?>{'gradedEventId': 'g-1'},
);

void main() {
  group('HLC', () {
    test('全序比较：physical → counter → deviceId', () {
      const Hlc a = Hlc(physical: 100, counter: 0, deviceId: 'b');
      const Hlc b = Hlc(physical: 100, counter: 0, deviceId: 'c');
      const Hlc c = Hlc(physical: 100, counter: 1, deviceId: 'a');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(c), lessThan(0));
      expect(c.compareTo(a), greaterThan(0));
    });

    test('相同三元组相等且哈希一致', () {
      const Hlc a = Hlc(physical: 1, counter: 2, deviceId: 'x');
      const Hlc b = Hlc(physical: 1, counter: 2, deviceId: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Event', () {
    test('线上类型名为 snake_case，往返保真', () {
      final Event original = _event();
      expect(eventTypeWireName(original.type), 'item_passed');

      final Event roundTrip = Event.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.type, EventType.itemPassed);
      expect(roundTrip.hlc, original.hlc);
      expect(roundTrip.itemId, 'py-lambda');
      expect(roundTrip.payload['gradedEventId'], 'g-1');
    });

    test('事件类型全集都有唯一 wire 名', () {
      final List<String> names = EventType.values.map(eventTypeWireName).toList();
      expect(names.toSet().length, EventType.values.length);
      expect(names, contains('step_completed'));
      expect(names, contains('note_revised'));
    });

    test('未知 wire 名抛 FormatException', () {
      expect(() => eventTypeFromWire('unknown_event'), throwsFormatException);
    });

    test('itemId 可为空（迁移类事件）', () {
      final Event retired = Event(
        id: 'e-2',
        type: EventType.itemRetired,
        hlc: const Hlc(physical: 1, counter: 0, deviceId: 'd'),
        spaceId: 'python',
        at: DateTime.utc(2026, 10, 17),
      );
      final Event roundTrip = Event.fromJson(retired.toJson());
      expect(roundTrip.itemId, isNull);
      expect(roundTrip.type, EventType.itemRetired);
    });
  });
}
