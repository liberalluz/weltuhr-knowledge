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
/// 当前接了两条入队源：**体系序**与**缺口回补**（见 `session_queue.dart` 文件头）。
/// 所以这一页出「新学 M 项」与（有缺口时）「缺口 K 项」两行；「复习」那一行仍不
/// 出现 —— 一个恒为 0 的「复习 0 项」与「今天确实没有要复习的」在屏幕上长得一模
/// 一样，而后者是假话。等 `B6` 把 `due` 折出来再补那一行。
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
  const OverviewScreen({super.key, required this.content, this.eventStore});

  final PackContent content;

  /// 事件存储。`null` = 没接（测试 / 取不到数据目录）—— 此时队列按「什么都没学过」
  /// 算，但**开始不了**，因为推进要写事件而写不进去。
  final EventStore? eventStore;

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
      setState(() {
        _loading = false;
        _rootId = root;
        _cursors = folded.cursors;
        _queue = buildSessionQueue(
          pack: widget.content,
          subtreeRoot: root,
          passed: folded.passed,
          gaps: gapItemIds(folded),
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
    if (queue == null || queue.isEmpty) {
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
          Text('新学 ${queue.newItems} 项', style: text.headlineMedium),
          const SizedBox(height: 8),
          Text(
            // 一项时长都没写时不留「预计 0 分钟」这种读数 —— 那是把「不知道」
            // 显示成了「不用花时间」。
            queue.timedItems == 0
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
              onPressed: widget.eventStore == null ? null : () => _start(queue),
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
