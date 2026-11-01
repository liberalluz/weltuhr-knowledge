import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/entities/node.dart';
import '../../../core/entities/state.dart';
import '../../../core/events/event.dart';
import '../../../core/events/event_store.dart';
import '../../../core/events/fold.dart';
import '../../../core/pack/pack_reader.dart';
import '../../../core/quant/subtree_brightness.dart';
import '../../../core/tree/tree_index.dart';
import '../../../core/universe/placement.dart';
import 'spike_scene.dart';

/// 宇宙视图的产品入口（`B17b` 笔 2 挂上、笔 3 接上节点、笔 4 接上亮度）。
///
/// **地址来自树，不自己算一套**：树屏把它的 [TreeIndex] 与当前那一行原样传进来
/// （`SPEC-TREE-007`），这里只调 `layoutOfNode` 把它翻成坐标。两处各存一个 id
/// 早晚会分叉 —— 在树里看到哪、切过来就该是哪一片天。
///
/// **主题在这一层覆成深色**，不动全局 `ThemeData`：星空必须黑底，而主 app 是
/// 浅色主题。覆在页面这一层，返回时主题自然还原，不必给入口加分支。
///
/// **采样面板不显示**：[SpikeSceneView] 的 `showReadout` 默认关，这里不传，
/// 用户看不到 `P50` / `P95`。帧率仍在 `lib/spike_main.dart` 那个调试入口采
/// （`flutter run -t lib/spike_main.dart`），验收口径不变。
///
/// ## 亮度为什么在页面这一层算
///
/// 亮度要事件日志（`passed` / `SrsState`）与包内容（`requirements` 算深度），
/// 两者都只有**装配层**拿得到 —— 渲染层只该收到一张 id → 亮度的表。与
/// `masteryOf` 同一条分层口径：取数归核心层（`subtreeBrightnessOf`），来源归这里。
///
/// ## 四个空态都落到同一处置
///
/// 没接存储 · 日志为空 · 读日志失败 · 某个包算不出深度 —— 四种情形一律把
/// [SpikeSceneView.brightness] 留成 `null`（全体共用 `universeBrightnessUnknown`）。
/// **不报错、不空白、不假装没学过**：日志读不出来时说「你什么都没学」是假话，
/// 而那正是这四种情形的共同点。
///
/// ⚠️ 类名仍带 `Spike`：改名会牵动测试与调用点，属于后续笔的整理范围，
/// 本笔不做未点名的重命名。
class UniverseScreen extends StatefulWidget {
  const UniverseScreen({
    super.key,
    this.tree,
    this.currentNodeId,
    this.contents,
    this.eventStore,
  });

  /// 树的索引。`null` = 骨架未装载 —— 此时只画星空，不画节点，也不报错。
  final TreeIndex? tree;

  /// 树里当前那一行。`null` 同上。
  final String? currentNodeId;

  /// 全部已装载的包。亮度从中取可学节点的 `requirements` 与打卡标记。
  ///
  /// 与树屏吃的是同一份（`SPEC-TREE-007`）：宇宙与树是同一棵树的两种看法，
  /// 各读一份包迟早出现「树里 150 项、宇宙算了 148 项」。
  final List<PackContent>? contents;

  /// 事件日志的去处。`null` = 这一层没接存储 —— 亮度降级，其余照常。
  final EventStore? eventStore;

  @override
  State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen> {
  /// 骨架点 id → 亮度。`null` = 还没算出来或算不出来 —— 见类文档的四个空态。
  Map<String, double>? _brightness;

  /// 这一片天。算不出来时是 `null`，由 `SpikeSceneView` 按「只画星空」处置。
  ///
  /// 在 `build` 里算而不是缓存：`layoutOfNode` 是纯函数，输入只有树与地址，
  /// 而这两个都是本组件的字段 —— 缓存反而要处理「树换了但 id 没变」这种失效。
  UniverseView? get _universe {
    final TreeIndex? tree = widget.tree;
    final String? id = widget.currentNodeId;
    if (tree == null || id == null) {
      return null;
    }
    return layoutOfNode(tree, id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UniverseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 地址或树换了 ⇒ 亮度对的是另一批点。不重算的话，从 A 进宇宙、返回、走到 B
    // 再进来，State 若是复用的，画的就是 A 的亮度（A 的 id 在新视角里查不到，
    // 于是全落成「未学」—— 看起来像刚把学过的都清空了）。
    if (oldWidget.currentNodeId != widget.currentNodeId ||
        oldWidget.tree != widget.tree) {
      _brightness = null;
      _load();
    }
  }

  Future<void> _load() async {
    final UniverseView? universe = _universe;
    final TreeIndex? tree = widget.tree;
    final EventStore? store = widget.eventStore;
    final List<PackContent> contents = widget.contents ?? const <PackContent>[];
    if (universe == null || tree == null || store == null || contents.isEmpty) {
      return;
    }

    // 打卡标记按 id 摊平：同一个 id 只可能在一个包里（`TreeIndex.build` 对重复
    // id 直接抛），因此不必保留出处。
    final Map<String, bool> checkin = <String, bool>{};
    final List<LearnableNode> learnables = <LearnableNode>[];
    for (final PackContent content in contents) {
      for (final LearnableNode node in content.learnableNodes) {
        learnables.add(node);
        checkin[node.id] = content.entryOf(node.id)?.isCheckin ?? true;
      }
    }

    try {
      // 事件日志按包分空间存（`readAll(spaceId: pack.pluginId)`），而一棵骨架
      // 下挂着多个载荷包 ⇒ 逐包折叠再合并。`passed` 是集合、`srs` 是按 id 的
      // 表，键在不同包之间不会撞，合并即并集。
      final Set<String> passed = <String>{};
      final Map<String, SrsState> srs = <String, SrsState>{};
      for (final PackContent content in contents) {
        final String spaceId = content.pack.pluginId;
        final List<Event> events = await store
            .readAll(spaceId: spaceId)
            .toList();
        final FoldedState folded = fold(
          events,
          spaceId: spaceId,
          userId: localDefaultUserId,
        );
        passed.addAll(folded.passed);
        srs.addAll(folded.srs);
      }

      final UniverseLayout layout = universe.layout;
      final Map<String, double> table = subtreeBrightnessOf(
        skeletonIds: <String>[
          universe.anchorId,
          ...layout.ancestorIds,
          ...layout.children.keys,
        ],
        learnables: learnables,
        parents: tree.parents,
        isPassed: passed.contains,
        isCheckin: (String id) => checkin[id] ?? true,
        stabilityOf: (String id) => srs[id]?.stability,
      );

      if (!mounted) {
        return;
      }
      setState(() => _brightness = table);
    } on FormatException {
      // 日志格式不对：与 `progress_screen` 同一处置 —— 不把堆栈抛给用户，
      // 亮度留 `null` 走统一基准。
      if (!mounted) {
        return;
      }
      setState(() => _brightness = null);
    } on StateError {
      // `depthOf` 对「可外化格为 0」的项抛 —— 那本该在内容校验期被拒收。
      // 一个坏项不该把整片天变成暗的，也不该假装算得出来 ⇒ 统一基准。
      if (!mounted) {
        return;
      }
      setState(() => _brightness = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('宇宙'),
        ),
        body: SpikeSceneView(universe: _universe, brightness: _brightness),
      ),
    );
  }
}
