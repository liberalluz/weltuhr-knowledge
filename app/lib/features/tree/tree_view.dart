/// 容器树的界面层（`SPEC-TREE-002` / `003` / `004` / `005` / `008` / `012`）。
///
/// ## 这里只有「画」和「把手势交出去」
///
/// 行集合由 [treeOutline] 算好，地址由调用方持有 —— 本文件不知道「当前地址」
/// 是怎么存的，也不知道换根之后要不要跳页。两件事分开的理由是失败时的含义
/// 不同：行集合算错是「树长得不对」，手势接错是「点了没反应 / 点错地方」。
///
/// ## 可点的只有三种，其余三种点了没反应
///
/// 可点：子节点（改地址）· 面包屑祖先（不在此文件）· 全树态下的**另一条**轴根
/// （换根）。不可点：虚拟根 `知识` · 计数行「还有 M 项」· **当前轴根**（它已经
/// 展开了，再点等于没点）—— 三者都交 `onTap: null`，靠 `InkWell` 自己关掉
/// 水波纹，而不是在回调里判一下再吞掉：后者会让「点了有反馈但什么都没发生」
/// 与「这行本来就不能点」在观感上打平。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/tree/tree_index.dart';
import '../../core/tree/tree_outline.dart';

/// 一行的 `Key`：测试与「点第几行」都按 `nodeId` 定位，不按行号（行号会随
/// 展开范围变，按行号写的断言在换根之后指向另一行）。
Key treeRowKey(String nodeId) => ValueKey<String>('tree-row:$nodeId');

/// 虚拟根 `知识` 那一行的 `Key`。它没有 `nodeId`，用 [treeRowKey] 会和计数行
/// 撞成同一个 `''`，同一列表里重复 `Key` 直接抛错。
const Key treeVirtualRootRowKey = ValueKey<String>('tree-virtual-root');

/// 计数行的 `Key`。每一级至多一个，用缩进级数区分。
Key treeOverflowRowKey(int indent) => ValueKey<String>('tree-overflow:$indent');

/// 「当前」标记（`SPEC-TREE-003`）。只应出现一次 —— 当前轴根只有一个。
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
    this.mode = TreeMode.singleAxis,
    this.scrollController,
  });

  final TreeIndex tree;

  /// 当前根（`SPEC-TREE-005` 换的是它）。它只用来定「当前轴」—— 行集合由
  /// [selectedId] 定，换根到中间节点不改变行集合。
  final String rootId;

  /// 当前地址所在节点。
  final String? selectedId;

  /// 树的形态（`SPEC-TREE-003`）：单轴态只出一条轴根，全树态三条。
  final TreeMode mode;

  /// 下钻 / 选中：改地址。
  final ValueChanged<String> onDrill;

  /// 换根：改根、留在树（不触发视图切换）。**只在全树态**点另一条轴根时调用。
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
      mode: mode,
    );
    return ListView.builder(
      controller: scrollController,
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final OutlineRow row = rows[index];
        return _TreeRowTile(row: row, onTap: _onTapOf(row));
      },
    );
  }

  /// 这一行点了交哪个回调；`null` = 不可点。
  ///
  /// 「别的轴根」才换根。当前轴根那行点了什么都不做（`SPEC-TREE-004` 的
  /// 「无反应」表），因为它已经展开了 —— 顺手改成「退回单轴态」的话，地址与
  /// 画面都不变，用户看到的是「点了没反应」，与判据里的「无反应」长得一样却
  /// 走了两套代码。
  ValueChanged<String>? _onTapOf(OutlineRow row) {
    if (!row.isClickable) {
      return null;
    }
    if (row.isAxisRoot) {
      return row.isCurrentRoot ? null : onChangeRoot;
    }
    return onDrill;
  }
}

class _TreeRowTile extends StatelessWidget {
  const _TreeRowTile({required this.row, required this.onTap});

  final OutlineRow row;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Layer? layer = row.layer;
    final ValueChanged<String>? tap = onTap;

    return InkWell(
      key: _keyOf(row),
      onTap: tap == null ? null : () => tap(row.nodeId),
      child: Container(
        height: treeRowHeight,
        color: row.isSelected ? colors.primaryContainer : null,
        padding: EdgeInsets.only(
          // 缩进 = 相对 `知识` 的段数 × 单级量（`SPEC-TREE-008`）。这里**不读**
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
                style: _labelStyle(text, colors),
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

  static Key _keyOf(OutlineRow row) {
    if (row.isVirtualRoot) {
      return treeVirtualRootRowKey;
    }
    if (row.isOverflow) {
      return treeOverflowRowKey(row.indent);
    }
    return treeRowKey(row.nodeId);
  }

  /// 三种行的字面：轴根与 `知识` 用强调字重，计数行退成次要色。
  ///
  /// 计数行**不做成按钮样式**：它不是节点，点了不改地址；给它一点灰度，比在
  /// 它旁边写一句「不可点」更省地方。
  TextStyle? _labelStyle(TextTheme text, ColorScheme colors) {
    if (row.isOverflow) {
      return text.bodySmall?.copyWith(color: colors.outline);
    }
    if (row.isVirtualRoot) {
      return text.titleSmall;
    }
    return row.isAxisRoot ? text.titleSmall : text.bodyMedium;
  }
}
