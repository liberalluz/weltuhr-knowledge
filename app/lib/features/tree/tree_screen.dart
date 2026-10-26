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
import '../../core/pack/pack_reader.dart';
import '../../core/tree/landing.dart';
import '../../core/tree/landing_target.dart';
import '../../core/tree/tree_index.dart';
import '../../core/tree/tree_outline.dart';
import 'tree_breadcrumb.dart';
import 'tree_view.dart';

/// 筛选条（第四类落点生效时出现，`SPEC-TREE-014`）。
const Key treeFilterBarKey = ValueKey<String>('tree-filter-bar');

/// 筛选条上「取消筛选」那个按钮。
const Key treeFilterClearKey = ValueKey<String>('tree-filter-clear');

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key, required this.contents, this.initialLanding});

  /// 全部已装载的包。骨架一条 + 载荷若干条 —— 树是**跨包**的，只喂一个包
  /// 会得到一片没有父的森林（载荷的 `attach_to` 指在骨架里）。
  final List<PackContent> contents;

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
      resolver: LandingResolver(tree, packRootsOf(tree: tree, contents: widget.contents)),
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
  void _changeRoot(String nodeId) {
    setState(() {
      _rootId = nodeId;
      _selectedId = nodeId;
    });
  }

  void _drill(String nodeId) {
    setState(() => _selectedId = nodeId);
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
      ),
      body: _body(context),
    );
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              // 不写「共 N 个节点」：那是装配器的读数，不是树的位置信息。
              '${tree.nodeCount} 个节点在树上',
              style: text.bodySmall,
            ),
          ),
        ),
        if (_filterTag != null) _filterBar(context, _filterTag!),
        const Divider(height: 1),
        Expanded(
          child: TreeView(
            tree: tree,
            rootId: rootId,
            selectedId: _selectedId,
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
                child: Text(line, style: text.bodySmall, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}
