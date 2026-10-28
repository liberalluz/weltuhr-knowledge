/// 会话推进器（`SPEC-STEP-005` / `009` / `011`）。
///
/// 这里只验**位置**：游标恢复、前进不跨项、回退不产生状态、预算只在项边界问。
/// 「写不写事件」不在本文件 —— 那是界面那一层的事，用界面用例验才有意义。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/session/session.dart';
import 'package:project_knowledge/core/session/session_queue.dart';

const List<EntryStep> _threeSteps = <EntryStep>[
  EntryStep(operator: ExecutionOperator.read, instruction: '读'),
  EntryStep(operator: ExecutionOperator.example, instruction: '看'),
  EntryStep(operator: ExecutionOperator.recall, instruction: '忆'),
];

QueueItem _item(String id, {int steps = 3}) => QueueItem(
  nodeId: id,
  name: id,
  estMinutes: 5,
  steps: _threeSteps.take(steps).toList(growable: false),
  hasCriteria: true,
);

SessionQueue _queue(List<QueueItem> items) =>
    SessionQueue(subtreeRoot: 'py:sys', items: items);

final DateTime _t0 = DateTime.utc(2026, 10, 28, 3);

SessionRun _run(
  List<QueueItem> items, {
  Map<String, int> cursors = const <String, int>{},
  DateTime Function()? now,
}) => SessionRun(
  queue: _queue(items),
  cursors: cursors,
  startedAt: _t0,
  now: now,
);

void main() {
  group('SessionRun', () {
    test('TC-STEP-011 游标来自 fold：已完成第 0 步 ⇒ 从第 1 步接上（SPEC-STEP-009）', () {
      final SessionRun run = _run(
        <QueueItem>[_item('py:a')],
        cursors: const <String, int>{'py:a': 1},
      );
      expect(run.stepIndex, 1);
      expect(run.step?.instruction, '看');
    });

    test('TC-STEP-012 游标超出步数时夹到最后一格（包升级把序列改短）（SPEC-STEP-009）', () {
      final SessionRun run = _run(
        <QueueItem>[_item('py:a')],
        cursors: const <String, int>{'py:a': 9},
      );
      expect(run.stepIndex, 2);
      expect(run.isLastStep, isTrue);
    });

    test('TC-STEP-013 nextStep 不跨项；最后一步再调没有效果（SPEC-STEP-010）', () {
      final SessionRun run = _run(<QueueItem>[_item('py:a'), _item('py:b')]);
      run.nextStep();
      run.nextStep();
      expect(run.stepIndex, 2);
      expect(run.itemIndex, 0);
      run.nextStep();
      expect(run.itemIndex, 0);
      expect(run.stepIndex, 2);
    });

    test('TC-STEP-014 back 在第 0 步无效，之后每退一格都返回 true（SPEC-STEP-011）', () {
      final SessionRun run = _run(<QueueItem>[_item('py:a')]);
      expect(run.back(), isFalse);
      run.nextStep();
      expect(run.back(), isTrue);
      expect(run.stepIndex, 0);
    });

    test('TC-STEP-015 nextItem 切到下一项，并按游标决定它的起点（SPEC-STEP-009）', () {
      final SessionRun run = _run(
        <QueueItem>[_item('py:a'), _item('py:b')],
        cursors: const <String, int>{'py:b': 2},
      );
      run.nextItem();
      expect(run.itemIndex, 1);
      expect(run.stepIndex, 2);
    });

    test('TC-STEP-016 预算只在项边界判：项内 25 分钟到了也照走（SPEC-STEP-005）', () {
      DateTime now = _t0;
      final SessionRun run = _run(<QueueItem>[
        _item('py:a'),
        _item('py:b'),
      ], now: () => now);
      now = _t0.add(const Duration(minutes: 40));
      // 项内照走 —— `budgetExhausted` 不影响 `nextStep`。
      run.nextStep();
      expect(run.stepIndex, 1);
      // 到项边界才问：此时该收尾。
      expect(run.shouldContinue(), isFalse);
    });

    test('TC-STEP-017 未过重来：restartItem 回到第 0 步，项不变（SPEC-STEP-021）', () {
      final SessionRun run = _run(<QueueItem>[_item('py:a'), _item('py:b')]);
      run.nextStep();
      run.nextStep();
      run.restartItem();
      expect(run.itemIndex, 0);
      expect(run.stepIndex, 0);
    });

    test('TC-STEP-018 空队列：立刻结束，remainingItems 为 0（SPEC-STEP-006）', () {
      final SessionRun run = _run(const <QueueItem>[]);
      expect(run.isFinished, isTrue);
      expect(run.item, isNull);
      expect(run.step, isNull);
      expect(run.remainingItems, 0);
      expect(run.shouldContinue(), isFalse);
    });

    test('TC-STEP-019 remainingItems 含当前项（SPEC-STEP-006）', () {
      final SessionRun run = _run(<QueueItem>[
        _item('py:a'),
        _item('py:b'),
        _item('py:c'),
      ]);
      expect(run.remainingItems, 3);
      run.nextItem();
      expect(run.remainingItems, 2);
    });
  });
}
