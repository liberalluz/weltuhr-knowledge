/// 进展视图 —— 能力清单分区（`SPEC-QUANT-011`）。
///
/// `QUANT-011` 把进展视图定为**两个分区**，本文件只做第二个：
/// - **能力清单**（本文件）：已毕业项 + 掌握度 + 适用场景 + 「历史」折叠区；
/// - **计划进度**（未实现，只放占位）：已完成段 + 当前循环轮次。
///
/// ## 为什么计划进度一个数字都不给
///
/// 它要「已完成段」与「当前循环轮次」两个量，而这两条**语义规格里还没有**：
/// 一段怎么算完成、重规划之后轮次怎么增，都未定；分段还要解析 `MethodBundle`
/// 的步骤结构（`QUANT-014`），视觉形态另记 `TBD-11`。这种情况下画一条线性
/// 百分比，等于用界面替规格做决定 —— 所以这一区只写「尚未实现」。
///
/// ## 为什么不显示事件计数
///
/// `VIEW-035` 的裁定：HUD 与进展视图一律不显示「复习 N 次」「累计 M 小时」
/// 这类按事件条数计的量。两台设备各学一遍就会翻倍，而用户会把它读成算错，
/// 进而怀疑那些**算得准**的数字（进度、掌握度）。状态类信息只用集合量。
///
/// ## 入口与外壳
///
/// 树屏 `AppBar` 的动作按钮推入，与 `planner` / `runner` 同一方式。`QUANT-011`
/// 说「底部导航承载 Z0–Z4 的视距刻度」，那个外壳尚未实现 —— 属应用外壳的事，
/// 另笔处理；本屏不新增第六视图，也不碰 `main.dart`。
///
/// ## 存储没接时按零事件算
///
/// 与 `overview_screen.dart` 同一先例：`eventStore == null` 不等于「读不出来」，
/// 而是「这条通道没接」（测试 / 取不到数据目录）。此时按「什么都没学过」渲染，
/// **不置错误态** —— 置了就跳到错误页，连空态长什么样都看不见。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/entities/node.dart';
import '../../core/entities/state.dart';
import '../../core/events/event.dart';
import '../../core/events/event_store.dart';
import '../../core/events/fold.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/quant/mastery.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.content, this.eventStore});

  final PackContent content;

  /// 事件存储。`null` = 没接，按零事件渲染（见文件头）。
  final EventStore? eventStore;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _problem;
  Set<String> _graduated = <String>{};
  Set<String> _retired = <String>{};
  Map<String, SrsState> _srs = <String, SrsState>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final EventStore? store = widget.eventStore;
    if (store == null) {
      setState(() => _loading = false);
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
        _graduated = folded.graduated;
        _retired = folded.retired;
        _srs = folded.srs;
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _problem = '事件日志读不出来：${error.message}';
      });
    }
  }

  /// 按 `pack.nodes` 的顺序取已毕业 / 已下线的项 —— 顺序稳定，不按集合迭代序
  /// （那会随插入顺序漂移，同一个包两次进来可能不一样）。
  List<LearnableNode> _nodesIn(Set<String> ids) => <LearnableNode>[
    for (final LearnableNode node in widget.content.learnableNodes)
      if (ids.contains(node.id)) node,
  ];

  /// 掌握度：`S` 取折叠出的 `SrsState`，缺则该函数自己返 0。
  ///
  /// `isCheckin` 与 `srs` 都可能是「没有」：没有 entry 的项按打卡式算（与
  /// `progress.dart` 同一口径），没有 `SrsState` 的项掌握度为 0。界面**不补判**
  /// 这两条，否则同一口径会长出两处实现。
  double _masteryOf(LearnableNode node) => masteryOf(
    node: node,
    stability: _srs[node.id]?.stability,
    isCheckin: widget.content.entryOf(node.id)?.isCheckin ?? true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('进展')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final String? problem = _problem;
    if (problem != null) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(problem));
    }
    final List<LearnableNode> graduated = _nodesIn(_graduated);
    final List<LearnableNode> retired = _nodesIn(_retired);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        const _SectionTitle('能力清单'),
        if (graduated.isEmpty)
          const _EmptyNote(
            '还没有毕业的项。一项要通过末次验收并积累到足够的记忆强度'
            '（S 达到 $graduationSDays 天）才会出现在这里。',
          )
        else
          for (final LearnableNode node in graduated)
            _CapabilityTile(
              name: node.name,
              outcomes:
                  widget.content.entryOf(node.id)?.outcomes ?? const <String>[],
              mastery: _masteryOf(node),
            ),
        const _SectionTitle('计划进度'),
        const _EmptyNote(
          '尚未实现 —— 这一区要「已完成段 + 当前循环轮次」，'
          '两条口径还没定，暂不给读数。',
        ),
        if (retired.isNotEmpty) _HistorySection(nodes: retired),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 空态与占位共用：说清「为什么这里是空的」，不是留白。
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// 能力清单的一行：项名 + 适用场景 + 掌握度。
///
/// 掌握度只给百分比整数：`d × s` 本身是连续值，界面上给更多位小数只是噪音。
/// **不给 `S` 原值** —— 那是「记得多牢」的中间量，与用户要回答的问题
/// （「这个我能不能用」）隔了一层。
class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.name,
    required this.outcomes,
    required this.mastery,
  });

  final String name;
  final List<String> outcomes;
  final double mastery;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: outcomes.isEmpty ? null : Text(outcomes.join(' · ')),
      trailing: Text('${(mastery * 100).round()}%'),
    );
  }
}

/// 「历史」折叠区：下线项。默认折叠 —— 它回答的是「以前学过什么」，
/// 排在能力清单之后，不该抢当前能力的注意力。
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.nodes});

  final List<LearnableNode> nodes;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('历史（${nodes.length} 项已下线）'),
      initiallyExpanded: false,
      children: <Widget>[
        for (final LearnableNode node in nodes)
          ListTile(title: Text(node.name)),
      ],
    );
  }
}
