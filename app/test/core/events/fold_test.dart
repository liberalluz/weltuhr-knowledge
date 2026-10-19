import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/fold.dart';

Event _event({
  required String id,
  required EventType type,
  required int physical,
  int counter = 0,
  String deviceId = 'dev-a',
  String? itemId = 'py-a',
  String spaceId = 'python',
  String userId = 'u-a',
  Map<String, Object?> payload = const <String, Object?>{},
}) => Event(
  id: id,
  type: type,
  hlc: Hlc(physical: physical, counter: counter, deviceId: deviceId),
  spaceId: spaceId,
  userId: userId,
  itemId: itemId,
  at: DateTime.fromMillisecondsSinceEpoch(physical, isUtc: true),
  payload: payload,
);

Event _step(
  String id,
  int physical,
  int stepIndex, {
  String itemId = 'py-a',
  String spaceId = 'python',
}) => _event(
  id: id,
  type: EventType.stepCompleted,
  physical: physical,
  itemId: itemId,
  spaceId: spaceId,
  payload: <String, Object?>{'stepIndex': stepIndex, 'operator': 'read'},
);

Event _graded(
  String id,
  int physical,
  String score, {
  String itemId = 'py-a',
  int counter = 0,
}) => _event(
  id: id,
  type: EventType.itemGraded,
  physical: physical,
  counter: counter,
  itemId: itemId,
  payload: <String, Object?>{'score': score},
);

Event _note(String id, int physical, String text, {String? itemId = 'py-a', int? targetVersion}) =>
    _event(
      id: id,
      type: EventType.noteRevised,
      physical: physical,
      itemId: itemId,
      payload: <String, Object?>{
        'sectionKey': 'boundary',
        'text': text,
        'layer': 'authored',
        'targetVersion': ?targetVersion,
      },
    );

void main() {
  group('基本', () {
    test('空事件流：游标 0、无已学、无笔记（SPEC-FND-010）', () {
      final FoldedState state = fold(const <Event>[]);
      expect(state.cursorOf('py-a'), 0);
      expect(state.passed, isEmpty);
      expect(state.notes, isEmpty);
      expect(state.carries, isEmpty);
    });

    test('乱序输入按 hlc 重放，结果与排好序完全一致（SPEC-FND-011）', () {
      final List<Event> ordered = <Event>[
        _step('e1', 1000, 0),
        _graded('e2', 1001, 'fail'),
        _graded('e3', 1002, 'pass'),
      ];
      final FoldedState a = fold(ordered);
      final FoldedState b = fold(ordered.reversed);
      expect(b.cursorOf('py-a'), a.cursorOf('py-a'));
      expect(b.lastGrade['py-a'], Grade.pass);
      expect(b.lastGrade['py-a'], a.lastGrade['py-a']);
    });

    test('同 physical 不同 counter 也按 counter 定序（SPEC-FND-011）', () {
      final FoldedState state = fold(<Event>[
        _graded('e2', 1000, counter: 1, 'pass'),
        _graded('e1', 1000, counter: 0, 'fail'),
      ]);
      expect(state.lastGrade['py-a'], Grade.pass);
    });
  });

  group('游标', () {
    test('游标 = max(已完成 stepIndex) + 1（无 SPEC：event-types.md §二 A-1）', () {
      final FoldedState state = fold(<Event>[
        _step('e1', 1000, 0),
        _step('e2', 1001, 1),
      ]);
      expect(state.cursorOf('py-a'), 2);
    });

    test('step_completed 不撤销：回看低序号不倒退游标（无 SPEC：event-types.md §二 A-1）', () {
      final FoldedState state = fold(<Event>[
        _step('e1', 1000, 0),
        _step('e2', 1001, 1),
        _step('e3', 1002, 2),
        // 用户回退到第 1 步重看 —— 这是纯视图操作，但即便真写了事件也不该倒推。
        _step('e4', 1003, 0),
      ]);
      expect(state.cursorOf('py-a'), 3);
    });

    test('按项独立计数，互不干扰（无 SPEC：event-types.md §三 会话游标）', () {
      final FoldedState state = fold(<Event>[
        _step('e1', 1000, 2),
        _step('e2', 1001, 0, itemId: 'py-b'),
      ]);
      expect(state.cursorOf('py-a'), 3);
      expect(state.cursorOf('py-b'), 1);
      expect(state.cursorOf('py-unknown'), 0);
    });
  });

  group('判定', () {
    test('item_passed 一写不可撤销，后续「未过」不摘掉已学（无 SPEC：event-types.md §二 A-3）', () {
      final FoldedState state = fold(<Event>[
        _event(id: 'e1', type: EventType.itemPassed, physical: 1000),
        _graded('e2', 1001, 'fail'),
      ]);
      expect(state.isPassed('py-a'), isTrue);
      // 复习未过只降 S、提前 due —— 成绩单上确实记了「未过」。
      expect(state.lastGrade['py-a'], Grade.fail);
    });

    test('item_skipped 不写判定、不计已学（C-11）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'pass'),
        _event(id: 'e2', type: EventType.itemSkipped, physical: 1001),
      ]);
      expect(state.lastGrade['py-a'], Grade.pass);
      expect(state.isPassed('py-a'), isFalse);
      expect(state.cursorOf('py-a'), 0);
    });

    test('graduated 不可逆，后续事件不回退（无 SPEC：event-types.md §二 A graduated）', () {
      final FoldedState state = fold(<Event>[
        _event(id: 'e1', type: EventType.graduated, physical: 1000),
        _graded('e2', 1001, 'fail'),
      ]);
      expect(state.isGraduated('py-a'), isTrue);
    });

    test('item_graded 取时间序最后一条成绩（SPEC-FND-010）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'proficient'),
        _graded('e2', 1001, 'pass'),
        _graded('e3', 1002, 'fail'),
      ]);
      expect(state.lastGrade['py-a'], Grade.fail);
    });
  });

  group('幂等与去重', () {
    test('同一条事件重传两次只算一次（无 SPEC：event-types.md §一 幂等）', () {
      final Event revised = _note('e1', 1000, '第一版');
      final FoldedState state = fold(<Event>[revised, revised]);
      expect(state.noteOf(itemId: 'py-a', sectionKey: 'boundary')!.version, 1);
    });

    test('两台设备各学一遍同一节都算，不去重（无 SPEC：event-types.md §一）', () {
      final FoldedState state = fold(<Event>[
        _note('e1', 1000, '手机写的', itemId: 'py-a'),
        _event(
          id: 'e2',
          type: EventType.noteRevised,
          physical: 1001,
          deviceId: 'dev-b',
          payload: <String, Object?>{'sectionKey': 'boundary', 'text': '平板写的'},
        ),
      ]);
      final FoldedNote note = state.noteOf(itemId: 'py-a', sectionKey: 'boundary')!;
      expect(note.version, 2);
      expect(note.text, '平板写的');
    });
  });

  group('空间与快照', () {
    test('spaceId 过滤：只折该空间的事件（SPEC-FND-010）', () {
      final List<Event> events = <Event>[
        _step('e1', 1000, 1),
        _step('e2', 1001, 4, itemId: 'ja-a', spaceId: 'japanese'),
      ];
      final FoldedState python = fold(events, spaceId: 'python');
      expect(python.cursorOf('py-a'), 2);
      expect(python.cursorOf('ja-a'), 0);
    });

    test('asOf 截断：只折那一刻及之前（含）的事件（SPEC-FND-010）', () {
      final List<Event> events = <Event>[
        _graded('e1', 1000, 'pass'),
        _graded('e2', 1005, 'fail'),
      ];
      final FoldedState earlier = fold(
        events,
        asOf: const Hlc(physical: 1000, counter: 0, deviceId: 'dev-a'),
      );
      expect(earlier.lastGrade['py-a'], Grade.pass);

      final FoldedState later = fold(
        events,
        asOf: const Hlc(physical: 1005, counter: 0, deviceId: 'dev-a'),
      );
      expect(later.lastGrade['py-a'], Grade.fail);
    });
  });

  group('孤儿项', () {
    test('item_retired 之后进度仍在，只多一个已下线标记（SPEC-FND-012）', () {
      final FoldedState state = fold(<Event>[
        _step('e1', 1000, 2),
        _event(id: 'e2', type: EventType.itemPassed, physical: 1001),
        _event(
          id: 'e3',
          type: EventType.itemRetired,
          physical: 1002,
          itemId: null,
          payload: <String, Object?>{'itemId': 'py-a', 'spaceVersion': '1.1.0'},
        ),
      ]);
      expect(state.isRetired('py-a'), isTrue);
      expect(state.cursorOf('py-a'), 3);
      expect(state.isPassed('py-a'), isTrue);
    });

    test('信封 itemId 缺失时从 payload 读（SPEC-FND-012）', () {
      final FoldedState state = fold(<Event>[
        _event(
          id: 'e1',
          type: EventType.itemRetired,
          physical: 1000,
          itemId: null,
          payload: <String, Object?>{'itemId': 'py-gone', 'spaceVersion': '1.2.0'},
        ),
      ]);
      expect(state.retired, <String>{'py-gone'});
    });
  });

  group('笔记', () {
    test('版本 = 该节事件计数（无 SPEC：event-types.md §二 D）', () {
      final FoldedState state = fold(<Event>[
        _note('e1', 1000, 'a'),
        _note('e2', 1001, 'b'),
        _note('e3', 1002, 'c'),
      ]);
      final FoldedNote note = state.noteOf(itemId: 'py-a', sectionKey: 'boundary')!;
      expect(note.version, 3);
      expect(note.text, 'c');
    });

    test('回滚追加事件、正文回到目标版本，历史仍计数（无 SPEC：event-types.md §二 D）', () {
      final FoldedState state = fold(<Event>[
        _note('e1', 1000, 'a'),
        _note('e2', 1001, 'b'),
        _note('e3', 1002, '', targetVersion: 1),
      ]);
      final FoldedNote note = state.noteOf(itemId: 'py-a', sectionKey: 'boundary')!;
      expect(note.text, 'a');
      expect(note.version, 3);
    });

    test('回滚目标版本不存在即报错，不静默回落（SPEC-FND-014）', () {
      expect(
        () => fold(<Event>[
          _note('e1', 1000, 'a'),
          _note('e2', 1001, '', targetVersion: 5),
        ]),
        throwsFormatException,
      );
    });

    test('没写过的节返回 null，不是空对象（SPEC-FND-014）', () {
      final FoldedState state = fold(<Event>[_note('e1', 1000, 'a')]);
      expect(state.noteOf(itemId: 'py-a', sectionKey: 'how'), isNull);
      expect(state.noteOf(itemId: 'py-b', sectionKey: 'boundary'), isNull);
    });

    test('空间级自由笔记（itemId 为空）与项内笔记分开计（无 SPEC：entity-fields.md §8）', () {
      final FoldedState state = fold(<Event>[
        _note('e1', 1000, '项内'),
        _note('e2', 1001, '空间级', itemId: null),
      ]);
      expect(state.noteOf(itemId: 'py-a', sectionKey: 'boundary')!.version, 1);
      expect(state.noteOf(itemId: null, sectionKey: 'boundary')!.text, '空间级');
    });
  });

  group('迁移账本', () {
    test('拆分与合并都进账本，顺序同事件序（C-12）', () {
      final FoldedState state = fold(<Event>[
        _event(
          id: 'e1',
          type: EventType.stateCarried,
          physical: 1000,
          itemId: 'py-a',
          payload: <String, Object?>{
            'fromItemId': 'py-a',
            'toItemIds': <String>['py-a-1', 'py-a-2'],
            'ratio': 0.5,
          },
        ),
        _event(
          id: 'e2',
          type: EventType.stateMerged,
          physical: 1001,
          itemId: null,
          payload: <String, Object?>{
            'fromItemIds': <String>['py-a-1', 'py-a-2'],
            'toBeId': 'py-a-new',
          },
        ),
      ]);
      expect(state.carries.single.from, 'py-a');
      expect(state.carries.single.toItemIds, <String>['py-a-1', 'py-a-2']);
      expect(state.carries.single.ratio, 0.5);
      expect(state.merges.single.toItemId, 'py-a-new');
    });

    test('拆分缺 ratio 字段时按 1/n 补（C-12）', () {
      final FoldedState state = fold(<Event>[
        _event(
          id: 'e1',
          type: EventType.stateCarried,
          physical: 1000,
          itemId: 'py-a',
          payload: <String, Object?>{
            'fromItemId': 'py-a',
            'toItemIds': <String>['py-a-1', 'py-a-2', 'py-a-3'],
          },
        ),
      ]);
      expect(state.carries.single.ratio, closeTo(1 / 3, 1e-12));
    });
  });

  group('数据归属（SPEC-ACC-014）', () {
    test('同一设备两个账号的进度互不污染（SPEC-ACC-014）', () {
      final List<Event> events = <Event>[
        _event(id: 'a1', type: EventType.itemPassed, physical: 1000),
        _event(
          id: 'b1',
          type: EventType.itemPassed,
          physical: 2000,
          itemId: 'py-b',
          userId: 'u-b',
        ),
      ];
      expect(fold(events, userId: 'u-a').passed, <String>{'py-a'});
      expect(fold(events, userId: 'u-b').passed, <String>{'py-b'});
    });

    test('不传 userId 即全量折 —— 迁移与导出要的是「存在过」（SPEC-ACC-014）', () {
      final List<Event> events = <Event>[
        _event(id: 'a1', type: EventType.itemPassed, physical: 1000),
        _event(
          id: 'b1',
          type: EventType.itemPassed,
          physical: 2000,
          itemId: 'py-b',
          userId: 'u-b',
        ),
      ];
      expect(fold(events).passed, <String>{'py-a', 'py-b'});
    });

    test('userId 与 spaceId 同时给出时两级都生效（SPEC-ACC-014）', () {
      final List<Event> events = <Event>[
        _event(id: 'a1', type: EventType.itemPassed, physical: 1000),
        _event(
          id: 'a2',
          type: EventType.itemPassed,
          physical: 2000,
          itemId: 'en-a',
          spaceId: 'english',
        ),
        _event(
          id: 'b1',
          type: EventType.itemPassed,
          physical: 3000,
          itemId: 'py-b',
          userId: 'u-b',
        ),
      ];
      expect(
        fold(events, spaceId: 'python', userId: 'u-a').passed,
        <String>{'py-a'},
      );
    });
  });

  group('坏事件', () {
    test('缺 stepIndex 即抛错，不补默认值（SPEC-FND-014）', () {
      expect(
        () => fold(<Event>[
          _event(id: 'e1', type: EventType.stepCompleted, physical: 1000),
        ]),
        throwsFormatException,
      );
    });

    test('缺 itemId 即抛错，不补默认值（SPEC-FND-014）', () {
      expect(
        () => fold(<Event>[
          _event(
            id: 'e1',
            type: EventType.itemPassed,
            physical: 1000,
            itemId: null,
          ),
        ]),
        throwsFormatException,
      );
    });

    test('未知 score 取值即抛错并列出允许值（SPEC-FND-014）', () {
      expect(() => fold(<Event>[_graded('e1', 1000, 'great')]), throwsFormatException);
    });
  });
}
