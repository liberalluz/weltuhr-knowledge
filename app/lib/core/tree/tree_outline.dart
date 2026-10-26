/// 树面板要画的行（`SPEC-TREE-003` / `004` / `008`）。
///
/// ## 行集合 = 三条轴根 + 当前根下「当前路径逐级展开」
///
/// 角色轴铺到底有 1,687 个细类，整棵前序展开既画不完、也读不出自己在哪。这里
/// 只把**选中路径**逐级展开，链上每一级的兄弟一并列出：
///
/// - 于是「逐级可点」（`SPEC-TREE-004`）不需要展开 / 收起这个**第三态** ——
///   点哪个兄弟，地址就改到它，它的下一级自然出现。树里只剩一种点击（改地址）
///   加一种换根（点别的轴根），与 `SPEC-TREE-004` 的两行表一一对应。
/// - 兄弟全列而不是只列链上那一个：只列链上那一个的话，用户看到的是一条直线，
///   「这里还有别的」这件事没有任何地方能读出来。
///
/// 行集合是纯函数，不是 widget 的中间产物 —— 它要能在不建渲染树的情况下断言
/// 顺序、缩进与展开范围（`tree_outline_test.dart`）。
///
/// ## 缩进用「相对当前根的段数」，不用 `TreeRow.depth`
///
/// `TreeRow.depth` 是从**轴根**起的绝对层深，而 `SPEC-TREE-008` 判的是「当前行
/// 相对**当前根**的路径段数」。换根之后两者差一个常数，把绝对值乘缩进量会把
/// 整棵树向右推 —— 而 `SPEC-TREE-008` 的禁令正是「不得按槽位序号缩进」，两处
/// 犯的是同一个错：拿一个与当前根无关的量当缩进依据。
library;

import '../constants.dart';
import '../entities/node.dart';
import '../enums.dart';
import 'tree_index.dart';

/// 树里一行。
class OutlineRow {
  const OutlineRow({
    required this.nodeId,
    required this.label,
    required this.indent,
    required this.path,
    required this.isAxisRoot,
    required this.isCurrentRoot,
    required this.isSelected,
    required this.hasChildren,
    this.layer,
  });

  final String nodeId;

  /// 展示名（`Node.name`）。与面包屑同源，不另取 `slug`。
  final String label;

  /// 相对当前根的路径段数（当前根为 `0`）。缩进 = 本值 × [treeLevelIndent]。
  final int indent;

  final String path;

  /// 三条轴根之一（`SPEC-TREE-003`）：点它是**换根**，不是下钻。
  final bool isAxisRoot;

  /// 当前根。行尾挂「当前」标记（`SPEC-TREE-003`）。
  final bool isCurrentRoot;

  /// 与当前地址相同的那一行。
  final bool isSelected;

  /// 有子节点。没有子节点的行点了只改地址，不展开 —— 这两件事在界面上要
  /// 看得出区别，否则「点了没反应」与「点了但这里本来就没有下一层」分不清。
  final bool hasChildren;

  /// `layer`（`SPEC-FND-003`）：**行尾标签**，不参与缩进（`SPEC-TREE-008`）。
  /// `null` = 本行没有这个字段（结构节点不带 `layer`）。
  final Layer? layer;
}

/// 树要画的行，按前序排列。
///
/// [rootId] 未知（不在树上）时只返回三条轴根 —— 空表会让界面变成一片空白，
/// 而「根不在树上」本身是要给人看的信息。
///
/// [selectedId] 不在 [rootId] 子树下时同理：不深入任何一级，只展开根的直接子。
/// **不回落成「选中根」**：那是替调用方猜地址，而地址只能由点击产生。
List<OutlineRow> treeOutline({
  required TreeIndex tree,
  required String rootId,
  String? selectedId,
}) {
  final List<OutlineRow> rows = <OutlineRow>[];
  bool rootIsAxisRoot = false;
  for (final TreeRow axis in tree.axisRoots()) {
    if (axis.nodeId == rootId) {
      rootIsAxisRoot = true;
    }
    rows.add(
      _rowOf(
        tree,
        axis,
        indent: 0,
        isAxisRoot: true,
        isCurrentRoot: axis.nodeId == rootId,
        selectedId: selectedId,
      ),
    );
  }

  // 根可以是任意节点（`SPEC-TREE-005` 的换根没限定必须换到轴根）：不在
  // [axisRoots] 里时它自己也得占一行，否则「当前根」在这张表上不存在。
  if (!rootIsAxisRoot) {
    final TreeRow? root = tree.rowOf(rootId);
    if (root == null) {
      return rows;
    }
    rows.add(
      _rowOf(
        tree,
        root,
        indent: 0,
        isAxisRoot: false,
        isCurrentRoot: true,
        selectedId: selectedId,
      ),
    );
  }

  _walk(
    tree,
    parentId: rootId,
    indent: 1,
    selectedId: selectedId,
    rows: rows,
  );
  return rows;
}

/// 当前根：轴序第一根。空树返回 `null`（界面据此显示空态，不自造一个根）。
String? firstAxisRootId(TreeIndex tree) {
  final List<TreeRow> roots = tree.axisRoots();
  return roots.isEmpty ? null : roots.first.nodeId;
}

void _walk(
  TreeIndex tree, {
  required String parentId,
  required int indent,
  required String? selectedId,
  required List<OutlineRow> rows,
}) {
  for (final TreeRow child in tree.childrenOf(parentId)) {
    rows.add(
      _rowOf(
        tree,
        child,
        indent: indent,
        isAxisRoot: false,
        isCurrentRoot: false,
        selectedId: selectedId,
      ),
    );
    if (_isStrictAncestorOfSelected(tree, child.nodeId, selectedId)) {
      _walk(
        tree,
        parentId: child.nodeId,
        indent: indent + 1,
        selectedId: selectedId,
        rows: rows,
      );
    }
  }
}

/// [nodeId] 是不是 [selectedId] 的**严格**祖先。
///
/// 用 `relativePath` 判，不看层深：它同时覆盖了「不在同一棵子树」（返回
/// `null`）与「是同一节点」（返回空串，但那不算祖先）两种情形。
bool _isStrictAncestorOfSelected(
  TreeIndex tree,
  String nodeId,
  String? selectedId,
) {
  if (selectedId == null || selectedId == nodeId) {
    return false;
  }
  return tree.relativePath(rootId: nodeId, nodeId: selectedId) != null;
}

OutlineRow _rowOf(
  TreeIndex tree,
  TreeRow row, {
  required int indent,
  required bool isAxisRoot,
  required bool isCurrentRoot,
  required String? selectedId,
}) {
  final Node? node = tree.nodeOf(row.nodeId);
  return OutlineRow(
    nodeId: row.nodeId,
    label: row.label,
    indent: indent,
    path: row.path,
    isAxisRoot: isAxisRoot,
    isCurrentRoot: isCurrentRoot,
    isSelected: row.nodeId == selectedId,
    hasChildren: tree.childrenOf(row.nodeId).isNotEmpty,
    layer: node is LearnableNode ? node.layer : null,
  );
}
