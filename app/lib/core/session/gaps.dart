/// 缺口回补 —— 「学过、但连续两次没过」的项（`SPEC-STEP-021` / `C-09`）。
///
/// ## 缺口是一个**派生值**，不是一条事件
///
/// `STEP-021` 原文写「生成缺口事件」，但事件表（`event-types.md` §二）里没有这个
/// 类型。裁定（2026-10-28）：缺口**不写事件** —— 「这一项连续两次未过」已经能从
/// `item_graded` 序列数出来，再记一条会让同一件事有两份真相，而两份真相必然在
/// 某次漏写或重复写之后开始打架。这与 `STEP-009`「游标由 fold 算、不建表」同一
/// 口径。
///
/// ## 两条出口的区别只在一个数
///
/// | 类 | 判据 | 出口 |
/// |---|---|---|
/// | 没学会 | 连续未过 < [failStreakToGap] | 重跑该项（`restartItem`） |
/// | 前置缺 | 连续未过 ≥ [failStreakToGap] | 进缺口回补队列 |
///
/// 「连续」的计数在 `fold` 里维护（见 `FoldedState.consecutiveFails`）—— 排序与
/// 去重沿用 `fold` 那一套，本文件只做判定，**不重算序列**。
library;

import '../constants.dart';
import '../events/fold.dart';

/// 这一项算不算缺口。
///
/// 只看次数，不看「是否已学过」：已 `item_passed` 的项复习时连续两次未过，同样
/// 是前置缺 —— 这正是 `STEP-021` 验收向量写的「同项连续两次未过（跨会话）」。
bool isGapStreak(int consecutiveFails) => consecutiveFails >= failStreakToGap;

/// 从折叠结果挑出缺口项的 id。
///
/// 只挑次数达阈值的：`fold` 把「中间合格」写成 0 而不是删键，所以这里按 `>=`
/// 筛，不需要额外判空。
Set<String> gapItemIds(FoldedState folded) {
  final Set<String> gaps = <String>{};
  for (final MapEntry<String, int> entry in folded.consecutiveFails.entries) {
    if (isGapStreak(entry.value)) {
      gaps.add(entry.key);
    }
  }
  return gaps;
}
