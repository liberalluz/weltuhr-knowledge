/// 树面板要画的行（`SPEC-TREE-002` / `003` / `004` / `008` / `012`）。
///
/// ## 行集合 = `知识` + 轴根 + 当前路径逐级展开 + 各层兄弟
///
/// 角色轴铺到底有 1,687 个细类，整棵前序展开既画不完、也读不出自己在哪。这里
/// 只把**选中路径**逐级展开 —— 从轴根到地址的每一级，**含地址自己那一层**
/// （不展开它自己的话，选中一行之后它的子节点永远不出现，收一层就走不动下一
/// 步）；链上每一级的兄弟一并列出：
///
/// - 于是「逐级可点」（`SPEC-TREE-004`）不需要展开 / 收起这个**第三态** ——
///   点哪个兄弟，地址就改到它，它的下一级自然出现。树里只剩一种点击（改地址）
///   加一种换根（全树态点别的轴根），与 `SPEC-TREE-004` 的表一一对应。
/// - 兄弟全列而不是只列链上那一个：只列链上那一个的话，用户看到的是一条直线，
///   「这里还有别的」这件事没有任何地方能读出来。
///
/// ## 两态（`SPEC-TREE-003`）
///
/// 单轴态只出**当前根所在那一条轴**的轴根行；全树态三条轴根各一行，但只有当前
/// 轴往下展 —— 另两条给的是「还有两支」这个事实，不是它们的整棵子树。
///
/// ## 同级截断（`SPEC-TREE-012`）
///
/// 单级兄弟超过 [treeSiblingRowCap] 行时只出前 50 行，其下一行「还有 M 项」。
/// **地址链必显**：地址（或它在该级的那位祖先）若落在被截掉的部分里，额外补进
/// 来 —— 否则下钻到第 51 个兄弟后，行集合里找不到「我在哪」；地址更深时它的
/// 祖先不在屏上，整条链在那一级断掉，逐级可点随之失效。
///
/// 行集合是纯函数，不是 widget 的中间产物 —— 它要能在不建渲染树的情况下断言
/// 顺序、缩进与展开范围（`tree_outline_test.dart`）。
///
/// ## 缩进以 `知识` 为 0（`SPEC-TREE-008`）
///
/// 不用 `TreeRow.depth`：那是从轴根起的绝对层深，缩进基准上移到 `知识` 之后
/// 差一个常数，直接乘缩进量会把所有行向右推一级。也不用「相对当前根」—— 换态
/// 时当前根在第几行会变，同一行的缩进跟着变，看起来像层级动了。
library;

import '../constants.dart';
import '../entities/node.dart';
import '../enums.dart';
import 'tree_index.dart';

/// 同级兄弟一次最多出多少行（`SPEC-TREE-012`）。超出的部分折进「还有 M 项」。
const int treeSiblingRowCap = 50;

/// 树的形态（`SPEC-TREE-003`）。
enum TreeMode {
  /// 单轴态（默认）：只出当前根所在那一条轴的轴根行。任何入口进来都是这一态。
  singleAxis,

  /// 全树态：三条轴根各一行，只有当前轴往下展。
  fullTree,
}

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
    this.isVirtualRoot = false,
    this.isOverflow = false,
  });

  /// 节点 id。虚拟根与截断行**没有节点**，这里是空串 —— 两者靠 [isVirtualRoot]
  /// 与 [isOverflow] 区分，界面据此判「这行不可点」。
  final String nodeId;

  /// 展示名（`Node.name`，或虚拟根 / 截断行的固定文案）。
  final String label;

  /// 相对 `知识` 行的路径段数（`知识` = `0`、轴根 = `1`）。
  /// 缩进 = 本值 × [treeLevelIndent]。
  final int indent;

  /// 完整 `path`。虚拟根与截断行为空串（它们没有地址）。
  final String path;

  /// 三条轴根之一（`SPEC-TREE-003`）：全树态点它是**换根**，不是下钻。
  final bool isAxisRoot;

  /// 当前轴根那一行。行尾挂「当前」标记（`SPEC-TREE-003`）。
  final bool isCurrentRoot;

  /// 与当前地址相同的那一行。
  final bool isSelected;

  /// 有子节点。没有子节点的行点了只改地址，不展开 —— 这两件事在界面上要
  /// 看得出区别，否则「点了没反应」与「点了但这里本来就没有下一层」分不清。
  final bool hasChildren;

  /// `layer`（`SPEC-FND-003`）：**行尾标签**，不参与缩进（`SPEC-TREE-008`）。
  /// `null` = 本行没有这个字段（结构节点不带 `layer`）。
  final Layer? layer;

  /// 虚拟根 `知识` 那一行（`SPEC-TREE-002`）：两态都画、不可点、不进地址。
  final bool isVirtualRoot;

  /// 同级截断的「还有 M 项」行（`SPEC-TREE-012`）：不可点、不进地址。
  final bool isOverflow;

  /// 这行能不能点。三类不可点：虚拟根、截断行、以及本行没有节点（空 [nodeId]）。
  bool get isClickable => !isVirtualRoot && !isOverflow && nodeId.isNotEmpty;
}

/// 截断行的文案。`count` = 该级被截掉的兄弟数。
String treeOverflowLabel(int count) => '还有 $count 项';

/// 树要画的行，按前序排列（父行紧跟其子行）。
///
/// [rootId] 只用来定「当前轴」—— 出哪条轴的轴根行、哪条轴往下展。它可以是
/// 任意节点，不必是轴根（`SPEC-TREE-005` 的换根没限定换到轴根）。
///
/// [rootId] 不在树上时 [TreeIndex.axisRootOf] 返回 `null`：单轴态下只剩 `知识`
/// 一行，全树态下三条轴根都在但都不展开。**不替调用方猜一根轴**去展开 —— 地址
/// 只能由点击产生。
List<OutlineRow> treeOutline({
  required TreeIndex tree,
  required String rootId,
  String? selectedId,
  TreeMode mode = TreeMode.singleAxis,
  int siblingCap = treeSiblingRowCap,
}) {
  final List<TreeRow> axes = tree.axisRoots();
  final String? currentAxisId = tree.axisRootOf(rootId)?.nodeId;
  final List<OutlineRow> rows = <OutlineRow>[
    OutlineRow(
      nodeId: '',
      label: treeVirtualRootLabel,
      indent: 0,
      path: '',
      isAxisRoot: false,
      isCurrentRoot: false,
      isSelected: false,
      hasChildren: axes.isNotEmpty,
      isVirtualRoot: true,
    ),
  ];

  // 轴根行**连续**列出（单轴态一条、全树态三条）：它们是 `知识` 的同一级子，
  // 中间不插当前轴的子行 —— 插进去会把另两条轴根推到几十行之后，「还有两支」
  // 这件事就看不见了。`知识` 之下这一级是前序的唯一例外，再往下都严格前序。
  final List<TreeRow> axisRows = mode == TreeMode.fullTree
      ? axes
      : axes
            .where((TreeRow axis) => axis.nodeId == currentAxisId)
            .toList(growable: false);
  for (final TreeRow axis in axisRows) {
    rows.add(
      _rowOf(
        tree,
        axis,
        indent: 1,
        isAxisRoot: true,
        isCurrentRoot: axis.nodeId == currentAxisId,
        selectedId: selectedId,
      ),
    );
  }

  // 只有当前轴往下展：全树态下另两条轴**只出轴根一行**（`SPEC-TREE-003`）。
  if (currentAxisId != null) {
    _walk(
      tree,
      parentId: currentAxisId,
      indent: 2,
      selectedId: selectedId,
      rows: rows,
      siblingCap: siblingCap,
    );
  }
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
  required int siblingCap,
}) {
  final List<TreeRow> children = tree.childrenOf(parentId);
  final List<TreeRow> shown = children.length <= siblingCap
      ? children
      : children.take(siblingCap).toList();

  // 地址链必显（`SPEC-TREE-012`）：被截掉的那部分里，若有一行是地址或它的
  // 祖先，补回来。补的是**这一级的祖先**而不是地址本身 —— 地址更深时，缺了
  // 这位祖先整条链就断在这一级。
  if (shown.length < children.length && selectedId != null) {
    for (final TreeRow row in children.skip(siblingCap)) {
      if (_isAddressOrAncestorOfIt(tree, row.nodeId, selectedId)) {
        shown.add(row);
        break;
      }
    }
  }

  for (final TreeRow child in shown) {
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
    if (_isAddressOrAncestorOfIt(tree, child.nodeId, selectedId)) {
      _walk(
        tree,
        parentId: child.nodeId,
        indent: indent + 1,
        selectedId: selectedId,
        rows: rows,
        siblingCap: siblingCap,
      );
    }
  }

  // 截断行排在最后一行，`M` 按「总数 − 容量」算，不因补回的地址行而减少
  // （`SPEC-TREE-012`）。
  if (children.length > siblingCap) {
    rows.add(
      OutlineRow(
        nodeId: '',
        label: treeOverflowLabel(children.length - siblingCap),
        indent: indent,
        path: '',
        isAxisRoot: false,
        isCurrentRoot: false,
        isSelected: false,
        hasChildren: false,
        isOverflow: true,
      ),
    );
  }
}

/// [nodeId] 是当前地址**本身**或它的祖先。
///
/// ⚠️ **必须含「它本身」**：只认严格祖先的话，选中一行之后它自己的子节点永远
/// 不出现（选中的是它，不是它的后代），于是逐级可点在第二层就断了 —— 而
/// `SPEC-TREE-004` 的验收行写的正是「点子节点 ⇒ `path` 变长，**视觉焦点下移
/// 一层**」。收一层、走一层，`_walk` 才有下一级可走。
///
/// 用 `relativePath` 判而不是比层深：它同时覆盖「不在同一棵子树」（返回
/// `null`）与「同一个节点」（返回空串）两种情形，两种都要能区分开。
bool _isAddressOrAncestorOfIt(
  TreeIndex tree,
  String nodeId,
  String? selectedId,
) {
  if (selectedId == null) {
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
