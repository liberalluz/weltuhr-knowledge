/// 四类落点 → 树的动作（`SPEC-TREE-009` / `010`）。
///
/// 只回答一件事：**给定一个结果，它落在树的哪一处**。检索算法、索引结构、
/// 搜索框交互都不在这里（`SPEC-TREE-009`：`ADR-0006` 把「空间内搜索」列为
/// 未定项，拿未裁定的能力约束已裁定的结构会造出第二处会分叉的判据）。
///
/// 可观测判据只有一条：**地址变没变**（`SPEC-TREE-010`）。前三类改地址，
/// 第四类只加筛选 —— 这与 `FND-006` 的坐标 / 容器二分同源。
library;

import '../enums.dart';
import 'tree_index.dart';

/// 一个落点。
sealed class Landing {
  const Landing();
}

/// 落在某个节点上。展开到它并选中，面包屑 = 它的 `path`。
final class NodeLanding extends Landing {
  const NodeLanding(this.nodeId);

  final String nodeId;
}

/// 落在某个包上。展开到该包覆盖子树的根（载荷包 = 恒星）。
final class PackLanding extends Landing {
  const PackLanding(this.pluginId);

  final String pluginId;
}

/// 落在某条轴上。换根到该轴根，收起到第 2 段。
final class AxisLanding extends Landing {
  const AxisLanding(this.axis);

  final Axis axis;
}

/// 落在四类标签的一个取值上。**不改地址**，只加筛选条件。
final class TagLanding extends Landing {
  const TagLanding(this.tag);

  final String tag;
}

/// 解析结果。改地址 / 只筛选两态互斥 —— 这正是 `SPEC-TREE-010` 的二分。
class LandingResult {
  const LandingResult._({this.nodeId, this.path, this.filterTag});

  /// 改地址：落到这个节点。
  ///
  /// [nodeId] 与 [path] **同源同带**，理由与 `BreadcrumbSegment` 那一对相同：
  /// 界面按节点 id 存地址（点一行交出去的就是 id），落点只给 `path` 的话界面
  /// 得拿字符串反查回节点 —— 而反查就是第二套地址解析，两套迟早分叉。
  const LandingResult.toNode({required String nodeId, required String path})
    : this._(nodeId: nodeId, path: path);

  const LandingResult.toFilter(String tag) : this._(filterTag: tag);

  /// 目标节点 id；`null` = 本落点不改地址。
  final String? nodeId;

  /// 目标 `path`；`null` = 本落点不改地址。
  final String? path;

  /// 目标标签；`null` = 本落点不筛选。
  final String? filterTag;

  bool get changesAddress => path != null;
}

/// 落点解析器。
///
/// `packRoots` 是 `plugin_id → 该包覆盖子树的根节点 id`（**有序**）：载荷包只有一个
/// 根（`payload.attach_to` 指向的恒星，`entity-fields` §1）；骨架包覆盖三轴、
/// 有三个根，落点取**第一个算得出 `path` 的**（轴序），因为地址只能是一处。
/// 不在这里现算 `attach_to` —— 那要读 `Pack`，而解析器只该认树。
class LandingResolver {
  const LandingResolver(this._tree, this._packRoots);

  final TreeIndex _tree;
  final Map<String, List<String>> _packRoots;

  /// 未命中时返回 `null`（不是异常）：落点是界面动作，调用方拿到 `null`
  /// 就是「这一条跳不过去」，而抛异常会把「跳不过去」变成崩溃。
  LandingResult? resolve(Landing landing) {
    switch (landing) {
      case NodeLanding(:final String nodeId):
        final String? path = _tree.pathOf(nodeId);
        return path == null
            ? null
            : LandingResult.toNode(nodeId: nodeId, path: path);
      case PackLanding(:final String pluginId):
        for (final String rootId in _packRoots[pluginId] ?? const <String>[]) {
          final String? path = _tree.pathOf(rootId);
          if (path != null) {
            return LandingResult.toNode(nodeId: rootId, path: path);
          }
        }
        return null;
      case AxisLanding(:final Axis axis):
        for (final TreeRow row in _tree.axisRoots()) {
          if (row.axis == axis) {
            return LandingResult.toNode(nodeId: row.nodeId, path: row.path);
          }
        }
        return null;
      case TagLanding(:final String tag):
        return LandingResult.toFilter(tag);
    }
  }
}
