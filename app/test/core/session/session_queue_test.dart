/// 队列构建（`SPEC-STEP-003` / `004`）：前沿、排除、排序。
///
/// 本笔只有「体系序」一条源，所以这里不验「三条源合成」—— 那条要等 SRS 到期
/// 与缺口回补接上（`B6` / 笔 2），现在写它只能写成恒真式。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
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

void main() {
  group('buildSessionQueue', () {
    test('TC-STEP-004 前置未过 ⇒ 后继不进队列（前沿只看 required）（SPEC-STEP-003）', () {
      final SessionQueue queue = buildSessionQueue(
        pack: _pack(prerequisites: <(String, String)>[('py:a', 'py:b')]),
        subtreeRoot: _root,
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
        passed: const <String>{},
      );
      expect(queue.knownMinutes, 0);
      expect(queue.timedItems, 0);
    });
  });
}
