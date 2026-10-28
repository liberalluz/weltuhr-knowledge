/// 队列构建（`SPEC-STEP-003` / `004` / `021`）：前沿、排除、排序、三条源合成。
///
/// 三条源都接上了：体系序 / 缺口回补 / SRS 到期。`due` 由 `fold` 的 `SrsState`
/// 给，这里直接造 `SrsState` —— 本文件验的是**入队判定**，不是 FSRS 的式子
/// （那在 `fsrs_test.dart` 与 `fold_test.dart`）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/entities/state.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/session/session_queue.dart';

import '../../support/pack_fixture.dart';

const List<EntryStep> _steps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读一遍'),
  EntryStep(operator: ExecutionOperator.recall, instruction: '回想'),
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
    answer: '参考答案',
    judge: QuizJudge.self,
  ),
];

/// `py:sys` 下挂 [names]（a / b / c），全部可学、都有两步。
PackContent _pack({
  List<(String, String)> prerequisites = const <(String, String)>[],
  List<(String, String)> recommended = const <(String, String)>[],
  Set<String> withoutSteps = const <String>{},
}) => fixturePack(
  <FixtureNode>[
    const FixtureNode('py:sys', 'Python', slot: LevelSlot.system),
    for (final String id in <String>['py:a', 'py:b', 'py:c'])
      FixtureNode(
        id,
        id.substring(3),
        parentId: 'py:sys',
        steps: withoutSteps.contains(id) ? const <EntryStep>[] : _steps,
        criteria: _criteria,
        quiz: _quiz,
      ),
  ],
  prerequisites: prerequisites,
  recommended: recommended,
);

const String _root = 'py:sys';

/// 「今天」。队列是纯函数，时钟由入参给 —— 写成定值，用例才不会随跑测试那天漂移。
final DateTime _today = DateTime.utc(2026, 10, 28, 12);

/// 造一条 `SrsState`。只有 `due` 与判据相关，其余字段给能过校验的最小值 ——
/// 填真数值会让人误以为本文件在验 FSRS。
SrsState _due(String itemId, DateTime due) => SrsState(
  itemId: itemId,
  difficulty: 5,
  stability: 3.173,
  lastReviewAt: due,
  due: due,
  failCount: 0,
  reps: 1,
  skipStreak: 0,
);

void main() {
  group('buildSessionQueue', () {
    test('TC-STEP-004 前置未过 ⇒ 后继不进队列（前沿只看 required）（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(prerequisites: <(String, String)>[('py:a', 'py:b')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
        'py:c',
      ]);
    });

    test('TC-STEP-005 前置已过 ⇒ 后继入队，且自己已被排除（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(prerequisites: <(String, String)>[('py:a', 'py:b')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
      );
      // 层号：c 与 a 同为 0，b 在 a 后面 ⇒ 排序结果是 c 先、b 后。
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:c',
        'py:b',
      ]);
    });

    test('TC-STEP-006 recommended 不构成门槛（ADR-0005 决策 4）（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(recommended: <(String, String)>[('py:a', 'py:b')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
      );
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        contains('py:b'),
      );
    });

    test('TC-STEP-007 没有步骤的项不入队 —— 进去会立刻「完成」，把分母灌水（无 SPEC：队列滤掉无步骤项是本批的实现约束，STEP 卷未裁定）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(withoutSteps: <String>{'py:b'}),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
        'py:c',
      ]);
    });

    test('TC-STEP-008 链式前置只露出最上游那一项（SPEC-STEP-003）', () {
      // c 依赖 b，b 依赖 a ⇒ 队列里 a 必须在 b 前、b 在 c 前。
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(
          prerequisites: <(String, String)>[('py:a', 'py:b'), ('py:b', 'py:c')],
        ),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
      ]);
    });

    test(
      'TC-STEP-009 队列带上步骤与判据非空标记，界面不必再读包（无 SPEC：队列自带步骤是会话层取数约定，STEP 卷未裁定）',
      () {
        final SessionQueue queue = buildSessionQueue(
          pack: _pack(),
          subtreeRoot: _root,
          now: _today,
          passed: const <String>{},
        );
        final QueueItem first = queue.items.first;
        expect(first.steps.length, 2);
        expect(first.hasCriteria, isTrue);
        expect(queue.length, 3);
      },
    );

    test('TC-STEP-010 包内没写时长时，总量记 0 且 timedItems 为 0（不是「0 分钟」）（无 SPEC：时长缺失的呈现方式未入册）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
      );
      expect(queue.knownMinutes, 0);
      expect(queue.timedItems, 0);
    });
  });

  group('缺口回补入队（SPEC-STEP-021）', () {
    test('TC-STEP-048 缺口项排在新学项之前（SPEC-STEP-021）', () {
      // 无前置时 a / b / c 同为 0 层 ⇒ 本来按 id 排成 a、b、c；c 是缺口，要挪到最前。
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        gaps: const <String>{'py:c'},
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:c',
        'py:a',
        'py:b',
      ]);
      expect(queue.items.first.kind, QueueItemKind.gapFill);
      expect(queue.items[1].kind, QueueItemKind.newItem);
    });

    test('TC-STEP-049 已 item_passed 的缺口项仍进队列（SPEC-STEP-021）', () {
      // 已学过的项复习时连续未过 ⇒ 回补。`item_passed` 不可撤销，但可以回补。
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:c'},
        gaps: const <String>{'py:c'},
      );
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        contains('py:c'),
      );
    });

    test('TC-STEP-050 缺口项的前置没过也照样入队（SPEC-STEP-021）', () {
      // 缺口项自己往往就是别人的前置：挡住它等于永远修不好那个缺口。
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(prerequisites: <(String, String)>[('py:a', 'py:c')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        gaps: const <String>{'py:c'},
      );
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        contains('py:c'),
      );
    });

    test('TC-STEP-051 缺口项没有步骤 ⇒ 不入队、不计入缺口数（SPEC-STEP-021）', () {
      // 包升级删了正文、事件里还留着 id：这类缺口不清掉，「缺口 N 项」永远归不了零。
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(withoutSteps: <String>{'py:c'}),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        gaps: const <String>{'py:c'},
      );
      expect(queue.gapItems, 0);
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        isNot(contains('py:c')),
      );
    });

    test('TC-STEP-052 缺口集合里有包内不存在的 id ⇒ 不抛错、不入队（SPEC-STEP-021）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        gaps: const <String>{'py:not-in-pack'},
      );
      expect(queue.length, 3);
      expect(queue.gapItems, 0);
    });

    test('TC-STEP-053 新学计数不含缺口项，不重复计（SPEC-STEP-021）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        gaps: const <String>{'py:c'},
      );
      expect(queue.length, 3);
      expect(queue.gapItems, 1);
      expect(queue.newItems, 2);
    });
  });

  group('SRS 到期（复习池）', () {
    test('TC-STEP-059 学过且到期 ⇒ 进复习池；新学数不含它（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 1))),
        },
      );
      expect(queue.reviewItems, 1);
      expect(queue.newItems, 2);
      expect(queue.items.first.isReview, isTrue);
      expect(queue.items.first.nodeId, 'py:a');
    });

    test('TC-STEP-060 学过但没到期 ⇒ 不进队列，复习行也是 0（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.add(const Duration(days: 1))),
        },
      );
      // 刚到点不算「以后」：`due == now` 到期（`!isAfter`），所以这条特意给未来一天。
      expect(queue.reviewItems, 0);
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:b',
        'py:c',
      ]);
    });

    test(
      'TC-STEP-061 `due` 恰等于 `now` 也算到期（边界闭区间，不是「过了才复习」）（SPEC-STEP-003）',
      () {
        final SessionQueue queue = buildSessionQueue(
          pack: _pack(),
          subtreeRoot: _root,
          now: _today,
          passed: const <String>{'py:a'},
          srs: <String, SrsState>{'py:a': _due('py:a', _today)},
        );
        expect(queue.reviewItems, 1);
      },
    );

    test('TC-STEP-062 复习不看前置：前置没过的已学项照样进（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        // c 是 a 的 required 前置，而 c 没学过。
        pack: _pack(prerequisites: <(String, String)>[('py:c', 'py:a')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 2))),
        },
      );
      expect(queue.reviewItems, 1);
      expect(queue.items.first.nodeId, 'py:a');
    });

    test('TC-STEP-063 没学过的项即便有条目也不进复习 —— 那是绕开前置的后门（无 SPEC：STEP-003 未写「复习只收已学」，本批按「保持」词义定）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(prerequisites: <(String, String)>[('py:c', 'py:a')]),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 2))),
        },
      );
      // a 没学过、前置 c 也没过 ⇒ 三条源都不收它。
      expect(queue.reviewItems, 0);
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        isNot(contains('py:a')),
      );
    });

    test('TC-STEP-064 缺口 ∩ 到期 ⇒ 只记缺口，一项不进两次队（SPEC-STEP-021）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        gaps: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 3))),
        },
      );
      expect(queue.gapItems, 1);
      expect(queue.reviewItems, 0);
      expect(
        queue.items.where((QueueItem item) => item.nodeId == 'py:a').length,
        1,
      );
      expect(queue.items.first.kind, QueueItemKind.gapFill);
    });

    test('TC-STEP-065 三类的和等于队列长度，没有一项被数两次（无 SPEC：计数口径是本批实现约束）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        gaps: const <String>{'py:c'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 3))),
        },
      );
      expect(queue.gapItems + queue.reviewItems + queue.newItems, queue.length);
      expect(queue.gapItems, 1);
      expect(queue.reviewItems, 1);
      expect(queue.newItems, 1);
    });

    test('TC-STEP-066 排序：缺口 → 复习（逾期久者先）→ 新学（SPEC-STEP-004）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a', 'py:b'},
        gaps: const <String>{'py:c'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 5))),
          'py:b': _due('py:b', _today.subtract(const Duration(days: 1))),
        },
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:c',
        'py:a',
        'py:b',
      ]);
    });

    test('TC-STEP-067 同逾期天数按 due 升序 —— 只差几小时的两项 `.inDays` 相同（无 SPEC：STEP-004 只说「逾期天数降序」，同数如何排未裁定）', () {
      final DateTime morning = DateTime.utc(2026, 10, 25, 8);
      final DateTime evening = DateTime.utc(2026, 10, 25, 20);
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        // 故意让 b 的 id 更大、due 更晚，两条判据指向同一答案才验得出稳定序。
        // `py:c` 也标已学（但不给条目）—— 否则它会作为新学项排在最后，干扰断言。
        passed: const <String>{'py:a', 'py:b', 'py:c'},
        srs: <String, SrsState>{
          'py:b': _due('py:b', evening),
          'py:a': _due('py:a', morning),
        },
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
        'py:b',
      ]);
    });

    test('TC-STEP-068 到期的项没有步骤 ⇒ 不入队、不计入复习数（无 SPEC：队列滤掉无步骤项是本批实现约束）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(withoutSteps: <String>{'py:a'}),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 2))),
        },
      );
      expect(queue.reviewItems, 0);
      expect(queue.length, 2);
    });

    test('TC-STEP-079 复习额度用完 ⇒ 只截池尾，逾期最久的先进队（SPEC-STEP-004）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a', 'py:b', 'py:c'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 5))),
          'py:b': _due('py:b', _today.subtract(const Duration(days: 3))),
          'py:c': _due('py:c', _today.subtract(const Duration(days: 1))),
        },
        reviewAllowance: 2,
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
        'py:b',
      ]);
      expect(queue.reviewItems, 2);
      expect(queue.reviewDeferred, 1);
      expect(
        queue.items.map((QueueItem item) => item.nodeId),
        isNot(contains('py:c')),
      );
    });

    test('TC-STEP-080 新学额度用完 ⇒ 按体系序取前几项，其余顺延（SPEC-STEP-028）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{},
        newAllowance: 1,
      );
      expect(queue.items.map((QueueItem item) => item.nodeId), <String>[
        'py:a',
      ]);
      expect(queue.newItems, 1);
      expect(queue.newDeferred, 2);
    });

    test('TC-STEP-081 额度 0 ⇒ 该池一条都排不进，且被挡的项数如实记下（SPEC-STEP-028）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a', 'py:b', 'py:c'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 2))),
          'py:b': _due('py:b', _today.subtract(const Duration(days: 2))),
        },
        reviewAllowance: 0,
      );
      expect(queue.reviewItems, 0);
      expect(queue.reviewDeferred, 2);
      expect(queue.items, isEmpty);
      // 队列空但被挡过 —— 界面据此说「另有两项排到明天」，而不是「都学过了」。
      expect(queue.deferredTotal, 2);
    });

    test('TC-STEP-082 缺口不受额度约束 —— 额度管两个池子，缺口是第三条源（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:c'},
        gaps: const <String>{'py:c'},
        reviewAllowance: 0,
      );
      expect(queue.gapItems, 1);
      expect(queue.items.first.nodeId, 'py:c');
      expect(queue.items.first.kind, QueueItemKind.gapFill);
      // 复习额度是 0，但没有到期项，所以一条也没被挡 —— 缺口本身不吃额度。
      expect(queue.reviewDeferred, 0);
    });

    test('TC-STEP-083 两池各削各的：复习额度用完不影响新学（SPEC-STEP-004）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(),
        subtreeRoot: _root,
        now: _today,
        passed: const <String>{'py:a'},
        srs: <String, SrsState>{
          'py:a': _due('py:a', _today.subtract(const Duration(days: 2))),
        },
        reviewAllowance: 0,
        newAllowance: 2,
      );
      expect(queue.reviewItems, 0);
      expect(queue.reviewDeferred, 1);
      expect(queue.newItems, 2);
      expect(queue.newDeferred, 0);
    });

    test(
      'TC-STEP-084 额度为 null ⇒ 不截断，被挡数恒为 0（无 SPEC：STEP-028 只说上限，未写「不限」这种入参）',
      () {
        final SessionQueue queue = buildSessionQueue(
          pack: _pack(),
          subtreeRoot: _root,
          now: _today,
          passed: const <String>{},
        );
        expect(queue.newItems, 3);
        expect(queue.newDeferred, 0);
        expect(queue.deferredTotal, 0);
      },
    );
  });
}
