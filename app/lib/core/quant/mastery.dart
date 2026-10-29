/// 掌握度与三层状态 —— `QUANT` 的取数层。
///
/// 本文件只做**取数**，不做展示：`d` 怎么来、`s` 怎么归一、两者怎么相乘、
/// 三层状态怎么判，全在这里；界面怎么画归 `VIEW`（轨道环的填充比例与线型）。
/// 因此本文件不引 Flutter，也不引 `FoldedState` —— 调用方给布尔与数值即可。
///
/// 三条口径容易写错，逐条对应裁定：
/// - `d` 的分母**不是 6**，是可外化格数（`QUANT-006`）；
/// - `s` 用 `S` 不用 `R`（`QUANT-005`）—— `R` 会随时间自己掉，环会自己变暗；
/// - `score` **不进公式**（`QUANT-004`）—— 它已经通过 FSRS 作用于 `D` / `S`。
library;

import '../constants.dart';
import '../entities/node.dart';

/// 三层学习状态（`STEP-002`）：**未学 → 已学 → 毕业，单调不可逆**。
///
/// 已学看「有没有 `item_passed` 事件」（`QUANT-003`），不看掌握度阈值 ——
/// 用阈值判会让复习没考好时进度自己往回跳。
enum LearningStage { unlearned, learned, graduated }

/// 深度 `d` = 齐备格 / 可外化格。
///
/// 「不可外化」不入分母：语音项与默会项的六格大多没有外部形态，按 6 作分母会
/// 让它们的掌握度永久接近 0，而那不是「没学会」，是对默会类知识的系统性歧视
/// （`QUANT-006`）。
///
/// **分母为 0 的情况在构建期已拒收**（内容校验的 `E-REQ-NO-EXTERNAL`）。真走到
/// 这里说明内容侧漏了校验：抛错而不是给默认值 —— 给了默认值，这类项会安静地
/// 算出一个假的深度，且再也没有东西能发现它。
double depthOf(LearnableNode node) {
  final int total = node.requirements.externalizableCount;
  if (total == 0) {
    throw StateError('${node.id} 的可外化格为 0，应在内容校验期被拒收');
  }
  return node.requirements.completeCount / total;
}

/// 记忆强度 `s = S / (S + S₀)`，`S₀` = `C-01`（天）。
///
/// 饱和归一：`S` 越大越接近 1、但永不达到，所以掌握度是连续值、可以回落，
/// 与「进度离散且永不倒退」是两套数据（`QUANT-001`）。
double memoryStrengthOf(double stability) =>
    stability / (stability + sZeroDays);

/// 掌握度 `mastery = d × s`；打卡式再乘 `C-25`。
///
/// [stability] 为 `null` 表示这项还没有 `SrsState`（从未判过分）⇒ 掌握度为 0。
/// [isCheckin] 为真时乘封顶系数：打卡项没有检验输入，`S` 只停在初值、且永不
/// 毕业，所以「照算但封顶」—— 不归零是因为「我确实读了一小时」是弱证据，不该
/// 被当作没发生（`QUANT-007` / `QUANT-008`）。
///
/// ⚠️ 封顶用**乘**不用取小：`min(C-25, d × s)` 会把几乎所有打卡项压到同一个值，
/// `d` 与 `s` 的差异全部消失，那就变成「一律记 0.5」，与「照算」冲突。
double masteryOf({
  required LearnableNode node,
  required double? stability,
  required bool isCheckin,
}) {
  final double d = depthOf(node);
  final double s = stability == null ? 0 : memoryStrengthOf(stability);
  final double base = d * s;
  return isCheckin ? checkinCap * base : base;
}

/// 毕业判据**只看 `S`**：`S ≥ C-02`，不加 `d` 下限（`QUANT-009`）。
///
/// 因此会出现「记得牢但学得浅」的毕业项（`d = 0.5`、`S = 180` ⇒ 掌握度 43%）。
/// 这不是漏洞：出口问的是「能不能用」，与「懂多深」无关；处置是能力清单里同时
/// 显示掌握度，让「学得浅」自己显现出来。
bool reachedGraduation(double stability) => stability >= graduationSDays;

/// 三层状态。**毕业优先** —— 已毕业的项一定有 `item_passed`，反过来不成立。
LearningStage stageOf({required bool passed, required bool graduated}) {
  if (graduated) {
    return LearningStage.graduated;
  }
  return passed ? LearningStage.learned : LearningStage.unlearned;
}
