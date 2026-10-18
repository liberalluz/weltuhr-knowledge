/// `⪯` 的**子树划分** —— 域内、以「没有任何同域前置」的项为根。
///
/// ## 为什么抽出来
///
/// 同一件事现在有两处要看：`Z1` 的恒星系暗斑数（`VIEW-037`：数量 =
/// **真实**恒星系数，不为好看凑数）与 `Z2` 的亮结（`VIEW-038`：亮结 = `⪯`
/// 子树，单项子树点进去直接 `Z4`）。两处各写一遍的话，哪天「暗斑数 ≠ 亮结数」
/// 不会有任何东西变红 —— 而那一对数字是**同一层意思的两个尺度**
/// （远看暗斑、近看亮结），本来就该恒等。
///
/// ## 三条口径
///
/// 1. **只看同域**：跨域边不算前置。`⪯` 在全局是一张图，而 `Z1` / `Z2` 画的是
///    一个域；把跨域前置算进来会让一个域里的项「没有根」，那朵云就永远画不出
///    亮结。
/// 2. **根按 `items` 的传入顺序**：调用方给的是包内出现顺序，两处顺序不同会让
///    「第 k 个亮结」在两次调用里指到不同的子树。
/// 3. **成员含根**：亮结是可点的容器，点它进的是**整棵子树**，根自己也在里面。
///
/// ## 已知缺口：多前置的项会出现在两棵树里
///
/// 一个项若有两条同域前置且分属两棵子树，从两个根做可达都能走到它 ⇒ 它同时
/// 属于两棵子树。当前三个包的 `⪯` 都是链／树（每项至多一个前置），不存在这种
/// 情形；真出现时「两棵子树加起来大于域内项数」是**如实**的，不是数错了。
library;

import '../entities/content.dart';

/// 一棵 `⪯` 子树。
class PrereqSubtree {
  const PrereqSubtree({required this.rootId, required this.memberIds});

  /// 子树根：域内没有任何同域前置的那一项。
  final String rootId;

  /// 成员（**含根**），按调用方 `items` 的传入顺序。
  final List<String> memberIds;

  int get size => memberIds.length;

  /// 单项子树 —— `VIEW-038`：`Z2` 点它**跳过 `Z3`** 直接进 `Z4`。
  /// 给一个只有一颗行星的恒星系画共面轨道是纯粹的空转。
  bool get isSingle => memberIds.length <= 1;
}

/// 把 [items]（同一域内的项）按 `⪯` 划成若干棵子树。
///
/// [edges] 给整个包的边即可 —— 跨域的会被忽略（口径 1）。空输入返回空列表：
/// 没有项就没有子树，而不是「一棵空树」。
List<PrereqSubtree> subtreesInDomain({
  required List<Item> items,
  required Iterable<Edge> edges,
}) {
  if (items.isEmpty) {
    return const <PrereqSubtree>[];
  }
  final List<String> order = <String>[for (final Item item in items) item.id];
  final Set<String> ids = order.toSet();

  final Map<String, List<String>> successors = <String, List<String>>{};
  final Map<String, int> indegree = <String, int>{for (final String id in order) id: 0};
  for (final Edge edge in edges) {
    final String from = edge.from;
    final String to = edge.to;
    if (!ids.contains(from) || !ids.contains(to)) {
      continue;
    }
    successors.putIfAbsent(from, () => <String>[]).add(to);
    indegree[to] = (indegree[to] ?? 0) + 1;
  }

  final List<PrereqSubtree> subtrees = <PrereqSubtree>[];
  for (final String rootId in order) {
    if ((indegree[rootId] ?? 0) > 0) {
      continue;
    }
    // 广度优先收集可达集。环不会被漏掉：`kahnLevels()` 在同一份边上已经抛过
    // 「`⪯` 有环」，这里再判一次等于立第二套判据。用 visited 只是为了在
    // 环状坏数据上不至于死循环。
    final Set<String> visited = <String>{rootId};
    final List<String> queue = <String>[rootId];
    for (int head = 0; head < queue.length; head++) {
      for (final String to in successors[queue[head]] ?? const <String>[]) {
        if (visited.add(to)) {
          queue.add(to);
        }
      }
    }
    subtrees.add(
      PrereqSubtree(
        rootId: rootId,
        memberIds: <String>[
          for (final String id in order)
            if (visited.contains(id)) id,
        ],
      ),
    );
  }
  return subtrees;
}
