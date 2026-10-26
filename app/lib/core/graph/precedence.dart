/// `⪯`（前提偏序）的唯一实现 —— 「哪些边参与偏序」只有这一处定义。
///
/// `entity-fields.md` §5：`⪯` = `strength = required` 边的**传递闭包**；
/// `recommended` 只影响排序建议与 UI 提示，**不构成可达性约束**。
///
/// ## 为什么单开这个文件
///
/// 同一句 `strength == required` 原先在 `levels.dart` 与 `plan/ordering.dart`
/// 各写一遍。两份同口径的过滤本身还不算「两套偏序源」，但它是**会分叉的起点**：
/// 哪天有人给 `recommended` 加一条例外，只改一处，`φ` 与体系逆序数就会对同一份
/// 数据给出互不相容的答案，而两边都不会红。`SDP` §4.2 `B15` 出口第 1 条
/// 「全项目只有一套偏序源」靠的就是这一个入口。
///
/// ⚠️ **环检测不在这里、也不该走这个入口**：`pack_reader` 的 `⪯` 环检测要覆盖
/// `required` 与 `recommended` **两类边**（同条出口判据第 2 项），它必须看到全部
/// 先修边。拿 `requiredEdgesOf` 过滤一遍，`recommended` 成环就再也报不出来 ——
/// 那不是收紧判据，是把判据删掉一半。
///
/// ## `V1` 不物化闭包
///
/// 前置集合每次现算，不建 N×N 矩阵、不留缓存（`entity-fields` §5 末句：
/// 载荷到十万级再引索引）。物化之后那份矩阵就是第二份事实，而它与边集合同步
/// 失败的唯一表现是「算错」—— 没有断言会红。
///
/// 代价要说清：`isRequiredBefore` 单次是 O(V+E)。要判「一批项里有没有项依赖
/// 批外的东西」，按批调用它会是 O(n·(V+E))；那种场景应当改成一次算出整批的
/// 前置集合再比，而不是给本文件加缓存。
library;

import '../entities/edge.dart';

/// 参与 `⪯` 的边。**唯一入口** —— 调用点不得再写一遍 `strength == required`。
Iterable<PrerequisiteEdge> requiredEdgesOf(Iterable<PrerequisiteEdge> edges) =>
    edges.where((PrerequisiteEdge edge) => edge.isRequired);

/// 某节点的**全部**前置（`required` 传递闭包，**不含自身**）。
///
/// 顺序是**自目标向上逐层**的 BFS 层序（直接前置在前、更远的前置在后），
/// 同层按 id 升序 —— 同一份边集每次给出同一个序列。这不是语义的一部分
/// （集合就是集合），但「同一份数据两次算出不同顺序」会让比对与排错无从下手，
/// 而排序几乎不要钱。
///
/// 返回空集合有三种来源（没有前置 · 端点根本不在图里 · 只有 `recommended`
/// 指向它），三种对调用方是同一件事：**不必先学任何东西**。
///
/// 自环（`from == to`）被跳过。它不是环、是**数据错误**（`cycle_check.dart`
/// 同口径），构建期以各自错误码报出；这里若把它算进去，BFS 会立刻遇到自己。
List<String> requiredPredecessorsOf({
  required String nodeId,
  required Iterable<PrerequisiteEdge> edges,
}) {
  final Map<String, List<String>> incoming = <String, List<String>>{};
  for (final PrerequisiteEdge edge in requiredEdgesOf(edges)) {
    if (edge.fromId == edge.toId) {
      continue;
    }
    (incoming[edge.toId] ??= <String>[]).add(edge.fromId);
  }

  final Set<String> seen = <String>{nodeId};
  final List<String> ordered = <String>[];
  List<String> frontier = <String>[nodeId];
  while (frontier.isNotEmpty) {
    final List<String> next = <String>[];
    for (final String current in frontier) {
      for (final String from in incoming[current] ?? const <String>[]) {
        if (seen.add(from)) {
          next.add(from);
        }
      }
    }
    next.sort();
    ordered.addAll(next);
    frontier = next;
  }
  return ordered;
}

/// `a ⪯ b` 是否成立 —— `a` 是 `b` 的前置，且 `a != b`。
///
/// 严格判定：自反部分（`a ⪯ a`）恒成立，对「还要先学什么」没有信息量，所以
/// 不进结果。名字里的 `Required` 同样是为了让人一眼看出它只沿 `required` 边。
bool isRequiredBefore({
  required String a,
  required String b,
  required Iterable<PrerequisiteEdge> edges,
}) => requiredPredecessorsOf(nodeId: b, edges: edges).contains(a);
