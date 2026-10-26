/// 树页面：持有当前根与当前地址，把两个手势接到 [TreeView]。
///
/// ## 为什么状态在这里，而不在 [TreeView] 里
///
/// 换根要**留在树里**（`SPEC-TREE-005`）：动作是「改根」，不是「开新页」。状态
/// 落在页面这一层，换根就只是 `setState`，既不 push 路由也不切视图 —— 而这两
/// 件事一旦混进组件内部，测试只能靠「页面栈深度」去反推，那是间接证据。
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
import '../../core/tree/tree_index.dart';
import '../../core/tree/tree_outline.dart';
import 'tree_view.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key, required this.contents});

  /// 全部已装载的包。骨架一条 + 载荷若干条 —— 树是**跨包**的，只喂一个包
  /// 会得到一片没有父的森林（载荷的 `attach_to` 指在骨架里）。
  final List<PackContent> contents;

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  TreeIndex? _tree;
  Object? _error;
  String? _rootId;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    try {
      final TreeIndex tree = TreeIndex.build(contents: widget.contents);
      _tree = tree;
      _rootId = firstAxisRootId(tree);
      _selectedId = _rootId;
    } on ArgumentError catch (error) {
      _error = error;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(treeVirtualRootLabel)),
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
