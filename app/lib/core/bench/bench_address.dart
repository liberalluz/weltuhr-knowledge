/// 装置该把地址钉在哪一层（`R-22` 的场景选择）。
///
/// ## 为什么这件事需要单独一个文件
///
/// `treeOutline` 只沿**选中路径**逐级展开（`SPEC-TREE-003`），不是全展开。于是
/// 「行集合有多大」取决于这条路径上每一层的**兄弟有多少**，而不是链有多长 ——
/// 学科轴第一个门类下只有一个一级学科，沿它走八级累计不到二十行，在一屏三十几行
/// 的视口里根本不滚。装置若照「沿第一条子链下钻到底」取地址，跑完只会报
/// 「可滚动范围是 0」，而那时距离「能出读数」看起来只差一步。
///
/// 抽出来的第二个理由与 [benchGate] 相同：**选错了不会报错**。装置照样跑满
/// 二十秒、照样出一行读数（只是那行会被 `_report` 判成无意义），错法与「读数怎么
/// 算」完全不同，混在 `State` 里就只能靠真机看。
///
/// ## 为什么是贪心而不是穷举
///
/// 穷举要拿每个节点当一次地址算一遍行集合：真实骨架三轴 3,375 节点，每次都重建
/// 一张行表，代价与「这个装置只跑一次」不相称。贪心的每一步只在**当前胜者**的
/// 子节点里挑，路径长度上限就是树的深度。行数靠 [treeOutline] **现算**，与界面
/// 用的是同一个纯函数 —— 另写一份估算，估错了不会有任何东西变红。
library;

import '../tree/tree_index.dart';
import '../tree/tree_outline.dart';

/// 挑一个「行集合最大」的地址：从 [rootId] 出发，每一步在子节点里挑「以它为地址
/// 时行数最多」的那个，行数不再增长就停（最多走 [maxDepth] 步）。
///
/// 结果是确定的：`childrenOf` 按官方码升序（`SPEC-TREE-011`），并列取先出现的
/// 那个 ⇒ 同一份骨架必得同一个地址、同一组行。
///
/// 返回 `rootId` 本身表示「它的子节点没有一个能展开出更多行」—— 那通常是空树或
/// 只有一层，装置据此报「可滚动范围是 0」而不是假装量到了什么。
String heaviestOutlineAddress(
  TreeIndex tree, {
  required String rootId,
  required int maxDepth,
}) {
  int rowsOf(String nodeId) => treeOutline(
        tree: tree,
        rootId: rootId,
        selectedId: nodeId,
      ).length;

  String best = rootId;
  int bestRows = rowsOf(rootId);
  for (int step = 0; step < maxDepth; step++) {
    String? winner;
    int winnerRows = bestRows;
    for (final TreeRow child in tree.childrenOf(best)) {
      final int rows = rowsOf(child.nodeId);
      // 严格大于：并列时保留先出现的（官方码小的那个）。用 `>=` 会让结果依赖
      // 遍历顺序的细节，而那样换一个 `childrenOf` 实现就换一组读数。
      if (rows > winnerRows) {
        winnerRows = rows;
        winner = child.nodeId;
      }
    }
    if (winner == null) {
      break;
    }
    best = winner;
    bestRows = winnerRows;
  }
  return best;
}
