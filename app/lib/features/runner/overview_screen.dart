/// 今日概览页 —— ④ 修习的入口（`SPEC-STEP-016`）。
///
/// ## 它是空间级的
///
/// 一个包一个概览：复习 N 项 / 新学 M 项 / 今日预计时长 / 一个「开始」。切包就是
/// 切概览，没有「跨空间总概览」这一层 —— `v0.1.0` 纯本地，多个包就是多个空间，
/// 合成一页只会得到一页既不属于谁、又替谁算了配额的数。
///
/// ## 只显示有来源的行
///
/// 三条入队源都已接通（见 `session_queue.dart` 文件头），所以这一页按队列实算出
/// 三行：「缺口 K 项」「复习 R 项」「新学 M 项」，前两行**为 0 时整行不出现** ——
/// 一个恒为 0 的「复习 0 项」与「今天确实没有要复习的」在屏幕上长得一模一样，
/// 而后者是假话。
///
/// 复习行**不带明细**：复习项逐项跑，点不点名字不改怎么学；而这一页唯一的动作是
/// 「开始」，多一行会把按钮往下挤。缺口行带明细是另一回事 —— 缺口要解释「什么在
/// 卡住后续」。
///
/// ## 范围根
///
/// 取本包**第一个** `system` 槽位节点（按 slug 排序，与空间页的分组同序）。
/// 一个包声明多个 `system` 时这里只覆盖第一个 —— 如实写在界面上，不假装全都算了。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/entities/node.dart';
import '../../core/enums.dart';
import '../../core/events/event.dart';
import '../../core/events/event_store.dart';
import '../../core/events/fold.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/session/daily_quota.dart';
import '../../core/session/gaps.dart';
import '../../core/session/session.dart';
import '../../core/session/session_queue.dart';
import 'runner_screen.dart';

/// 概览页在「缺口 N 项」下面点名几项。超出部分只说「还有 N 项」。
///
/// 写成具名常量而不是内联 `3`：这一页虽在 `features/`（`R2` 不管 UI 字面量），
/// 但「点名几项」是会改的口径，散在字符串拼接里下次没人找得到。
const int _gapNamesShown = 3;

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.content,
    this.eventStore,
    this.now,
  });

  final PackContent content;

  /// 事件存储。`null` = 没接（测试 / 取不到数据目录）—— 此时队列按「什么都没学过」
  /// 算，但**开始不了**，因为推进要写事件而写不进去。
  final EventStore? eventStore;

  /// 「今天」。`null` = 取当下 —— 界面在生产里就该读真时钟，而 Widget 测试要注入
  /// 定值：否则「到期 / 未到期」跟着跑测试的那一天漂移，用例会时红时绿。
  final DateTime? now;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = true;
  String? _problem;
  SessionQueue? _queue;
  Map<String, int> _cursors = <String, int>{};
  String? _rootId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? root = _scopeRoot(widget.content);
    final EventStore? store = widget.eventStore;
    final DateTime at = widget.now ?? DateTime.now();
    // 日界跟着「今天」那个时刻的时区走：测试注入了定值时钟，日界也随之可控。
    final Duration utcOffset = at.timeZoneOffset;
    if (root == null) {
      setState(() {
        _loading = false;
        _rootId = null;
      });
      return;
    }
    if (store == null) {
      // 存储没接不等于「读不出来」：队列按「什么都没学过」算得出来，只是开始
      // 不了（推进要写事件）。这里**不置 `_problem`** —— 置了就会跳到错误态，
      // 连「有新学 N 项」都看不见。
      setState(() {
        _loading = false;
        _rootId = root;
        _queue = buildSessionQueue(
          pack: widget.content,
          subtreeRoot: root,
          passed: const <String>{},
          now: at,
          reviewAllowance: quotaRemaining(cap: reviewPoolCap, used: 0),
          newAllowance: quotaRemaining(cap: newPoolCap, used: 0),
        );
      });
      return;
    }
    try {
      final List<Event> events = await store
          .readAll(spaceId: widget.content.pack.pluginId)
          .toList();
      if (!mounted) {
        return;
      }
      final FoldedState folded = fold(
        events,
        spaceId: widget.content.pack.pluginId,
        userId: localDefaultUserId,
      );
      // 当日用量只由事件决定 —— 与 `fold` 吃同一份日志，不另读一份计数表。
      final DailyQuotaUsage usage = dailyQuotaUsage(
        events: events,
        asOf: at,
        utcOffset: utcOffset,
      );
      setState(() {
        _loading = false;
        _rootId = root;
        _cursors = folded.cursors;
        _queue = buildSessionQueue(
          pack: widget.content,
          subtreeRoot: root,
          passed: folded.passed,
          now: at,
          gaps: gapItemIds(folded),
          srs: folded.srs,
          reviewAllowance: quotaRemaining(
            cap: reviewPoolCap,
            used: usage.reviewed,
          ),
          newAllowance: quotaRemaining(cap: newPoolCap, used: usage.learned),
        );
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _rootId = root;
        _problem = '事件日志读不出来：${error.message}';
      });
    }
  }

  /// 缺口行的明细：点名至多 `_gapNamesShown` 项，超出只说「还有 N 项」。
  ///
  /// 为什么不在概览页列全：这一页的职责是「今天做不做、从哪开始」，不是清单。
  /// 全列会把唯一的动作「开始」挤到屏幕外 —— 一个只有信息没有入口的页面。
  static String _gapDetail(SessionQueue queue) {
    final List<String> names = <String>[
      for (final QueueItem item in queue.items)
        if (item.isGapFill) item.name,
    ];
    if (names.length <= _gapNamesShown) {
      return names.join('、');
    }
    final int rest = names.length - _gapNamesShown;
    return '${names.take(_gapNamesShown).join('、')}… 还有 $rest 项';
  }

  /// 被额度挡下的项怎么说。
  ///
  /// 只说排期，不说欠账 —— `SPEC-STEP-030` 不许出现「欠」「逾期」「缺」这类字，
  /// 也不许着警示色，所以这行落在 `bodySmall`，与「会话到 N 分钟收尾」同一档。
  static String _deferredLine(int count) => '另有 $count 项排到明天';

  /// 本包第一个 `system` 槽位节点。`null` = 这一包没有可学的入口。
  static String? _scopeRoot(PackContent content) {
    final List<Node> systems =
        content.nodes
            .where((Node node) => node.levelSlot == LevelSlot.system)
            .toList()
          ..sort((Node a, Node b) => a.slug.compareTo(b.slug));
    return systems.isEmpty ? null : systems.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final SessionQueue? queue = _queue;
    if (_rootId == null) {
      return _centered(
        text,
        title: '这一包没有可学的范围',
        detail: '它没有声明 `system` 槽位节点 —— 概览页按这个词定位范围根。',
      );
    }
    if (_problem != null) {
      return _centered(text, title: '暂不可用', detail: _problem!);
    }
    // 「今天排满了」与「本来就没有」必须分开：两种情况下列表都是空的，但前者
    // 是被额度挡住的 —— 说成「都学过了」是假话。
    if (queue == null || (queue.isEmpty && queue.deferredTotal == 0)) {
      return _centered(
        text,
        title: '这个范围里没有可学的项',
        detail: '要么都学过了，要么前置还没过 —— 前置不过的项不进队列。',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 缺口排在「新学」之前，与队列顺序一致 —— 界面上先说哪一类，用户
          // 进去就先做哪一类。
          if (queue.gapItems > 0) ...<Widget>[
            Text(
              '缺口 ${queue.gapItems} 项（回补）',
              key: const Key('overview-gaps'),
              style: text.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _gapDetail(queue),
              key: const Key('overview-gap-detail'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
          if (queue.reviewItems > 0) ...<Widget>[
            Text(
              '复习 ${queue.reviewItems} 项',
              key: const Key('overview-reviews'),
              style: text.headlineMedium,
            ),
            const SizedBox(height: 8),
          ],
          if (queue.reviewDeferred > 0) ...<Widget>[
            Text(
              _deferredLine(queue.reviewDeferred),
              key: const Key('overview-reviews-deferred'),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          // 新学行照旧「0 也出」；只有额度用满、一条都没排进来时才整行不出 ——
          // 那时下面那行灰字已经说明了原因，再写「新学 0 项」只会读成「今天没事」。
          if (queue.newItems > 0 || queue.newDeferred == 0) ...<Widget>[
            Text('新学 ${queue.newItems} 项', style: text.headlineMedium),
            const SizedBox(height: 8),
          ],
          if (queue.newDeferred > 0) ...<Widget>[
            Text(
              _deferredLine(queue.newDeferred),
              key: const Key('overview-new-deferred'),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            // 一项时长都没写时不留「预计 0 分钟」这种读数 —— 那是把「不知道」
            // 显示成了「不用花时间」。额度用满时也不说「时长未知」：包内写了，
            // 只是今天排不进来。措辞只说「今天排到这里」，不带欠账色彩
            // （`SPEC-STEP-030`：不得出现「欠」「逾期」，不得着警示色）。
            queue.isEmpty && queue.deferredTotal > 0
                ? '今天的名额已用完'
                : queue.timedItems == 0
                ? '预计时长未知（包内未写）'
                : '今日预计 ${queue.knownMinutes} 分钟'
                      '${queue.timedItems == queue.length ? '' : '（${queue.length - queue.timedItems} 项未写时长）'}',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '会话到 ${defaultSessionBudget.inMinutes} 分钟收尾，'
            '不切断进行中的项',
            style: text.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('overview-start'),
              // 队列空的时候没有可推进的项：额度用满那种「空」也不能点进去，
              // 进去只会立刻收尾。
              onPressed: widget.eventStore == null || queue.isEmpty
                  ? null
                  : () => _start(queue),
              child: const Text('开始'),
            ),
          ),
          if (widget.eventStore == null) ...<Widget>[
            const SizedBox(height: 8),
            Text('事件存储未接入，开始不了 —— 推进要写事件', style: text.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _centered(
    TextTheme text, {
    required String title,
    required String detail,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(detail, style: text.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _start(SessionQueue queue) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RunnerScreen(
          content: widget.content,
          queue: queue,
          cursors: _cursors,
          eventStore: widget.eventStore,
        ),
      ),
    );
  }
}
