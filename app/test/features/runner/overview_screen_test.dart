/// 今日概览页（`SPEC-STEP-016`）：范围、读数、入口，以及「不显示没有来源的行」。
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
import 'package:project_knowledge/features/runner/overview_screen.dart';

import '../../support/pack_fixture.dart';

class _MemoryStore implements EventStore {
  _MemoryStore([List<Event>? seed]) : _events = <Event>[...?seed];

  final List<Event> _events;

  List<Event> get events => List<Event>.unmodifiable(_events);

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

const List<EntryStep> _steps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读一遍'),
];

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

/// 五个可学项的包 —— 「点名前三项」这条口径要有第四项才验得出来。
PackContent _widePack() => fixturePack(<FixtureNode>[
  const FixtureNode('py:sys', 'Python', slot: LevelSlot.system),
  for (final (String id, String name) in <(String, String)>[
    ('py:1', '一'),
    ('py:2', '二'),
    ('py:3', '三'),
    ('py:4', '四'),
    ('py:5', '五'),
  ])
    FixtureNode(
      id,
      name,
      parentId: 'py:sys',
      steps: _steps,
      criteria: _criteria,
      quiz: _quiz,
    ),
]);

/// 六个可学项的包 —— `C-07` 是 5，第六项才排得进「额度用满」那种局面。
PackContent _pack6() => fixturePack(<FixtureNode>[
  const FixtureNode('py:sys', 'Python', slot: LevelSlot.system),
  for (int i = 1; i <= 6; i++)
    FixtureNode(
      'py:$i',
      '$i',
      parentId: 'py:sys',
      steps: _steps,
      criteria: _criteria,
      quiz: _quiz,
    ),
]);

Event _passed(String itemId, {int minute = 0}) => buildItemPassed(
  spaceId: 'python',
  itemId: itemId,
  gradedEventId: 'graded-$itemId',
  clock: HlcClock(deviceId: 'test-device'),
  now: DateTime.utc(2026, 10, 28, 3, minute),
  userId: 'local',
);

/// 判一次。`minute` 用来把两条判定的 HLC 拉开，免得同 `(physical, counter)`
/// 让定序落到 id 兜底上 —— 那样测的就不是时间序了。
Event _graded(String itemId, Grade score, {required int minute}) =>
    buildItemGraded(
      spaceId: 'python',
      itemId: itemId,
      score: score,
      progressKind: ProgressKind.checked,
      clock: HlcClock(deviceId: 'test-device'),
      now: DateTime.utc(2026, 10, 28, 3, minute),
      userId: 'local',
    );

Future<void> _pump(WidgetTester tester, EventStore? store) async {
  await _pumpWith(tester, _pack(), store);
}

Future<void> _pumpWith(
  WidgetTester tester,
  PackContent pack,
  EventStore? store, {
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OverviewScreen(content: pack, eventStore: store, now: now),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-STEP-025 概览只报有来源的那一行：新学 N 项，没有「复习」（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.text('新学 2 项'), findsOneWidget);
    expect(find.byKey(const Key('overview-start')), findsOneWidget);
    // 零事件 ⇒ 既无缺口也无到期项 —— 另外两行不该拿 0 凑数。
    expect(find.textContaining('复习'), findsNothing);
    expect(find.textContaining('缺口'), findsNothing);
  });

  testWidgets('TC-STEP-026 已学的项不计入新学数（门槛只认 item_passed）（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore(<Event>[_passed('py:a')]));
    expect(find.text('新学 1 项'), findsOneWidget);
  });

  testWidgets('TC-STEP-027 包内没写时长 ⇒ 不显示「预计 0 分钟」（无 SPEC：时长缺失的呈现方式未入册）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.textContaining('预计时长未知'), findsOneWidget);
    expect(find.textContaining('预计 0 分钟'), findsNothing);
  });

  testWidgets('TC-STEP-028 存储未接入 ⇒ 开始按钮不可用，且如实说明（无 SPEC：存储未接入时的降级形态未入册）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, null);
    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('overview-start')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('事件存储未接入'), findsWidgets);
  });

  testWidgets('TC-STEP-029 点「开始」进全屏 Runner（SPEC-STEP-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    await tester.tap(find.byKey(const Key('overview-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('runner-position')), findsOneWidget);
  });

  testWidgets('TC-STEP-054 连续两次未过 ⇒ 出「缺口」行，且不计入新学（SPEC-STEP-021）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        _graded('py:a', Grade.fail, minute: 1),
        _graded('py:a', Grade.fail, minute: 2),
      ]),
    );
    expect(find.byKey(const Key('overview-gaps')), findsOneWidget);
    expect(find.text('缺口 1 项（回补）'), findsOneWidget);
    // 甲 是缺口、不算新学；剩下只有 乙。
    expect(find.text('新学 1 项'), findsOneWidget);
    expect(find.textContaining('复习'), findsNothing);
  });

  testWidgets('TC-STEP-055 中间有过合格 ⇒ 不出「缺口」行（清零，不按历史累计）（SPEC-STEP-021）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        _graded('py:a', Grade.fail, minute: 1),
        _graded('py:a', Grade.pass, minute: 2),
        _graded('py:a', Grade.fail, minute: 3),
      ]),
    );
    expect(find.byKey(const Key('overview-gaps')), findsNothing);
    expect(find.text('新学 2 项'), findsOneWidget);
  });

  testWidgets('TC-STEP-056 缺口不足三项时全部点名（无 SPEC：概览明细点几项未入册）', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _MemoryStore(<Event>[
        _graded('py:a', Grade.fail, minute: 1),
        _graded('py:a', Grade.fail, minute: 2),
      ]),
    );
    // 明细在「缺口 N 项」下面，按队列顺序（缺口项排在前面）点名。
    expect(find.byKey(const Key('overview-gap-detail')), findsOneWidget);
    expect(find.text('甲'), findsOneWidget);
    // 不足四项时不许出现「还有」—— 那是给溢出用的措辞，用了会让人以为还有更多。
    expect(find.textContaining('还有'), findsNothing);
  });

  testWidgets('TC-STEP-057 缺口超过三项时点名前三项并说「还有 N 项」（无 SPEC：同上）', (
    WidgetTester tester,
  ) async {
    // 每项各占两个分钟：同分钟的两次判定 HLC 相同，事件 id 会撞车被去重，
    // 结果是只有第一项数得出「连续两次」—— 那不是被测逻辑的问题，是夹具打架。
    final List<String> ids = <String>['py:1', 'py:2', 'py:3', 'py:4', 'py:5'];
    final List<Event> events = <Event>[
      for (int i = 0; i < ids.length; i++) ...<Event>[
        _graded(ids[i], Grade.fail, minute: i * 2 + 1),
        _graded(ids[i], Grade.fail, minute: i * 2 + 2),
      ],
    ];
    await _pumpWith(tester, _widePack(), _MemoryStore(events));

    expect(find.text('缺口 5 项（回补）'), findsOneWidget);
    // 前三项按 id 序点名，第四、五项不出现，改用「还有 2 项」交代。
    expect(find.text('一、二、三… 还有 2 项'), findsOneWidget);
    expect(find.text('四'), findsNothing);
  });

  testWidgets('TC-STEP-058 无缺口时明细整块不出现，不留空行（无 SPEC：同上）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.byKey(const Key('overview-gap-detail')), findsNothing);
  });

  testWidgets('TC-STEP-069 打卡项也会到期 ⇒ 出「复习 1 项」，且不重复计入新学（SPEC-STEP-003）', (
    WidgetTester tester,
  ) async {
    // 打卡项的 `S` 冻结在初值（`QUANT-007`），`due` 仍按 `C-03` 反解得到 ——
    // 判定在 10-28，初值 `S` 约 3.2 天 ⇒ 到期日在 10-31 之后。看 11-05。
    await _pumpWith(
      tester,
      _pack(),
      _MemoryStore(<Event>[
        _passed('py:a'),
        _graded('py:a', Grade.pass, minute: 1),
      ]),
      now: DateTime.utc(2026, 11, 5, 12),
    );

    expect(find.text('复习 1 项'), findsOneWidget);
    expect(find.text('新学 1 项'), findsOneWidget);
    expect(find.text('复习 2 项'), findsNothing);
  });

  testWidgets('TC-STEP-070 还没到 due ⇒ 不出复习行，学过的项也不退回新学（SPEC-STEP-003）', (
    WidgetTester tester,
  ) async {
    await _pumpWith(
      tester,
      _pack(),
      _MemoryStore(<Event>[
        _passed('py:a'),
        _graded('py:a', Grade.pass, minute: 1),
      ]),
      now: DateTime.utc(2026, 10, 29, 12),
    );

    expect(find.byKey(const Key('overview-reviews')), findsNothing);
    expect(find.textContaining('复习'), findsNothing);
    expect(find.text('新学 1 项'), findsOneWidget);
  });

  testWidgets('TC-STEP-085 额度没用满 ⇒ 不出现「排到明天」（N=0 整行不出）（SPEC-STEP-028）', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _MemoryStore());
    expect(find.byKey(const Key('overview-reviews-deferred')), findsNothing);
    expect(find.byKey(const Key('overview-new-deferred')), findsNothing);
    expect(find.textContaining('排到明天'), findsNothing);
  });

  testWidgets(
    'TC-STEP-086 新学额度用满 ⇒ 灰字出、池行不出、开始键不可点（SPEC-STEP-028 · SPEC-STEP-030）',
    (WidgetTester tester) async {
      // 每项先判分、后写 `item_passed`：判分那一刻该项还没学过，才算「今天新学」。
      // 各占一分钟 —— 同分钟的判定 HLC 相同、事件 id 会撞车被去重。
      final List<Event> events = <Event>[
        for (int i = 1; i <= 5; i++) ...<Event>[
          _graded('py:$i', Grade.pass, minute: i * 2 - 1),
          _passed('py:$i', minute: i * 2),
        ],
      ];
      await _pumpWith(
        tester,
        _pack6(),
        _MemoryStore(events),
        now: DateTime.utc(2026, 10, 28, 12),
      );

      expect(find.byKey(const Key('overview-new-deferred')), findsOneWidget);
      expect(find.text('另有 1 项排到明天'), findsOneWidget);
      // 池行不出：替代它的那句说明了原因。「新学 0 项」会被读成「今天没事」。
      expect(find.text('新学 0 项'), findsNothing);
      expect(find.text('今天的名额已用完'), findsOneWidget);
      expect(find.textContaining('欠'), findsNothing);
      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('overview-start')),
      );
      expect(button.onPressed, isNull);
    },
  );
}
