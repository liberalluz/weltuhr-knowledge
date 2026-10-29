/// 一次判分后的 `D` / `S` / 上次复习时刻 / 累计次数 —— **派生与写入两侧共用的
/// 唯一一份递推**。
///
/// ## 为什么要单独一个文件
///
/// 毕业判据是 `S ≥ C-02`，而 `S` 只在 `fold` 里被递推出来。判分那一刻要知道新
/// `S`（决定写不写 `graduated`），两种做法都不好：**重放整条事件流**把「一次
/// 判分」变成 O(事件数)，**各写一份**则会出现两个 `S`，而 `fold` 那份是事实、
/// 判分那份只是猜测。这里把三种分支（无历史 / 有历史 / 打卡冻结）收成一个函数，
/// 两侧都调它。
///
/// ## 三条分支与各自的来源
///
/// | 分支 | 行为 | 依据 |
/// |---|---|---|
/// | 无历史 | `D` / `S` 取初值 | `fsrsInitial` |
/// | 有历史 | 按 `elapsedDays` 递推，同日走单独一支 | `fsrsNext` |
/// | 打卡式 | `S` 冻结，此后不再增长 | `QUANT-007` · `N-05` |
///
/// **打卡项也走「无历史」那一支**：它照算初值，只是之后不再更新 —— 若在这里
/// 直接返回零，打卡项的掌握度会恒为 0，与「不归零」（`QUANT-007`）相反。
library;

import '../enums.dart';
import 'fsrs.dart';

/// 评分累计量。**不含派生值**（`R(t)` / `due`）—— `due` 由 `fold` 在收尾处
/// 按 `lastReviewAt + 反解(S)` 算一次，中途重算只会留下没有消费者的半截时刻。
typedef SrsAdvance = ({
  double difficulty,
  double stability,
  DateTime lastReviewAt,
  int reps,
});

/// 喂一次评分，返回新的累计量。
///
/// [elapsedDays] 由**上次复习时刻**算出，不是上次事件时刻：同一天多次判分要落进
/// 「同日」那一支（`C-115` / `C-116`），否则刚学完再练一遍会看到隔天式的增幅。
SrsAdvance advanceSrs({
  required SrsAdvance? previous,
  required Grade grade,
  required DateTime at,
  bool checkedOnly = false,
}) {
  if (previous == null) {
    final ({double difficulty, double stability}) initial = fsrsInitial(grade);
    return (
      difficulty: initial.difficulty,
      stability: initial.stability,
      lastReviewAt: at,
      reps: 1,
    );
  }
  final double elapsedDays =
      at.difference(previous.lastReviewAt).inSeconds / Duration.secondsPerDay;
  final ({double difficulty, double stability}) next = fsrsNext(
    grade: grade,
    difficulty: previous.difficulty,
    stability: previous.stability,
    elapsedDays: elapsedDays,
    freeze: checkedOnly,
  );
  return (
    difficulty: next.difficulty,
    stability: next.stability,
    lastReviewAt: at,
    reps: previous.reps + 1,
  );
}
