/// 一次修习会话的推进器（`SPEC-STEP-005` / `009` / `010` / `011`）。
///
/// ## 游标不入库
///
/// 当前走到第几项、第几步**不作为状态存下来**。步内进度由 `fold` 从
/// `step_completed` 算出（`FoldedState.cursors`：某项已完成的步数 = 下一步的位置），
/// 本类只是把它读进来、在内存里往前走。`SPEC-STEP-009` 的验收就是「检索 schema，
/// 无 `SessionCursor`」—— 建一张表来存它，事件流与那张表就有了两个事实源。
///
/// ## 回退不写事件
///
/// 后退只是把内存里的下标减一。写一条「退回」事件会让回退本身产生状态，
/// 于是 `fold` 要额外知道「退到哪一步之前」；而回退的语义就是「当作没走那一步」，
/// 它本来就不该留下痕迹（`SPEC-STEP-011` 的验收：退回去再前进，事件数不变）。
///
/// ## 到点不切断进行中的项
///
/// [budgetExhausted] 只在**项边界**被问一次（`SPEC-STEP-005`）。项内每一格
/// 停下来问，会在半途中把人赶出会话 —— 那样既不能算完成也不能算未学，
/// 掌握度无处记账。
library;

import '../constants.dart';
import '../entities/entry.dart';
import 'session_queue.dart';

/// 默认会话预算（`C-05`）。分钟数取 `constants.dart` 的 `sessionBudgetMinutes` ——
/// 这个数在概览页与推进器两处出现，写第二遍就会分叉。
const Duration defaultSessionBudget = Duration(minutes: sessionBudgetMinutes);

/// 一次会话。队列入、位置出；不碰存储、不碰事件。
class SessionRun {
  SessionRun({
    required SessionQueue queue,
    required Map<String, int> cursors,
    required this.startedAt,
    DateTime Function()? now,
    this.budget = defaultSessionBudget,
  }) : _queue = queue,
       _cursors = cursors,
       _now = now ?? DateTime.now,
       _stepIndex = _resumeStep(queue, cursors) {
    if (queue.isEmpty) {
      _itemIndex = -1;
      _stepIndex = 0;
    }
  }

  final SessionQueue _queue;

  /// `fold` 算出的步内游标。读进来之后本类不再回写它 —— 回写就等于在这里
  /// 造第二份进度。
  final Map<String, int> _cursors;

  /// 会话开始时刻。预算从它算起。
  final DateTime startedAt;

  final DateTime Function() _now;
  final Duration budget;

  int _itemIndex = 0;
  int _stepIndex;

  /// 第几项（0 起）。队列空时为 `-1`。
  int get itemIndex => _itemIndex;

  /// 当前项的第几步（0 起）。
  int get stepIndex => _stepIndex;

  SessionQueue get queue => _queue;

  bool get isFinished => _itemIndex < 0 || _itemIndex >= _queue.items.length;

  QueueItem? get item => isFinished ? null : _queue.items[_itemIndex];

  /// 当前这一步。项没有步骤时返回 `null` —— 入队时已滤掉无步骤项，这里是兜底。
  EntryStep? get step {
    final QueueItem? current = item;
    if (current == null || _stepIndex >= current.steps.length) {
      return null;
    }
    return current.steps[_stepIndex];
  }

  /// 当前项是否只剩最后一步。走到这格的下一步，就是项边界。
  bool get isLastStep {
    final QueueItem? current = item;
    return current != null && _stepIndex == current.steps.length - 1;
  }

  /// 当前项的步内进度，0 起、用于位置条：「第 i/n 步」。
  int get stepCount => item?.steps.length ?? 0;

  /// 预算是否已用尽。**只在项边界问**（见文件头）。
  bool get budgetExhausted => _now().difference(startedAt) >= budget;

  /// 项边界上是否还该继续下一项。
  ///
  /// 队列走完 ⇒ 不继续；预算用尽 ⇒ 不继续。两者都不看「已学了几项」——
  /// 按项数收尾会让「单词 30 秒」与「异步范式 40 分钟」被同等对待。
  bool shouldContinue() => !isFinished && !budgetExhausted;

  /// 前进一格。**不跨项** —— 最后一步再调用它没有效果，调用方应当先收尾该项，
  /// 再调 [nextItem]。这样「项完成」与「步完成」在代码里也是两件事。
  void nextStep() {
    if (isFinished || isLastStep) {
      return;
    }
    _stepIndex += 1;
  }

  /// 后退一格。已在第 0 步时没有效果（界面据此禁用回退按钮）。
  bool back() {
    if (isFinished || _stepIndex == 0) {
      return false;
    }
    _stepIndex -= 1;
    return true;
  }

  /// 未过：不前进，停在这一项的第 0 步重来（`SPEC-STEP-021` 的「没学会」出口）。
  ///
  /// **不写事件** —— 退回去本身不是事实，何况 `fold` 的游标来自 `step_completed`，
  /// 它记的是「已完成第几步」，没有「退回去」这个动作可记。
  void restartItem() {
    if (isFinished) {
      return;
    }
    _stepIndex = 0;
  }

  /// 收尾当前项，走到下一项的第一格。
  ///
  /// 下一项的起点仍按游标算 —— 同一次会话里重进一个「学到一半」的项是正常的
  /// （队列里每一项都可能不是第一次进）。
  void nextItem() {
    if (isFinished) {
      return;
    }
    _itemIndex += 1;
    _stepIndex = _itemIndex < _queue.items.length
        ? _resumeStepFor(_queue.items[_itemIndex])
        : 0;
  }

  /// 会话里还没走到的项数（含当前项）。概览页用它显示「还剩 N 项」。
  int get remainingItems => isFinished ? 0 : _queue.items.length - _itemIndex;

  int _resumeStepFor(QueueItem item) {
    final int done = _cursors[item.nodeId] ?? 0;
    if (done <= 0) {
      return 0;
    }
    // 游标可能大于当前步骤数：步骤序列被包升级改短了。**不夹到底**会让位置条
    // 显示「第 6/5 步」，夹到最后一格又会让那一格重跑一次。取「最后一步」是
    // 这里唯一不撒谎的选择 —— 它至少停在一个真实存在的步骤上。
    return done >= item.steps.length ? item.steps.length - 1 : done;
  }

  static int _resumeStep(SessionQueue queue, Map<String, int> cursors) {
    if (queue.items.isEmpty) {
      return 0;
    }
    final QueueItem first = queue.items.first;
    final int done = cursors[first.nodeId] ?? 0;
    if (done <= 0) {
      return 0;
    }
    return done >= first.steps.length ? first.steps.length - 1 : done;
  }
}
