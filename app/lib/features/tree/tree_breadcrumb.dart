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
/// ## 宽度不够时省中间、保首末（`SPEC-TREE-012` 的连带）
///
/// 面包屑唯一的作用是回答「我在哪」。原先整条横向滚动、默认停最左：职业轴名字
/// 长，下钻两层就把**当前地址**顶出屏外，剩下的是三个已经不相关的祖先。
///
/// 现在首段与末段**固定在两端**，只有中间段进滚动区（初始停在最右）。屏幕再
/// 窄，「知识 › … › 当前」也在；被省掉的是中间那些祖先 —— 它们能从树行上读到。
library;

import 'package:flutter/material.dart';

import '../../core/tree/tree_index.dart';

/// 一段的 `Key`。按 `nodeId` 定，**不按第几段** —— 段数随地址变，按序号写的
/// 断言在改过地址之后指向另一段。虚拟根的空 id 也是合法键（`breadcrumb:`）。
Key breadcrumbSegmentKey(String nodeId) =>
    ValueKey<String>('breadcrumb:$nodeId');

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
      // 的空态说明去解释（`treeOutline` 对同一情形也选择「只留 `知识`」）。
      return const SizedBox.shrink();
    }
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BreadcrumbSegment first = segments.first;
    final BreadcrumbSegment last = segments.last;
    final List<BreadcrumbSegment> middle = segments.length > 2
        ? segments.sublist(1, segments.length - 1)
        : const <BreadcrumbSegment>[];

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        _segment(context, first, isLast: segments.length == 1),
        if (middle.isNotEmpty) ...<Widget>[
          _separator(text, colors),
          // 只有中间段可缩：首末两段是判据要求「必须看得见」的那两段。
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < middle.length; i++) ...<Widget>[
                    if (i > 0) _separator(text, colors),
                    _segment(context, middle[i], isLast: false),
                  ],
                ],
              ),
            ),
          ),
          _separator(text, colors),
        ] else if (segments.length > 1)
          // 只有两段（`知识 › 轴根`）时中间段为空，首末之间仍要一个分隔符 ——
          // 少了它，两段会连成「知识学科」。
          _separator(text, colors),
        Flexible(child: _segment(context, last, isLast: true)),
      ],
    );
  }

  Widget _separator(TextTheme text, ColorScheme colors) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      breadcrumbSeparator,
      style: text.bodySmall?.copyWith(color: colors.outline),
    ),
  );

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
        // 末段被挤到极限时截尾而不是溢出：判据要的是「末段可见」，可见的
        // 那一段名字不完整，仍比整段飞出屏幕强。
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
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
