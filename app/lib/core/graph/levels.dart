/// `⪯` 上的 Kahn 层号 —— 这就是 `φ`（`SPEC-VIEW-002`）。
///
/// `entity-fields.md` §2 把 `Item.depth` 定义为「**派生** = `φ`，不入库」，
/// 派生源就是本文件的函数。三处用它：宇宙视图的 `φ` 坐标、树视图的缩进、
/// 详情页的邻域排序。
///
/// 层号 = **最长的前置链长度**（`max(前置层号) + 1`），不是最短 —— 用最短会把
/// 一个「有两条前置链、其中一条很深」的项摆到前一层，看起来像前置已学完。
library;

import '../entities/content.dart';

/// 边端点不在 `nodeIds` 里时的处置：**忽略这条边**。
///
/// 理由与解析层一致（`pack_parse.dart` 的注释）：存在性校验在构建期
/// `validator.py` 已拒过，客户端再写一份就是**两份会分叉的判据**；
/// 而坏掉时的表象是「少几条边 / 层号偏小」，不是崩溃。
Map<String, int> kahnLevels({
  required Iterable<String> nodeIds,
  required Iterable<Edge> edges,
}) {
  final Map<String, int> level = <String, int>{
    for (final String id in nodeIds) id: 0,
  };
  final Map<String, int> indegree = <String, int>{for (final String id in level.keys) id: 0};
  final Map<String, List<String>> successors = <String, List<String>>{};

  for (final Edge edge in edges) {
    if (!level.containsKey(edge.from) || !level.containsKey(edge.to)) {
      continue;
    }
    successors.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
    indegree[edge.to] = (indegree[edge.to] ?? 0) + 1;
  }

  // Kahn：入度 0 的先入队；出边时把层号传播给后继，取较大者。
  final List<String> queue = <String>[
    for (final MapEntry<String, int> entry in indegree.entries)
      if (entry.value == 0) entry.key,
  ];
  // 顺序只影响出队顺序，不影响层号（层号取 max）。排序一次，让同一份包
  // 每次算出的中间状态都一样，便于排查。
  queue.sort();

  int head = 0;
  while (head < queue.length) {
    final String current = queue[head];
    head += 1;
    final int nextLevel = (level[current] ?? 0) + 1;
    for (final String to in successors[current] ?? const <String>[]) {
      if (nextLevel > (level[to] ?? 0)) {
        level[to] = nextLevel;
      }
      final int remaining = (indegree[to] ?? 0) - 1;
      indegree[to] = remaining;
      if (remaining == 0) {
        queue.add(to);
      }
    }
  }

  if (head < level.length) {
    final List<String> stuck = <String>[
      for (final MapEntry<String, int> entry in indegree.entries)
        if (entry.value > 0) entry.key,
    ]..sort();
    throw FormatException('`⪯` 有环，无法定 φ：${stuck.join(" / ")}（`SPEC-FND-005`）');
  }

  return level;
}
