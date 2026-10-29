/// 树页面：持有当前根与当前地址，把两个手势接到 [TreeView]。
///
/// ## 为什么状态在这里，而不在 [TreeView] 里
///
/// 换根要**留在树里**（`SPEC-TREE-005`）：动作是「改根」，不是「开新页」。状态
/// 落在页面这一层，换根就只是 `setState`，既不 push 路由也不切视图 —— 而这两
/// 件事一旦混进组件内部，测试只能靠「页面栈深度」去反推，那是间接证据。
///
/// ## 落点与手势是两条入口，落到同一个状态
///
/// 手势（点行、点面包屑）只改一件事；落点（[TreeScreen.initialLanding]）可能
/// 连根一起换，判据在 `core/tree/landing_target.dart`。两条入口写在这里而不是
/// 各写一份：地址只有一份，两个地方各存一个 id 就会分叉（`SPEC-TREE-007`）。
///
/// ## 建树可能立不起来，那也要说出来
///
/// [TreeIndex.build] 在三种坏数据上抛错：节点 id 重复、主父不唯一、同一轴出现
/// 两条无父链。三种都是「数据坏了」，不是「本页写错了」—— 塌成一句「加载失败」
/// 会让人去翻这一页的代码，而该翻的是那个包。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/events/event_store.dart';
import '../../core/events/hlc_clock.dart';
import '../../core/events/journal_event_store.dart';
import '../../core/locate/locator.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/plan/plan_entry.dart';
import '../../core/plan/plan_events.dart';
import '../../core/tree/landing.dart';
import '../../core/tree/landing_target.dart';
import '../../core/tree/tree_index.dart';
import '../../core/tree/tree_outline.dart';
import '../locate/locate_overlay.dart';
import '../planner/planner_screen.dart';
import 'tree_breadcrumb.dart';
import 'tree_view.dart';

/// 标题栏上的「定位」（`SPEC-PLAN-016` 第三入口的进处）。
const Key treeLocateKey = ValueKey<String>('tree-locate');

/// 筛选条（第四类落点生效时出现，`SPEC-TREE-014`）。
const Key treeFilterBarKey = ValueKey<String>('tree-filter-bar');

/// 筛选条上「取消筛选」那个按钮。
const Key treeFilterClearKey = ValueKey<String>('tree-filter-clear');

/// 「全树 / 单轴」切换按钮（`SPEC-TREE-003`）：单轴态显示「全树」，全树态显示
/// 「单轴」。放「N 个节点在树上」那一行的右侧 —— 它讲的是「树有多大」，切换讲
/// 的是「看几条轴」，同一件事的两种看法。
const Key treeModeToggleKey = ValueKey<String>('tree-mode-toggle');

class TreeScreen extends StatefulWidget {
  const TreeScreen({
    super.key,
    required this.contents,
    this.initialLanding,
    this.eventStore,
  });

  /// 全部已装载的包。骨架一条 + 载荷若干条 —— 树是**跨包**的，只喂一个包
  /// 会得到一片没有父的森林（载荷的 `attach_to` 指在骨架里）。
  final List<PackContent> contents;

  /// 建计划后写 `plan_created` 的去处。
  ///
  /// `null` = 这一层没接存储（旧的界面测试、纯展示预览）。此时**不假装写成功**：
  /// 计划照样进 Planner，但交出草稿后会说「没有落盘」—— 静默吞掉一条
  /// `plan_created` 等于丢事实（`SPEC-FND-010`）。
  final EventStore? eventStore;

  /// 打开时落到哪一处（`SPEC-TREE-010` 的四类落点）。
  ///
  /// `null` = 落在轴序第一个根 —— 不是「没有落点」，而是「知识树的最外层」，
  /// 那是唯一一个不需要任何一条数据就能确定的地址。
  ///
  /// 只在 `initState` 用一次。换落点要换 `key`，否则 `State` 复用、新落点不生效
  /// （与 `LocateOverlay.initialQuery` 同一条）。
  final Landing? initialLanding;

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  TreeIndex? _tree;
  Object? _error;
  String? _rootId;
  String? _selectedId;

  /// 当前筛选条件（第四类落点写进来的）。
  ///
  /// **不放 `ViewState`**：那个实体的 `axisFilter` 仍是旧的轴名 → 值列表口径
  /// （`entity-fields` §18 标着待删），把它当容器用等于先把一个待删字段救活、
  /// 再等下一次改名。筛选是页面状态，跟着页面生死。
  String? _filterTag;

  /// 定位浮层是否打开。放页面状态：浮层的遮罩要盖住整棵树，而不是只盖某一行。
  bool _locating = false;

  /// 树的形态（`SPEC-TREE-003`）。**默认单轴态**，且任何落点进来都回到这一态
  /// （`SPEC-TREE-013`）—— 落点携带确定节点，三轴并列会把刚确定的维度重新摊开。
  /// 只有用户点「全树」才进全树态，换根后自动退回单轴。
  TreeMode _mode = TreeMode.singleAxis;

  /// 发事件的时钟。**一个页面一个**：同一页面内连发两条时 `counter` 才会递增，
  /// 每次新建会把「同一毫秒」的发两条排成并列（`Hlc.compareTo` 只能靠 deviceId 分）。
  final HlcClock _clock = HlcClock(deviceId: localDeviceId);

  @override
  void initState() {
    super.initState();
    try {
      final TreeIndex tree = TreeIndex.build(contents: widget.contents);
      _tree = tree;
      final String? rootId = firstAxisRootId(tree);
      _rootId = rootId;
      _selectedId = rootId;
      _applyInitialLanding(tree, rootId);
    } on ArgumentError catch (error) {
      _error = error;
    }
  }

  /// 初值落点。根都找不到（骨架未装）时静默跳过 —— 没有树可以落，
  /// 而空态由 [_body] 说，不在这里抢先报错。
  void _applyInitialLanding(TreeIndex tree, String? rootId) {
    final Landing? landing = widget.initialLanding;
    if (landing == null || rootId == null) {
      return;
    }
    final TreeTarget? target = landInTree(
      tree: tree,
      resolver: LandingResolver(
        tree,
        packRootsOf(tree: tree, contents: widget.contents),
      ),
      landing: landing,
      currentRootId: rootId,
      currentAddressId: rootId,
    );
    if (target == null) {
      // 落点未命中：保持「最外层」。**不改成报错页** —— 跳不过去是一个可以
      // 接受的结局，把整棵树换成错误页会让用户连「我本来在哪」都看不到。
      return;
    }
    _rootId = target.rootId;
    _selectedId = target.addressId;
    _filterTag = target.filterTag;
  }

  /// 换根：改根 + 地址跟到新根，**不**切视图（`SPEC-TREE-005`）。
  ///
  /// 换根只在全树态发生（单轴态画面里没有另两条轴根），换完退回单轴态 ——
  /// 换轴的目的是「去看那一支」，不是「站在三岔口」。
  void _changeRoot(String nodeId) {
    setState(() {
      _rootId = nodeId;
      _selectedId = nodeId;
      _mode = TreeMode.singleAxis;
    });
  }

  void _drill(String nodeId) {
    setState(() => _selectedId = nodeId);
  }

  /// 单轴态 ⇄ 全树态（`SPEC-TREE-003`）。这是**唯一**改 [TreeMode] 的地方 ——
  /// 换根与落点都退回单轴，别处不再各写一遍。
  void _toggleMode() {
    setState(() {
      _mode = _mode == TreeMode.fullTree
          ? TreeMode.singleAxis
          : TreeMode.fullTree;
    });
  }

  /// 落点进来一律单轴态（`SPEC-TREE-013`）。
  void _resetMode() {
    _mode = TreeMode.singleAxis;
  }

  /// 点面包屑上的某一级：改地址，行集合跟着收到那一级（`SPEC-TREE-004` / `007`）。
  ///
  /// **这里不改根**，因为当前的两种手势保证了「地址永远在当前根子树内」：根只
  /// 有点轴根这一条来源（必然是最外层），而下钻与面包屑只沿地址的祖先链走 ——
  /// 那条链一定经过根本身。
  ///
  /// 落点那条入口**会**把根推到目标所在轴（`SPEC-TREE-013`），但它在
  /// `core/tree/landing_target.dart` 里一次算完（根与地址同批给出），不走这里
  /// 的逐字段赋值 —— 否则「根没跟上」这种状态会有一帧可见。
  void _jumpTo(String nodeId) => setState(() => _selectedId = nodeId);

  void _clearFilter() => setState(() => _filterTag = null);

  @override
  Widget build(BuildContext context) {
    final TreeIndex? tree = _tree;
    final String? address = _selectedId ?? _rootId;
    return Scaffold(
      appBar: AppBar(
        // 标题就是面包屑：`知识` 只出现一次。分两处写「知识」再加一条同名前缀，
        // 屏幕上会有两个一模一样的第一段，而它们谁都点不动。
        title: (tree == null || address == null)
            ? const Text(treeVirtualRootLabel)
            : TreeBreadcrumb(tree: tree, nodeId: address, onJump: _jumpTo),
        actions: <Widget>[
          IconButton(
            key: treeLocateKey,
            icon: const Icon(Icons.search),
            tooltip: '定位',
            onPressed: () => setState(() => _locating = true),
          ),
        ],
      ),
      // 浮层自带遮罩（`LocateOverlay` 根是 `Stack` + `Positioned.fill`），所以它
      // 必须叠在整棵树之上，而不是塞进某一栏。
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _body(context)),
          if (_locating) Positioned.fill(child: _locateOverlay()),
        ],
      ),
    );
  }

  /// 浮层本体。**作用域就是当前根**：`subtreeRoot` 给的是 `_rootId`，于是「圈内」
  /// 只有本包当前子树，跨包命中会落在分诊里（`VIEW-030` ①）。
  Widget _locateOverlay() {
    final PackContent? pack = _packContaining(_rootId);
    return LocateOverlay(
      pack: pack,
      subtreeRoot: _rootId ?? '',
      // 树是跨包的，本包之外的包照样能搜到 —— 但只在用户主动点「在全部空间中
      // 搜索」之后（`SPEC-VIEW-031`），所以这里给全量与 `scopePluginId`。
      otherPacks: <PackContent>[
        for (final PackContent content in widget.contents)
          if (!identical(content, pack)) content,
      ],
      scopePluginId: pack?.pack.pluginId,
      onPick: (LocateResult result, LocateHit hit) => _landOn(hit.target),
      onPickNear: _landOn,
      onDismiss: () => setState(() => _locating = false),
      onPlanHere: _planFrom,
      canPlanHere: (LocateResult result) =>
          planEntryFor(result: result, contents: widget.contents) != null,
    );
  }

  /// 把地址落到某个节点上（`SPEC-TREE-010` 第一类）。走 `landInTree` 而不是直接
  /// `_drill`：跨轴命中要把根一起推过去，逐字段赋值会让「根没跟上」露一帧。
  void _landOn(String nodeId) {
    final TreeIndex? tree = _tree;
    if (tree == null) {
      setState(() => _locating = false);
      return;
    }
    final TreeTarget? target = landInTree(
      tree: tree,
      resolver: LandingResolver(
        tree,
        packRootsOf(tree: tree, contents: widget.contents),
      ),
      landing: NodeLanding(nodeId),
      currentRootId: _rootId ?? nodeId,
      currentAddressId: _selectedId ?? nodeId,
    );
    setState(() {
      _locating = false;
      if (target != null) {
        _rootId = target.rootId;
        _selectedId = target.addressId;
        _filterTag = target.filterTag;
        // 落点进来一律单轴态（`SPEC-TREE-013`）：站着三岔口定位，等于把刚刚
        // 确定的那个维度又摊开一次。
        _resetMode();
      }
    });
  }

  /// 「按此范围建计划」（`SPEC-PLAN-016` 第三入口）。
  ///
  /// 浮层已经在 `canPlanHere` 里判过一遍，这里再算一次是**故意的**：两次之间
  /// 内容包不会变，而重算比把 `PlanEntry` 缓存进 `State` 更省事 —— 缓存的代价是
  /// 要回答「包换了之后它什么时候失效」，那是个真问题，这里不需要它。
  Future<void> _planFrom(LocateResult result) async {
    final PlanEntry? entry = planEntryFor(
      result: result,
      contents: widget.contents,
    );
    if (entry == null) {
      return;
    }
    final PackContent? pack = _packContaining(entry.subtreeRoot);
    if (pack == null) {
      return;
    }
    setState(() => _locating = false);
    final PlanDraft? draft = await PlannerScreen.open(
      context,
      pack: pack,
      spaceId: entry.spaceId,
      subtreeRoot: entry.subtreeRoot,
      primaryAxis: entry.primaryAxis,
      packVersions: entry.packVersions,
    );
    if (draft == null || !mounted) {
      return;
    }
    await _recordPlan(draft);
  }

  /// 落一条 `plan_created`。**只在用户真的交了草稿之后**写 —— 打开 Planner 又
  /// 返回不等于建了计划（`planner_screen.dart` 文件头：面板只交草稿）。
  Future<void> _recordPlan(PlanDraft draft) async {
    final EventStore? store = widget.eventStore;
    if (store == null) {
      // 没接存储时不假装写成功，也不回滚界面 —— 计划已经交出来了，只是没落盘。
      _say('事件存储未接入，这份计划没有落盘');
      return;
    }
    try {
      await store.append(
        buildPlanCreated(
          draft: draft,
          clock: _clock,
          now: DateTime.now(),
          userId: localDefaultUserId,
        ),
      );
    } on StateError catch (error) {
      _say(error.message);
    }
  }

  void _say(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 某个节点所在的包。`null` = 没装载那个节点（骨架缺失时 `_rootId` 也是 null）。
  PackContent? _packContaining(String? nodeId) {
    if (nodeId == null) {
      return null;
    }
    for (final PackContent content in widget.contents) {
      if (content.nodeById.containsKey(nodeId)) {
        return content;
      }
    }
    return null;
  }

  Widget _body(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TreeIndex? tree = _tree;
    final String? rootId = _rootId;

    if (tree == null) {
      return _Notice(
        title: '这棵树立不起来',
        lines: <String>[
          '${_error ?? '未知原因'}',
          '树要求每个节点至多一个主父、且同一轴只有一条无父链 —— '
              '这两条之一被数据打破了。',
        ],
      );
    }
    if (rootId == null) {
      return const _Notice(
        title: '树里没有根',
        lines: <String>['已装载的包里没有可作轴根的节点（未装骨架时通常如此）。'],
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  // 不写「共 N 个节点」：那是装配器的读数，不是树的位置信息。
                  '${tree.nodeCount} 个节点在树上',
                  style: text.bodySmall,
                ),
              ),
              // 「全树 / 单轴」（`SPEC-TREE-003`）：文案跟着当前态走 —— 按钮写的
              // 是「点了会去哪」，不是「现在在哪」。
              TextButton(
                key: treeModeToggleKey,
                onPressed: _toggleMode,
                child: Text(
                  _mode == TreeMode.fullTree ? '单轴' : '全树',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (_filterTag != null) _filterBar(context, _filterTag!),
        const Divider(height: 1),
        Expanded(
          child: TreeView(
            tree: tree,
            rootId: rootId,
            selectedId: _selectedId,
            mode: _mode,
            onDrill: _drill,
            onChangeRoot: _changeRoot,
          ),
        ),
      ],
    );
  }

  /// 筛选条（`SPEC-TREE-014`）。
  ///
  /// 条件生效时**必须看得见**、且能一键撤掉：`SPEC-TREE-010` 要求第四类落点
  /// 看上去与前三类不同，而它唯一的外显就是这条 —— 否则「点了筛选」与「点了
  /// 没反应」在画面上完全一样。
  ///
  /// **它不删任何一行**（理由见 `SPEC-TREE-014`：行集合由地址派生，删行会在
  /// 地址路径上打洞）。所以这里没有任何过滤动作，只有一句「当前条件是它」。
  Widget _filterBar(BuildContext context, String tag) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      key: treeFilterBarKey,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.filter_alt_outlined, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '筛选：$tag',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: colors.primary),
            ),
          ),
          IconButton(
            key: treeFilterClearKey,
            icon: const Icon(Icons.close, size: 16),
            tooltip: '取消筛选',
            visualDensity: VisualDensity.compact,
            onPressed: _clearFilter,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: text.titleMedium),
            const SizedBox(height: 12),
            for (final String line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
