/// 容器树的界面层（`SPEC-TREE-003` / `004` / `005` / `008`）。
///
/// ## 这里只有「画」和「把手势交出去」
///
/// 行集合由 [treeOutline] 算好，地址由调用方持有 —— 本文件不知道「当前地址」
/// 是怎么存的，也不知道换根之后要不要跳页。两件事分开的理由是失败时的含义
/// 不同：行集合算错是「树长得不对」，手势接错是「点了没反应 / 点错地方」。
///
/// ## 树里只有两种点击
///
/// `SPEC-TREE-004` 的表一共两行：点子节点 = 下钻改地址，点别的轴根 = 换根。
/// 没有第三种 —— 「点了只筛选不改地址」是四类标签的行为（坐标语义），树里的
/// 每一行都是容器（`SPEC-FND-006`）。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/tree/tree_index.dart';
import '../../core/tree/tree_outline.dart';

/// 一行的 `Key`：测试与「点第几行」都按 `nodeId` 定位，不按行号（行号会随
/// 展开范围变，按行号写的断言在换根之后指向另一行）。
Key treeRowKey(String nodeId) => ValueKey<String>('tree-row:$nodeId');

/// 「当前」标记（`SPEC-TREE-003`）。只应出现一次 —— 根的个数是 1。
const Key treeCurrentRootMarkKey = ValueKey<String>('tree-current-root');

/// 行首固定留白（px）。缩进在它**之上**叠加，断言缩进时减去它即可。
const double treeRowLeadingGap = 8;

/// 行高（px）。
///
/// 不按 48 的触控最小尺寸给：这是桌面树，一屏要读得下十几行，48 会把可视行数
/// 砍掉三分之一。可点性由整行的 `InkWell` 保证 —— 36 仍远高于 24 px 的下限。
const double treeRowHeight = 36;

/// 容器树。
///
/// [rootId] 与 [selectedId] 都由调用方持有（本组件是 `StatelessWidget`）：
/// 树不该有第二份「当前位置」，否则面包屑、宇宙视图与它各自 fold 一次就会分叉
/// （`SPEC-TREE-007`：三者读同一份来源）。
class TreeView extends StatelessWidget {
  const TreeView({
    super.key,
    required this.tree,
    required this.rootId,
    required this.selectedId,
    required this.onDrill,
    required this.onChangeRoot,
    this.scrollController,
  });

  final TreeIndex tree;

  /// 当前根（`SPEC-TREE-005` 换的是它）。
  final String rootId;

  /// 当前地址所在节点。
  final String? selectedId;

  /// 下钻 / 选中：改地址。
  final ValueChanged<String> onDrill;

  /// 换根：改根、留在树（不触发视图切换）。
  final ValueChanged<String> onChangeRoot;

  /// 列表的滚动控制器。
  ///
  /// 默认 `null`（列表自己造一个），接进来的唯一理由是**帧预算装置**要驱动一个
  /// 固定剧本（`tool/bench/frame_bench.dart`）：读数的可比性依赖「怎么滚」这件事
  /// 被钉住，而手势在 `flutter run` 里不可复现。页面本身不需要它 —— 换根与
  /// 下钻都不该顺手把滚动位置重置。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: rootId,
      selectedId: selectedId,
    );
    return ListView.builder(
      controller: scrollController,
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final OutlineRow row = rows[index];
        // 「别的轴根」才换根。当前根那行点了是回它自己（改地址），不是换根 ——
        // 两件事的回调不同，混成一个会让「换根后仍留在树」这条判据失去观测点。
        final bool changesRoot = row.isAxisRoot && !row.isCurrentRoot;
        return _TreeRowTile(
          row: row,
          onTap: changesRoot ? onChangeRoot : onDrill,
        );
      },
    );
  }
}

class _TreeRowTile extends StatelessWidget {
  const _TreeRowTile({required this.row, required this.onTap});

  final OutlineRow row;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Layer? layer = row.layer;

    return InkWell(
      key: treeRowKey(row.nodeId),
      onTap: () => onTap(row.nodeId),
      child: Container(
        height: treeRowHeight,
        color: row.isSelected ? colors.primaryContainer : null,
        padding: EdgeInsets.only(
          // 缩进 = 相对当前根的段数 × 单级量（`SPEC-TREE-008`）。这里**不读**
          // `row` 之外的任何层级信息：槽位序号、绝对层深都不该进来。
          left: treeRowLeadingGap + row.indent * treeLevelIndent,
          right: treeRowLeadingGap,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                row.label,
                overflow: TextOverflow.ellipsis,
                style: row.isAxisRoot ? text.titleSmall : text.bodyMedium,
              ),
            ),
            if (layer != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  // 结构节点没有 `layer`，所以走到这里的都是可学节点。
                  layerLabels[layer] ?? layer.name,
                  style: text.labelSmall?.copyWith(color: colors.outline),
                ),
              ),
            if (row.isCurrentRoot)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '当前',
                  key: treeCurrentRootMarkKey,
                  style: text.labelSmall?.copyWith(color: colors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
