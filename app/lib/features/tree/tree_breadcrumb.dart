/// 面包屑（`SPEC-TREE-002` / `006` / `007`）。
///
/// ## 段数不在这里数
///
/// 段数与段名全部来自 [TreeIndex.breadcrumb]：`知识` + 当前节点的路径。本文件
/// 一个字符都不拼 —— 一旦这里也数一遍「第几段」，树行集合与面包屑就成了两份
/// 各自演化的真相，而 `SPEC-TREE-007` 要的恰恰是**同一个来源**（宇宙视图将来
/// 读的也是它）。
///
/// ## 三种段的可点性不同
///
/// | 段 | 可点 | 原因 |
/// |---|---|---|
/// | 第 1 段 `知识` | **否** | 它不是节点、没有地址（`SPEC-TREE-002`） |
/// | 中间段（祖先） | 是 | 点它 = 改地址（上移），行集合跟着收 |
/// | 末段（当前地址） | **否** | 点了地址不变，给个能点的样子只是让人多点一次 |
///
/// ⚠️ **树永远并列列出三条轴根**（`SPEC-TREE-003`），所以「回到最外层」不是一个
/// 可以离开的状态、也不需要入口。第 1 段因此只是**位置标记**，不是按钮。
library;

import 'package:flutter/material.dart';

import '../../core/tree/tree_index.dart';

/// 一段的 `Key`。按 `nodeId` 定，**不按第几段** —— 段数随地址变，按序号写的
/// 断言在改过地址之后指向另一段。虚拟根的空 id 也是合法键（`breadcrumb:`）。
Key breadcrumbSegmentKey(String nodeId) => ValueKey<String>('breadcrumb:$nodeId');

/// 段与段之间的分隔符。**展示字符**，不进常量表：它是排版记号，不是可调参数。
const String breadcrumbSeparator = '›';

/// 面包屑：`知识 › 学科 › 哲学 › 马克思主义哲学`。
///
/// [nodeId] 是**当前地址**（不是当前根）：地址变则段数与段名同步变
/// （`SPEC-TREE-007`），根怎么变与它无关。
class TreeBreadcrumb extends StatelessWidget {
  const TreeBreadcrumb({
    super.key,
    required this.tree,
    required this.nodeId,
    this.onJump,
  });

  final TreeIndex tree;

  /// 当前地址落在哪个节点。
  final String nodeId;

  /// 点中间段时交出去的节点 id。`null` = 整条面包屑只读。
  final ValueChanged<String>? onJump;

  @override
  Widget build(BuildContext context) {
    final List<BreadcrumbSegment> segments = tree.breadcrumb(nodeId);
    if (segments.isEmpty) {
      // 地址不在树上 —— 不画一条凭空的「知识 › ?」。宁可空着，让调用方那边
      // 的空态说明去解释（`treeOutline` 对同一情形也选择「只给轴根」）。
      return const SizedBox.shrink();
    }
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < segments.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  breadcrumbSeparator,
                  style: text.bodySmall?.copyWith(color: colors.outline),
                ),
              ),
            _segment(context, segments[i], isLast: i == segments.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    BreadcrumbSegment segment, {
    required bool isLast,
  }) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool clickable = !segment.isVirtualRoot && !isLast && onJump != null;
    final Widget label = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        segment.label,
        style: isLast
            ? text.titleMedium
            : (clickable
                  ? text.bodyMedium?.copyWith(color: colors.primary)
                  : text.bodyMedium),
      ),
    );
    if (!clickable) {
      return KeyedSubtree(
        key: breadcrumbSegmentKey(segment.nodeId),
        child: label,
      );
    }
    return InkWell(
      key: breadcrumbSegmentKey(segment.nodeId),
      onTap: () => onJump!(segment.nodeId),
      child: label,
    );
  }
}
