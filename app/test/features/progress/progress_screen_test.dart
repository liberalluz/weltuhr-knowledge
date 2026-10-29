/// 进展视图 · 能力清单分区（`SPEC-QUANT-011`）。
///
/// 六条用例只覆盖**分区可读**这一层：谁出现在哪、数值有没有、空态说什么、
/// 什么词不许出现。它不验掌握度的算法 —— 那是 `mastery.dart` 与
/// `progress_test.dart` 的事，界面这边只负责「把算出来的数原样显示成整数百分比」，
/// 所以下面比较的是**两项之间的相对大小**，而不是某个写死的百分数：写死 32%
/// 会在 `C-01` / `C-25` 调参时红，而它红得没有任何信息量。
///
/// 「历史」区单独一条验折叠：下线项的默认状态是**看不见**，只有点了才出现 ——
/// 反过来（默认展开）会让「以前学过什么」抢当前能力的注意力（见屏文件注释）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/event_store.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/session/session_events.dart';
import 'package:project_knowledge/features/progress/progress_screen.dart';

import '../../support/pack_fixture.dart';

class _MemoryStore implements EventStore {
  _MemoryStore([List<Event>? seed]) : _events = <Event>[...?seed];

  final List<Event> _events;

  @override
  Future<void> append(Event event) async {
    _events.add(event);
  }

  @override
  Stream<Event> readAll({String? spaceId}) =>
      Stream<Event>.fromIterable(<Event>[
        for (final Event event in _events)
          if (spaceId == null || event.spaceId == spaceId) event,
      ]);

  @override
  Future<Event?> byId(String id) async {
    for (final Event event in _events) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }
}

const String _space = 'python';

const List<EntryStep> _steps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读一遍'),
];

/// 判据非空 ⇒ 不是打卡项（`entry.isCheckin == false`）⇒ `S` 照常增长、
/// 掌握度不乘 `C-25` 的封顶。空判据会把两项的掌握度一起压到 50% 以内，
/// 那时「学得多的那项更高」这条断言就分不开了。
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

/// 甲、乙两项，同一父下 —— 顺序由 `pack.nodes` 给，甲在前。
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
  const FixtureNode(
    'py:b',
    '乙',
    parentId: 'py:sys',
    steps: _steps,
    criteria: _criteria,
    quiz: _quiz,
  ),
]);

final HlcClock _clock = HlcClock(deviceId: 'test-device');

/// 第 [day] 天的凌晨三点。
///
/// **必须按天铺开、不能只差几分钟**：`S` 的增量取决于评分时的召回率 `R`，
/// 而 `R` 随间隔衰减 —— 三次判分挤在几分钟里，`R≈1`，`S` 几乎不涨，两项的
/// 掌握度会双双落到同一个整数百分比上，用例就分不出「学得多」与「学得少」。
DateTime _at(int day) => DateTime.utc(2026, 10, 1, 3).add(Duration(days: day));

/// 判一次。`day` 逐次递增还有一个副作用是正好要的：同一天的判定 HLC 相同、
/// 事件 id 会撞车被去重，那样「判了三次」只剩一次。
Event _graded(String itemId, Grade score, int minute) => buildItemGraded(
  spaceId: _space,
  itemId: itemId,
  score: score,
  progressKind: ProgressKind.checked,
  checkin: false,
  clock: _clock,
  now: _at(minute),
  userId: 'local',
);

Event _passed(String itemId, int minute) => buildItemPassed(
  spaceId: _space,
  itemId: itemId,
  gradedEventId: 'graded-$itemId-$minute',
  clock: _clock,
  now: _at(minute),
  userId: 'local',
);

Event _graduated(String itemId, int minute) => buildGraduated(
  spaceId: _space,
  itemId: itemId,
  sAtGraduation: 200,
  clock: _clock,
  now: _at(minute),
  userId: 'local',
);

/// `item_retired` 没有会话侧的构造器（它不是学习动作），这里照 `event-types.md`
/// §二 C 直接造：信封 `itemId` 可为空，本用例两边都写，与真实迁移事件一致。
Event _retired(String itemId, int minute) {
  final Hlc hlc = _clock.next(_at(minute));
  return Event(
    id: 'retired-$itemId',
    type: EventType.itemRetired,
    hlc: hlc,
    spaceId: _space,
    userId: 'local',
    itemId: itemId,
    at: DateTime.fromMillisecondsSinceEpoch(hlc.physical, isUtc: true),
    payload: <String, Object?>{'itemId': itemId, 'spaceVersion': '1.1.0'},
  );
}

/// 一项走完「判分 → 已学 → 毕业」。[reps] 是判分次数 —— 次数越多 `S` 越长，
/// 掌握度越高。
List<Event> _graduatedItem(String itemId, {required int reps, int from = 1}) =>
    <Event>[
      for (int i = 0; i < reps; i++) _graded(itemId, Grade.pass, from + i * 2),
      _passed(itemId, from + reps * 2),
      _graduated(itemId, from + reps * 2 + 1),
    ];

Future<void> _pump(WidgetTester tester, EventStore? store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProgressScreen(content: _pack(), eventStore: store),
    ),
  );
  await tester.pumpAndSettle();
}

/// 页面上所有「整数百分比」的数值，按出现顺序。
List<int> _percents(WidgetTester tester) => <int>[
  for (final Element element
      in find
          .byWidgetPredicate(
            (Widget w) =>
                w is Text && w.data != null && _percent.hasMatch(w.data!),
          )
          .evaluate())
    int.parse((element.widget as Text).data!.replaceAll('%', '')),
];

final RegExp _percent = RegExp(r'^\d+%$');

void main() {
  testWidgets('TC-QUANT-045 已毕业项按包内顺序列出，掌握度显示为整数百分比（SPEC-QUANT-011）', (
    WidgetTester tester,
  ) async {
    // 乙 判三次、甲 判一次 ⇒ 乙 的 `S` 更长，掌握度必须更高。顺序断言就藏在这条
    // 不等号里：包内顺序是甲在前，取到的两个百分比若反了，说明列表没按 `pack.nodes`。
    await _pump(
      tester,
      _MemoryStore(<Event>[
        ..._graduatedItem('py:a', reps: 1),
        ..._graduatedItem('py:b', reps: 3, from: 10),
      ]),
    );

    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    final List<int> percents = _percents(tester);
    expect(percents, hasLength(2));
    expect(percents.last, greaterThan(percents.first));
  });

  testWidgets('TC-QUANT-046 适用场景显示 entry 的 `outcomes`（SPEC-QUANT-011）', (
    WidgetTester tester,
  ) async {
    // 夹具的 `entryJson` 把 `outcomes` 写成「能说明<项名>」—— 界面上应该原样
    // 出现，而不是回落到摘要或项名。
    await _pump(
      tester,
      _MemoryStore(<Event>[..._graduatedItem('py:a', reps: 1)]),
    );

    expect(find.text('能说明甲'), findsOneWidget);
    expect(find.text('能说明乙'), findsNothing);
  });

  testWidgets('TC-QUANT-047 无毕业项 ⇒ 空态文案可见，且不留空列表（SPEC-QUANT-011）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());

    expect(find.textContaining('还没有毕业的项'), findsOneWidget);
    // 空态是「一段话」而不是「一个空 ListView」—— 后者看上去像加载失败。
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('TC-QUANT-048 已下线项进「历史」区且默认折叠（SPEC-QUANT-011）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        ..._graduatedItem('py:a', reps: 1),
        _retired('py:b', 20),
      ]),
    );

    expect(find.text('历史（1 项已下线）'), findsOneWidget);
    // 默认折叠：折叠时子项**不建**，不是建了再隐藏。
    expect(find.text('乙'), findsNothing);

    await tester.tap(find.text('历史（1 项已下线）'));
    await tester.pumpAndSettle();
    expect(find.text('乙'), findsOneWidget);
    // 展开之后它仍在「历史」里，没有跑进能力清单 —— 能力清单只认 `graduated`。
    expect(find.text('能说明乙'), findsNothing);
  });

  testWidgets('TC-QUANT-049 计划进度区只给占位文案，不给读数（无 SPEC：该区口径未定）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[..._graduatedItem('py:a', reps: 1)]),
    );

    expect(find.text('计划进度'), findsOneWidget);
    expect(find.textContaining('尚未实现'), findsOneWidget);
    // 一个数字都不给：给了百分比就等于用界面替规格决定「一段怎么算完成」。
    expect(_percents(tester), hasLength(1));
  });

  testWidgets('TC-QUANT-050 全页不出现事件计数措辞（SPEC-VIEW-035）', (
    WidgetTester tester,
  ) async {
    // 埋 3 次判分 + 2 步完成：只要界面把事件条数当读数，这些数字就会露出来。
    // 必须先毕业 —— 否则空态文案里的「末次验收」「180 天」会被下面第 1 条
    // 正则误伤，测的就不是计数措辞了。
    await _pump(
      tester,
      _MemoryStore(<Event>[
        buildStepCompleted(
          spaceId: _space,
          itemId: 'py:a',
          stepIndex: 0,
          operator: ExecutionOperator.read,
          clock: _clock,
          now: _at(1),
          userId: 'local',
        ),
        buildStepCompleted(
          spaceId: _space,
          itemId: 'py:a',
          stepIndex: 1,
          operator: ExecutionOperator.read,
          clock: _clock,
          now: _at(2),
          userId: 'local',
        ),
        ..._graduatedItem('py:a', reps: 3, from: 10),
      ]),
    );

    expect(find.text('甲'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+\s*次')), findsNothing);
    expect(find.textContaining('累计'), findsNothing);
    expect(find.textContaining('小时'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d+$')), findsNothing);
  });
}
