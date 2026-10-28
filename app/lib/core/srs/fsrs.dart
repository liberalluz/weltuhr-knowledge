/// FSRS-5 的纯函数实现 —— 初始值、一次评分后的 `D` / `S`、可提取率、到期日。
///
/// 三条纪律：
/// 1. **参数全部取自 `constants.dart`**（`C-98`–`C-121`）—— 本文件不写数值字面量。
/// 2. **`R(t)` 不存**：只由 `S` 与经过时间现算，存了就会有第二份可能不一致的真相。
/// 3. **档位映射只有一条路**（[fsrsGradeOf]）：未过 → `Again` · 合格 → `Good` ·
///    熟练 → `Easy`。三档之外的 `Hard` 只有权重、没有入口。
///
/// **刻意不做的两件**：`fuzz`（间隔抖动）与 `maximumInterval` —— 它们只改变排期的
/// 形状，不改变 `D` / `S` 的算法；本版的 `due` 是「精确反解」，不做抖动。
library;

import 'dart:math' as math;

import '../constants.dart';
import '../enums.dart';

/// 三档 → FSRS 档位下标（`C-119`）。
int fsrsGradeOf(Grade grade) => fsrsGradeIndex[grade]!;

/// 首次评分时的 `D` 与 `S`。
///
/// **只在没有历史时调用**：`D` / `S` 一旦存在，更新走 [fsrsNext]。
({double difficulty, double stability}) fsrsInitial(Grade grade) => (
  difficulty: _initialDifficulty(grade),
  stability: _initialStability(grade),
);

/// 一次评分后的 `D` / `S`。
///
/// - [elapsedDays] 为距上次评分的天数；**同日复习走 `C-115` / `C-116` 那一支**，
///   与「隔天复习」是两套增幅 —— 合成一个式子会让「刚学完再练一遍」看不到任何变化。
/// - [freeze] 为真时原样返回（打卡项：无检验输入 ⇒ `S` 不更新、永不毕业）。
({double difficulty, double stability}) fsrsNext({
  required Grade grade,
  required double difficulty,
  required double stability,
  required double elapsedDays,
  bool freeze = false,
}) {
  if (freeze) {
    return (difficulty: difficulty, stability: stability);
  }
  final double r = fsrsRetrievability(
    stability: stability,
    elapsedDays: elapsedDays,
  );
  final double nextStability;
  if (elapsedDays <= 0) {
    nextStability = _stabilitySameDay(grade: grade, stability: stability);
  } else if (grade == Grade.fail) {
    nextStability = _stabilityAfterForget(
      difficulty: difficulty,
      stability: stability,
      retrievability: r,
    );
  } else {
    nextStability = _stabilityAfterRecall(
      grade: grade,
      difficulty: difficulty,
      stability: stability,
      retrievability: r,
    );
  }
  return (
    difficulty: _nextDifficulty(grade: grade, difficulty: difficulty),
    stability: nextStability,
  );
}

/// 可提取率 `R(t)`：`(1 + FACTOR × t / S)^DECAY`。
///
/// **入参只有 `S` 与经过时间** —— `D` 不进这个式子，它只作用于 `S` 的更新
/// （`C-102`–`C-105`）。把 `D` 塞进来会让人以为「难的东西记得更快忘」，
/// 而 FSRS 表达这件事的方式是「难的 `S` 涨得慢」。
double fsrsRetrievability({
  required double stability,
  required double elapsedDays,
}) {
  if (stability <= 0) {
    throw ArgumentError.value(stability, 'stability', '稳定度必须为正');
  }
  final double t = elapsedDays < 0 ? 0 : elapsedDays;
  return math.pow(1 + fsrsFactor * t / stability, fsrsDecay).toDouble();
}

/// 距下次复习的天数：由 `C-03` 目标保留率反解 `R(t)`。
///
/// `R(t) = r` ⇒ `t = S / FACTOR × (r^(1/DECAY) − 1)`。
/// ⚠️ 本表 `r = 0.90`、`DECAY = −0.5` 时它恰好退化成 `t = S` —— 这不是巧合，
/// 而是 FSRS 默认参数的自洽点；改任一个值都会让「天数 ≈ 稳定度」不再成立，
/// 所以这条恒等式在用例里是**断言**，不是巧合。
///
/// 下界取 1 天：`S` 很小时反解出小数天，而「今天学完今天到期」会让脉动通道
/// 在用户眼前闪一整天。
double fsrsIntervalDays({required double stability}) {
  final double raw =
      stability /
      fsrsFactor *
      (math.pow(fsrsTargetRetention, 1 / fsrsDecay) - 1);
  return math.max(1, raw);
}

/// 到期时刻 = 上次复习 + [fsrsIntervalDays]。
DateTime fsrsDueAt({
  required DateTime lastReviewAt,
  required double stability,
}) {
  final double days = fsrsIntervalDays(stability: stability);
  final int milliseconds = (days * Duration.millisecondsPerDay).round();
  return lastReviewAt.add(Duration(milliseconds: milliseconds));
}

double _initialStability(Grade grade) => switch (grade) {
  Grade.fail => fsrsW0,
  Grade.pass => fsrsW2,
  Grade.proficient => fsrsW3,
};

/// `D₀ = w4 − e^(w5·(g−1)) + 1`。
double _initialDifficulty(Grade grade) {
  final int index = fsrsGradeOf(grade);
  return _clampDifficulty(fsrsW4 - math.exp(fsrsW5 * (index - 1)) + 1);
}

/// 记得住（合格 / 熟练）：`S′ = S · (1 + e^w8 · (11 − D) · S^(−w9) · (e^(w10·(1−R)) − 1) · bonus)`。
double _stabilityAfterRecall({
  required Grade grade,
  required double difficulty,
  required double stability,
  required double retrievability,
}) {
  final double growth =
      math.exp(fsrsW8) *
      (fsrsDifficultyMax + 1 - difficulty) *
      math.pow(stability, -fsrsW9) *
      (math.exp(fsrsW10 * (1 - retrievability)) - 1);
  final double bonus = grade == Grade.proficient ? fsrsW16 : 1;
  return stability * (1 + growth * bonus);
}

/// 忘了（未过）：`S′_f = w11 · D^(−w12) · ((S + 1)^w13 − 1) · e^(w14·(1−R))`。
double _stabilityAfterForget({
  required double difficulty,
  required double stability,
  required double retrievability,
}) {
  return fsrsW11 *
      math.pow(difficulty, -fsrsW12) *
      (math.pow(stability + 1, fsrsW13) - 1) *
      math.exp(fsrsW14 * (1 - retrievability));
}

/// 同日复习：`S′ = S · e^(w17·(g − g_合格 + w18))`。
///
/// 用 `g_合格` 而不是字面 `3`：那个 `3` 就是「合格」在 `C-119` 里的下标，
/// 写成数字会在映射改档时静默失配。
double _stabilitySameDay({required Grade grade, required double stability}) {
  final int index = fsrsGradeOf(grade);
  final int goodIndex = fsrsGradeOf(Grade.pass);
  return stability * math.exp(fsrsW17 * (index - goodIndex + fsrsW18));
}

/// `D′ = D + ΔD·(10 − D)/9`，再向 `D₀(熟练)` 做一次均值回归。
double _nextDifficulty({required Grade grade, required double difficulty}) {
  final int index = fsrsGradeOf(grade);
  final int goodIndex = fsrsGradeOf(Grade.pass);
  final double delta = -fsrsW6 * (index - goodIndex);
  final double damped =
      difficulty +
      delta * (fsrsDifficultyMax - difficulty) / (fsrsDifficultyMax - 1);
  final double reverted =
      fsrsW7 * _initialDifficulty(Grade.proficient) + (1 - fsrsW7) * damped;
  return _clampDifficulty(reverted);
}

double _clampDifficulty(double value) =>
    value.clamp(fsrsDifficultyMin, fsrsDifficultyMax).toDouble();
