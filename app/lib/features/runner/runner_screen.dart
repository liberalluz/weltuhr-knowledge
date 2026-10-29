/// 修习会话界面 —— 全屏沉浸、一屏一步（`SPEC-STEP-008` / `010` / `011` / `015`）。
///
/// ## 谁写事件
///
/// 本页是唯一写学习事件的地方：前进写 `step_completed`、验收写 `item_graded`、
/// 首次合格写 `item_passed`。`session.dart` 只算位置，`session_events.dart` 只造
/// 对象 —— 两边都不碰存储，这样「什么时候算真的发生了」只有这一处判断。
///
/// ## 回退不写事件
///
/// 回退只把内存里的下标减一（`SessionRun.back`）。它不产生事件，因此也不会
/// 在 `fold` 里留下痕迹 —— 回退的语义就是「当作没走那一步」。
///
/// ## ⑤ 只给两档
///
/// 不给「熟练」：本页没有实现脚手架追踪之外的证据链，而 `SPEC-STEP-022` 说
/// 「看过答案最高只能合格」。两档 + `scaffold` 字段同时落盘，是自洽的最小形态；
/// 三档与 FSRS 映射归 `B6`。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/entities/entry.dart';
import '../../core/entities/state.dart';
import '../../core/enums.dart';
import '../../core/events/event.dart';
import '../../core/events/event_store.dart';
import '../../core/events/hlc_clock.dart';
import '../../core/events/journal_event_store.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/quant/mastery.dart';
import '../../core/session/session.dart';
import '../../core/session/session_events.dart';
import '../../core/session/session_queue.dart';
import '../../core/srs/advance.dart';
import 'step_views.dart';

class RunnerScreen extends StatefulWidget {
  const RunnerScreen({
    super.key,
    required this.content,
    required this.queue,
    required this.cursors,
    required this.srs,
    required this.graduated,
    this.eventStore,
  });

  final PackContent content;
  final SessionQueue queue;

  /// `fold` 算出的步内游标。进会话时读一次，之后本页不再回写 ——
  /// 回写就等于在这里造第二份进度。
  final Map<String, int> cursors;

  /// `fold` 算出的记忆状态。判分后要凭「判分前的 `S`」推「判分后的 `S`」，
  /// 才能决定写不写 `graduated`；没有它就等于把每次判分都当首次评分。
  final Map<String, SrsState> srs;

  /// `fold` 算出的已毕业集合。**已毕业的项不再写第二条 `graduated`** ——
  /// 那条事件是状态转换，不是每次达标的记录。
  final Set<String> graduated;

  final EventStore? eventStore;

  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen> {
  /// 每次新建：`HlcClock` 的 `counter` 是进程内单调量，跨页共用一个会让
  /// 「同一毫秒」的两条事件排序依赖页面切换顺序（`tree_screen.dart` 同口径）。
  final HlcClock _clock = HlcClock(deviceId: localDeviceId);

  late final SessionRun _run = SessionRun(
    queue: widget.queue,
    cursors: widget.cursors,
    startedAt: DateTime.now(),
  );

  final TextEditingController _input = TextEditingController();

  bool _busy = false;

  /// 是否已进入 ⑤。进入之后主按钮换成「合格 / 未过」。
  bool _grading = false;

  /// 是否已点开参考答案。它决定 `scaffold` 落 `answer` 还是 `none`。
  bool _answerShown = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QueueItem? item = _run.item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('这一轮没有要学的项')),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(context, item),
            Expanded(
              child: _grading ? _gradeBody(context, item) : _stepBody(item),
            ),
            _bottomBar(context, item),
          ],
        ),
      ),
    );
  }

  /// 一条细位置条（`SPEC-STEP-008`：不放大标题、不给返回键抢注意力）。
  Widget _topBar(BuildContext context, QueueItem item) {
    final TextTheme text = Theme.of(context).textTheme;
    final int total = item.steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '结束会话',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                key: const Key('runner-progress'),
                minHeight: 4,
                value: _grading ? 1 : (_run.stepIndex + 1) / total,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _grading ? '验收' : '第 ${_run.stepIndex + 1}/$total 步',
            key: const Key('runner-position'),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _stepBody(QueueItem item) {
    final EntryStep? step = _run.step;
    if (step == null) {
      return const Center(child: Text('这一步读不出来'));
    }
    final NodeEntry? entry = widget.content.entryOf(item.nodeId);
    if (entry == null) {
      return const Center(child: Text('这一项的正文不在包里'));
    }
    return StepBody(step: step, entry: entry, controller: _input);
  }

  /// ⑤ 的界面：题目 → 作答 → （可选）看参考答案。
  Widget _gradeBody(BuildContext context, QueueItem item) {
    final TextTheme text = Theme.of(context).textTheme;
    final NodeEntry? entry = widget.content.entryOf(item.nodeId);
    final List<QuizItem> quiz = entry?.quiz ?? const <QuizItem>[];
    return ListView(
      key: const Key('grade-body'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: <Widget>[
        Text('验收', style: text.titleMedium),
        const SizedBox(height: 12),
        for (final QuizItem question in quiz) ...<Widget>[
          Text(question.prompt, style: text.bodyLarge),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('grade-input'),
          controller: _input,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '先自己答，再对答案',
          ),
        ),
        const SizedBox(height: 12),
        if (!_answerShown)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('grade-show-answer'),
              onPressed: _busy
                  ? null
                  : () => setState(() => _answerShown = true),
              child: const Text('看参考答案'),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('参考答案', style: text.labelLarge),
                const SizedBox(height: 8),
                for (final QuizItem question in quiz)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(question.answer, style: text.bodyMedium),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, QueueItem item) {
    if (_grading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                key: const Key('grade-fail'),
                onPressed: _busy ? null : () => _grade(item, Grade.fail),
                child: const Text('未过'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('grade-pass'),
                onPressed: _busy ? null : () => _grade(item, Grade.pass),
                child: const Text('合格'),
              ),
            ),
          ],
        ),
      );
    }
    final EntryStep? step = _run.step;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: <Widget>[
          TextButton(
            key: const Key('runner-back'),
            onPressed: _busy || _run.stepIndex == 0
                ? null
                : () => setState(() => _run.back()),
            child: const Text('回退'),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('runner-next'),
            onPressed: _busy ? null : () => _completeStep(item),
            child: Text(step == null ? '下一步' : primaryLabelOf(step.operator)),
          ),
        ],
      ),
    );
  }

  /// 走完当前这一步：写事件 → 下一步；到最后一步就进 ⑤。
  Future<void> _completeStep(QueueItem item) async {
    final EntryStep? step = _run.step;
    if (step == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _append(
        buildStepCompleted(
          spaceId: widget.content.pack.pluginId,
          itemId: item.nodeId,
          stepIndex: _run.stepIndex,
          operator: step.operator,
          clock: _clock,
          now: DateTime.now(),
          userId: localDefaultUserId,
        ),
      );
      if (!mounted) {
        return;
      }
      if (_run.isLastStep) {
        if (item.hasCriteria) {
          // 最后一步走完即进 ⑤（`SPEC-STEP-015`：不给「稍后」）。
          setState(() {
            _input.clear();
            _answerShown = false;
            _grading = true;
          });
        } else {
          await _autoPass(item);
        }
      } else {
        setState(() {
          _run.nextStep();
          _input.clear();
        });
      }
    } on StateError catch (error) {
      _say(error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// 判据为空的打卡项：跳过 ⑤，直接按「合格」写两条。
  ///
  /// **仍然写 `item_graded`** —— `item_passed` 的 payload 必填 `gradedEventId`，
  /// 只写后者的话它没有落点，`fold` 的 `lastGrade` 也永远是空。
  Future<void> _autoPass(QueueItem item) async {
    try {
      // 同一批事件取同一时刻：先后顺序由 `hlc` 递增保证，不靠两次 `now()` 的
      // 相对大小（同一毫秒内两次调用可以相等，相等就没有顺序）。
      final DateTime now = DateTime.now();
      final Event graded = buildItemGraded(
        spaceId: widget.content.pack.pluginId,
        itemId: item.nodeId,
        score: Grade.pass,
        progressKind: ProgressKind.checked,
        checkin: true,
        scaffold: ScaffoldLevel.none,
        clock: _clock,
        now: now,
        userId: localDefaultUserId,
      );
      await _append(graded);
      await _append(
        buildItemPassed(
          spaceId: widget.content.pack.pluginId,
          itemId: item.nodeId,
          gradedEventId: graded.id,
          clock: _clock,
          now: now,
          userId: localDefaultUserId,
        ),
      );
      // 打卡项到此为止：`S` 冻结、永不毕业（`QUANT-007` / `N-05`），不写
      // `graduated`。
      if (!mounted) {
        return;
      }
      _advanceAfterPass();
    } on StateError catch (error) {
      _say(error.message);
    }
  }

  /// 判分之后判毕业：`S ≥ C-02` 即再写一条 `graduated`（`QUANT-009`：只看
  /// `S`，不加 `d` 下限）。
  ///
  /// **`S` 由 [advanceSrs] 算，与 `fold` 同一份** —— 各写一条递推就会出现两个
  /// `S`，而 `fold` 那份才是事实。
  ///
  /// 三条跳过条件，缺一条就会写出错的事件：
  /// - 打卡项：`S` 冻结、永不毕业（`N-05`）
  /// - 已毕业：`graduated` 是状态转换，不是每次达标的记录
  /// - 未达阈值
  Future<void> _maybeGraduate(QueueItem item, Grade score, DateTime now) async {
    if (!item.hasCriteria || widget.graduated.contains(item.nodeId)) {
      return;
    }
    final SrsState? previous = widget.srs[item.nodeId];
    final SrsAdvance next = advanceSrs(
      previous: previous == null
          ? null
          : (
              difficulty: previous.difficulty,
              stability: previous.stability,
              lastReviewAt: previous.lastReviewAt,
              reps: previous.reps,
            ),
      grade: score,
      at: now,
    );
    if (!reachedGraduation(next.stability)) {
      return;
    }
    await _append(
      buildGraduated(
        spaceId: widget.content.pack.pluginId,
        itemId: item.nodeId,
        sAtGraduation: next.stability,
        clock: _clock,
        now: now,
        userId: localDefaultUserId,
      ),
    );
  }

  /// 合格之后：进下一项；到点收尾（`SPEC-STEP-005`：只在项边界问）。
  void _advanceAfterPass() {
    setState(() {
      _grading = false;
      _answerShown = false;
      _input.clear();
      _run.nextItem();
    });
    if (!_run.shouldContinue()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _grade(QueueItem item, Grade score) async {
    setState(() => _busy = true);
    try {
      final DateTime now = DateTime.now();
      final ScaffoldLevel scaffold = _answerShown
          ? ScaffoldLevel.answer
          : ScaffoldLevel.none;
      final Event graded = buildItemGraded(
        spaceId: widget.content.pack.pluginId,
        itemId: item.nodeId,
        score: score,
        // 自评：判据由本人核对，系统没有可核验对象（`SPEC-STEP-019`）。
        // 这与「是不是打卡项」是两件事：有判据的项 `checkin` 为假，`S` 照常涨。
        progressKind: ProgressKind.checked,
        checkin: !item.hasCriteria,
        scaffold: scaffold,
        clock: _clock,
        now: now,
        userId: localDefaultUserId,
      );
      await _append(graded);
      if (score == Grade.pass) {
        await _append(
          buildItemPassed(
            spaceId: widget.content.pack.pluginId,
            itemId: item.nodeId,
            gradedEventId: graded.id,
            clock: _clock,
            now: now,
            userId: localDefaultUserId,
          ),
        );
      }
      await _maybeGraduate(item, score, now);
      if (!mounted) {
        return;
      }
      if (score == Grade.pass) {
        _advanceAfterPass();
      } else {
        // 没学会：不前进，留在这一项从头再来（`SPEC-STEP-021`）。
        setState(() {
          _grading = false;
          _answerShown = false;
          _input.clear();
          _run.restartItem();
        });
      }
    } on StateError catch (error) {
      _say(error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _append(Event event) async {
    final EventStore? store = widget.eventStore;
    if (store == null) {
      throw StateError('事件存储未接入，这一步没有落盘');
    }
    await store.append(event);
  }

  void _say(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
