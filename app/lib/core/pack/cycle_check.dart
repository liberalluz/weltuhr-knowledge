/// `⪯` 环检测 —— 客户端加载期复验（`SPEC-FND-005`）。
///
/// **为什么客户端要再做一遍**：构建期 `content/tools/validator.py` 已经拒过环，
/// 但 `pack.json` 会被手改、会被第三方分发，构建期校验管不到运行时的这份文件。
/// 只做环检测、不做全量语义校验（域在册 / 边端点存在 / `schemes` 是线性扩展）——
/// 那些重复实现会造出**两份会分叉的判据**，而环的后果最重：`φ` 是 `⪯` 上的
/// Kahn 层号（`entity-fields` §2「派生 = depth」），有环就取不出层号，
/// 整个宇宙的径向坐标直接塌掉。
///
/// 语义与 Python 侧**逐条对齐**（`validator.find_cycles`）：只报**基本环**、
/// 起点取环上最小 id、同一环只报一次、自环跳过。两边判据同源，靠这条注释和
/// `test/core/pack/cycle_check_test.dart` 的向量维持。
library;

import '../entities/content.dart';

/// 图遍历三色。
enum _Color { unvisited, onStack, done }

/// 返回全部**基本环**；每条环首尾为同一 id（`[a, b, a]`）。
///
/// 只沿「两端都是字符串且非自环」的边遍历 —— 自环（`from == to`）不是环，
/// 是**数据错误**，由构建期以各自错误码报出，加载器不为它编一条环。
List<List<String>> findCycles(List<Edge> edges) {
  final Map<String, Set<String>> adjacency = <String, Set<String>>{};
  for (final Edge edge in edges) {
    if (edge.from != edge.to) {
      (adjacency[edge.from] ??= <String>{}).add(edge.to);
    }
  }

  final List<List<String>> cycles = <List<String>>[];
  final Set<String> signatures = <String>{};
  final Map<String, _Color> color = <String, _Color>{};
  final List<String> stack = <String>[];

  void visit(String node) {
    color[node] = _Color.onStack;
    stack.add(node);
    for (final String next in _sorted(adjacency[node] ?? const <String>{})) {
      final _Color state = color[next] ?? _Color.unvisited;
      if (state == _Color.unvisited) {
        visit(next);
      } else if (state == _Color.onStack) {
        final List<String> ring = _canonical(stack.sublist(stack.indexOf(next)));
        final String signature = ring.join('\n');
        if (signatures.add(signature)) {
          cycles.add(<String>[...ring, ring.first]);
        }
      }
    }
    stack.removeLast();
    color[node] = _Color.done;
  }

  for (final String node in _sorted(adjacency.keys)) {
    if ((color[node] ?? _Color.unvisited) == _Color.unvisited) {
      visit(node);
    }
  }

  cycles.sort((List<String> a, List<String> b) => a.join('\n').compareTo(b.join('\n')));
  return cycles;
}

/// 把环旋转到以**最小 id** 起头 —— 同一个环因 DFS 入口不同会得到不同序列，
/// 不归一就会报「两个环」。
List<String> _canonical(List<String> ring) {
  int pivot = 0;
  for (int i = 1; i < ring.length; i++) {
    if (ring[i].compareTo(ring[pivot]) < 0) {
      pivot = i;
    }
  }
  return <String>[...ring.sublist(pivot), ...ring.sublist(0, pivot)];
}

List<String> _sorted(Iterable<String> values) => values.toList()..sort();
