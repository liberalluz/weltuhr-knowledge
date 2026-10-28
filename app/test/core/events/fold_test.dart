import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
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

Event _note(
  String id,
  int physical,
  String text, {
  String? itemId = 'py-a',
  int? targetVersion,
}) => _event(
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

/// 笔 5c：`spaceVersion` + `target{selector, resolved}` 换成 `packVersions` +
/// `subtreeRoot`（`event-types.md` §二 B 已同步）。
Event _planCreated(
  String id,
  int physical, {
  String spaceId = 'python',
  String subtreeRoot = 'python:fn',
  String schemeId = 'sch-full',
}) => _event(
  id: id,
  type: EventType.planCreated,
  physical: physical,
  itemId: null,
  spaceId: spaceId,
  payload: <String, Object?>{
    'subtreeRoot': subtreeRoot,
    'primaryAxis': 'major',
    'packVersions': <String, Object?>{
      'skeleton': '1.0.0',
      'payloads': <String, Object?>{'python': '0.1.0'},
    },
    'sourcePolicy': <String, Object?>{'primary': 'src-official'},
    'schemeId': schemeId,
    'methodProfileId': 'method-bundle-understand',
  },
);

Event _planRevised(
  String id,
  int physical, {
  required String planId,
  String subtreeRoot = 'python:async',
  String schemeId = 'sch-narrow',
}) => _event(
  id: id,
  type: EventType.planRevised,
  physical: physical,
  itemId: null,
  payload: <String, Object?>{
    'planId': planId,
    'subtreeRoot': subtreeRoot,
    'primaryAxis': 'major',
    'packVersions': <String, Object?>{
      'skeleton': '1.0.0',
      'payloads': <String, Object?>{'python': '0.1.0'},
    },
    'sourcePolicy': <String, Object?>{'primary': 'src-official'},
    'schemeId': schemeId,
    'methodProfileId': 'method-bundle-understand',
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

    test('TC-STEP-036 连续两次未过折出 2（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail'),
        _graded('e2', 1001, 'fail'),
      ]);
      expect(state.consecutiveFails['py-a'], 2);
    });

    test('TC-STEP-037 中间出现一次合格即清零（SPEC-STEP-021）', () {
      // 未过 → 合格 → 未过：数到最近那一段只有 1 次，不是「历史累计 2 次」。
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail'),
        _graded('e2', 1001, 'pass'),
        _graded('e3', 1002, 'fail'),
      ]);
      expect(state.consecutiveFails['py-a'], 1);
    });

    test('TC-STEP-038 熟练同样清零，不只合格（SPEC-STEP-021）', () {
      // 写成只判 pass 就会把「熟练」当成未过继续累加 —— 熟练是「这一次会了」。
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail'),
        _graded('e2', 1001, 'proficient'),
        _graded('e3', 1002, 'fail'),
      ]);
      expect(state.consecutiveFails['py-a'], 1);
    });

    test('TC-STEP-039 连续数按项分开算，不串到别的项（SPEC-STEP-021）', () {
      final FoldedState state = fold(<Event>[
        _graded('e1', 1000, 'fail', itemId: 'py-a'),
        _graded('e2', 1001, 'fail', itemId: 'py-b'),
        _graded('e3', 1002, 'fail', itemId: 'py-a'),
      ]);
      expect(state.consecutiveFails['py-a'], 2);
      expect(state.consecutiveFails['py-b'], 1);
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
      final FoldedNote note = state.noteOf(
        itemId: 'py-a',
        sectionKey: 'boundary',
      )!;
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
          payload: <String, Object?>{
            'itemId': 'py-gone',
            'spaceVersion': '1.2.0',
          },
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
      final FoldedNote note = state.noteOf(
        itemId: 'py-a',
        sectionKey: 'boundary',
      )!;
      expect(note.version, 3);
      expect(note.text, 'c');
    });

    test('回滚追加事件、正文回到目标版本，历史仍计数（无 SPEC：event-types.md §二 D）', () {
      final FoldedState state = fold(<Event>[
        _note('e1', 1000, 'a'),
        _note('e2', 1001, 'b'),
        _note('e3', 1002, '', targetVersion: 1),
      ]);
      final FoldedNote note = state.noteOf(
        itemId: 'py-a',
        sectionKey: 'boundary',
      )!;
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
      expect(fold(events, spaceId: 'python', userId: 'u-a').passed, <String>{
        'py-a',
      });
    });
  });

  group('计划', () {
    test(
      'TC-PLAN-055 plan_created 折出一份，版本从 1 起（无 SPEC：event-types.md §二 B）',
      () {
        final FoldedState state = fold(<Event>[_planCreated('e1', 1000)]);

        expect(state.plans.keys, <String>['e1'], reason: '身份 = 创建事件的 id');
        final Plan plan = state.plans['e1']!;
        expect(plan.id, 'e1');
        // 信封上的 `spaceId` **不折进 `Plan`**：`fold(spaceId:)` 已按它过滤，
        // 实体再存一份就是第二份真相。
        expect(plan.subtreeRoot, 'python:fn', reason: '范围由子树根表达');
        expect(plan.primaryAxis, Axis.major);
        expect(plan.packVersions.skeleton, '1.0.0');
        expect(plan.packVersions.payloads, <String, String>{'python': '0.1.0'});
        expect(plan.schemeId, 'sch-full');
        expect(plan.methodProfileId, 'method-bundle-understand');
        expect(plan.sourcePolicy, <String, Object?>{'primary': 'src-official'});
        expect(
          plan.toJson().containsKey('target'),
          isFalse,
          reason: '`resolved` 是派生值，折的时候重算，不落盘',
        );
        expect(plan.version, 1);
      },
    );

    test('TC-PLAN-056 同一子树两份计划独立存在（SPEC-PLAN-003 验收向量）', () {
      // 键是**创建事件的 id**。若有人把它改成 `subtreeRoot`，这两行会塌成一份 ——
      // 而 `Plan` 头部明写「同一子树可并存多份」（「入门跑通」与「专攻异步」）。
      final FoldedState state = fold(<Event>[
        _planCreated('e1', 1000, schemeId: 'sch-full'),
        _planCreated('e2', 2000, schemeId: 'sch-narrow'),
      ]);

      expect(state.plans.length, 2);
      expect(state.plans['e1']!.schemeId, 'sch-full');
      expect(state.plans['e2']!.schemeId, 'sch-narrow');
      expect(state.plans['e1']!.subtreeRoot, state.plans['e2']!.subtreeRoot);
      // 两份各自的版本独立计数，不是「同子树共用一份」。
      expect(state.plans['e1']!.version, 1);
      expect(state.plans['e2']!.version, 1);
    });

    test('TC-PLAN-057 plan_revised 版本 +1，且新 payload 覆盖旧值（SPEC-PLAN-019）', () {
      final FoldedState state = fold(<Event>[
        _planCreated('e1', 1000),
        _planRevised('e2', 2000, planId: 'e1'),
      ]);

      final Plan plan = state.plans['e1']!;
      expect(plan.version, 2, reason: '版本由 fold 数条数得出，payload 不写');
      expect(plan.schemeId, 'sch-narrow', reason: '重规划换了体系');
      expect(plan.subtreeRoot, 'python:async', reason: '重规划也换了范围根');
      expect(plan.packVersions.toJson(), <String, Object?>{
        'skeleton': '1.0.0',
        'payloads': <String, Object?>{'python': '0.1.0'},
      }, reason: '版本快照整份覆盖，不逐字段合并');
      expect(state.plans.length, 1, reason: '重规划改的是同一份，不是新开一份');
    });

    test('TC-PLAN-058 plan_revised 指向不存在的计划即抛错，不静默补建（SPEC-FND-014）', () {
      expect(
        () => fold(<Event>[_planRevised('e2', 2000, planId: 'ghost')]),
        throwsFormatException,
      );
    });

    test('TC-PLAN-059 同一条创建事件重传只算一次，版本不涨（无 SPEC：event-types.md §一 幂等）', () {
      final Event created = _planCreated('e1', 1000);
      final FoldedState state = fold(<Event>[created, created]);

      expect(state.plans['e1']!.version, 1);
      expect(state.plans.length, 1);
    });

    test('TC-PLAN-060 spaceId 过滤：别空间的计划折不进来（SPEC-FND-010）', () {
      final FoldedState state = fold(<Event>[
        _planCreated('e1', 1000),
        _planCreated('e2', 2000, spaceId: 'german'),
      ], spaceId: 'python');

      expect(state.plans.keys, <String>['e1']);
      // `plansOf(spaceId)` 已删：`Plan` 不持空间归属，上面那行 keys 就是全部证据。
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
      expect(
        () => fold(<Event>[_graded('e1', 1000, 'great')]),
        throwsFormatException,
      );
    });
  });
}
