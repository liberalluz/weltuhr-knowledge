/// 骨架点的亮度 —— `B17b` 笔 4 · `ADR-0006` §5「亮度按掌握度映射」。
///
/// ## 为什么是「子树聚合」而不是「逐点掌握度」
///
/// 掌握度只对**可学节点**（`planet`）有定义：`masteryOf` 要 `requirements`
/// 算 `d`、要 `SrsState` 算 `s`（`mastery.dart:55`）。而球上只有骨架节点 ——
/// 载荷没有球壳可上（`placement.dart` 的 `legalSkeletonSlots` 里不存在
/// `system` / `planet`）。所以每个骨架点的亮度只能是**它子树内可学项的聚合**：
/// 「这一片天里学会了几成」。
///
/// ## 已学为什么要有底光
///
/// 照字面「亮度 = 掌握度均值」会违反 `ADR-0006:97` 的判据「已学项比未学项亮」：
/// 已学但从未判过分的项没有 `SrsState`，`masteryOf` 对它返回 0（`QUANT-004`
/// 之后 `score` 不进公式，判分才产生 `S`）—— 于是「学过一遍」与「没碰过」
/// 会一样暗。底光把这两件事分开：已学至少 [universeLearnedBaseBrightness]，
/// 未学是 0，两者之间按掌握度连续过渡。
///
/// ## 子树归属只有一处判
///
/// `inScopeOf`（`core/graph/in_scope.dart`）已经定义了「某节点是否在某子树下」，
/// 文件头明写「每处各写一遍 `ancestors.contains(root)` 迟早分叉」。本文件直接
/// 调它，不另写一份遍历 —— 圈定计划范围与「这片天有多亮」问的是同一个问题。
library;

import '../constants.dart';
import '../entities/node.dart';
import '../graph/in_scope.dart';
import '../graph/parent_index.dart';
import 'mastery.dart';

/// 单条可学项对亮度的贡献，0..1。
///
/// 未学恒 0；已学从底光起跳，掌握度把它推到 1。**单调不减**于掌握度 ——
/// 判据「掌握得更好更亮」由这个函数的形状保证，不靠调用方补判。
double brightnessOfItem({required bool passed, required double mastery}) {
  if (!passed) {
    return 0;
  }
  final double capped = mastery.clamp(0, 1);
  return universeLearnedBaseBrightness +
      (1 - universeLearnedBaseBrightness) * capped;
}

/// 一批骨架点各自的亮度，0..1。
///
/// [skeletonIds] 是**要算的那几个点**，不是全部 3,375 个：调用方只传当前节点、
/// 来路与直接子级。这样代价是「点数 × 可学项数」，而不是「全树 × 可学项数」。
///
/// 子树里一个可学项都没有的骨架点（纯中间层、或载荷没装）返回 0 —— 按「未学」
/// 处置，而不是从结果里缺席：缺席会让调用方去猜「是没学还是没算」。
///
/// [isPassed] / [isCheckin] / [stabilityOf] 由调用方给：本层不认事件日志、不认
/// 包内容，与 `masteryOf` 同一条分层口径（取数归核心层，来源归装配层）。
Map<String, double> subtreeBrightnessOf({
  required Iterable<String> skeletonIds,
  required Iterable<LearnableNode> learnables,
  required ParentIndex parents,
  required bool Function(String itemId) isPassed,
  required bool Function(String itemId) isCheckin,
  required double? Function(String itemId) stabilityOf,
}) {
  final List<String> anchors = List<String>.of(skeletonIds);
  final Map<String, double> sums = <String, double>{
    for (final String id in anchors) id: 0,
  };
  final Map<String, int> counts = <String, int>{
    for (final String id in anchors) id: 0,
  };

  for (final LearnableNode node in learnables) {
    final bool passed = isPassed(node.id);
    // 未学不必算掌握度：结果恒 0，而 `depthOf` 对「可外化格为 0」的坏数据会抛
    // （那本该在内容校验期被拒收）。不白跑一趟，也就不会因为一个没学过的坏项
    // 把整片天打成降级态。
    final double value = passed
        ? brightnessOfItem(
            passed: true,
            mastery: masteryOf(
              node: node,
              stability: stabilityOf(node.id),
              isCheckin: isCheckin(node.id),
            ),
          )
        : 0;
    for (final String anchor in anchors) {
      if (inScopeOf(node, subtreeRoot: anchor, parents: parents)) {
        sums[anchor] = sums[anchor]! + value;
        counts[anchor] = counts[anchor]! + 1;
      }
    }
  }

  return <String, double>{
    for (final String id in anchors)
      id: counts[id] == 0 ? 0 : sums[id]! / counts[id]!,
  };
}
