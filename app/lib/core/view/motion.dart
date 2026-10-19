/// 运动时钟、相位与减速停转（`C-54` / `C-55` / `C-56` / `C-57` · `V-1i`）。
///
/// 整条链路只有三步：**时钟 → 速率 → 相位**。
///
/// ```
/// dt ──advanceClock(·, ·, factor)──▶ clock ──orbitPhase(·, T)──▶ phase
///         ▲                            ▲
///         └── governorFactor(距离) ─────┘   （`C-57`：贴近可点对象就慢下来）
/// ```
///
/// ## 为什么时钟是「累计秒数」而不是控制器进度
///
/// `AnimationController..repeat()` 走完一个周期会把 `value` 归零。用它当相位源，
/// 凡是**周期不能整除控制器周期**的轨道，都会在归零那一帧跳一下 —— `Z3` 的
/// `T_i = C-56 · (a_i / a_inner)^1.5` 正是这种：它与 `C-55` 的 72 s 不成整数比。
/// 跳变只在屏幕上一闪而过，不会有任何断言变红，所以在这里从结构上排掉：
/// 时钟只增不减，相位是它的函数。
///
/// ## 为什么速率乘在时钟上、不乘在相位上
///
/// 相位乘系数在「指针抬起的这一刻」会跳：`相位 × 0` 就地冻结，`相位 × 1`
/// 又从当前位置继续 —— 中间少掉的是那段时间，而画面上表现为「忽然往前蹿一下」。
/// 乘在速率上则是把这段时间**积分**进去，停与走都连续。
///
/// ## 三个函数都是纯函数
///
/// 「转多快、什么时候停、相位连不连续」全部可算，不必起 widget 去肉眼看。
library;

import '../constants.dart' show fullTurnRadians;

/// [clockSeconds] 在周期 [periodSeconds] 内的相位，`0 ≤ phase < 1`。
///
/// `clockSeconds` 为负时按 `Dart` 的 `%` 语义折回正区间（结果符号跟除数走），
/// 于是 `-0.01` 落在 `0.999…` 而不是 `-0.0004` —— 时钟理论上不会倒退，但
/// 重启 ticker 的那一帧 `dt` 可能为负（见 [advanceClock]），折回比抛异常更稳。
///
/// [periodSeconds] 必须是正数：0 或负数没有「一个周期」这回事，静默取 0 会让
/// 相位恒为 0，画面从此不动而没有任何东西报错。
double orbitPhase(double clockSeconds, num periodSeconds) {
  if (!periodSeconds.isFinite || periodSeconds <= 0) {
    throw ArgumentError.value(
      periodSeconds,
      'periodSeconds',
      '周期必须是正数（0 或负没有「一个周期」这回事）',
    );
  }
  final double turns = clockSeconds / periodSeconds;
  if (!turns.isFinite) {
    return 0;
  }
  final double fraction = turns % 1.0;
  return fraction < 0 ? fraction + 1.0 : fraction;
}

/// 屏幕上的旋转角（弧度）= 相位 × 2π。`C-54` 的盘自转与 `C-55` 的构型公转
/// 都走这一个入口 —— 两处各写一遍 `2π · t / T`，日后一处改成角速度就分叉了。
double spunRadians(double clockSeconds, num periodSeconds) =>
    orbitPhase(clockSeconds, periodSeconds) * fullTurnRadians;

/// 减速停转的速率系数（`C-57`），取值 `[0, 1]`。
///
/// - 距离 `≤ stopRadius` ⇒ **0**：贴到可点对象上就完全停住，否则点不中；
/// - 距离 `≥ slowRadius` ⇒ **1**：常速；
/// - 中间线性。
///
/// ⚠️ 判据是「离**最近可点对象**的距离」，不是「指针在不在盘内」：`Z1` 的盘
/// 铺满全屏，后者等于「指针在屏幕上」⇒ 永远不转（`constants.md` 明写这条）。
///
/// 系数**单调不增**：距离越近越慢。这一条换来了收敛性 —— 物体靠近指针 ⇒ 变慢
/// ⇒ 更靠不近，于是停在 `stopRadius` 外一点点，不会来回振荡。
///
/// `distance` 非有限（`NaN` / 无穷）时返回 1：算不出距离就照常转，
/// 「不知道」不该被读成「停在原地」。
double governorFactor({
  required double distance,
  required double stopRadius,
  required double slowRadius,
}) {
  if (!slowRadius.isFinite || !stopRadius.isFinite || slowRadius <= stopRadius) {
    throw ArgumentError(
      'slowRadius ($slowRadius) 必须大于 stopRadius ($stopRadius)：'
      '写反或相等会让减速区间消失，而画面上表现只是「转得怪」',
    );
  }
  if (!distance.isFinite) {
    return 1;
  }
  if (distance <= stopRadius) {
    return 0;
  }
  if (distance >= slowRadius) {
    return 1;
  }
  return (distance - stopRadius) / (slowRadius - stopRadius);
}

/// 推进累计时钟：`clock + dt × factor`。
///
/// 三条防御各对应一种「画面上看不出来但一定错」的情况：
/// - `dt ≤ 0` 或非有限：`Ticker` 重启后第一帧的 `elapsed` 从零重新计，差值会是
///   负数。照加就是整盘倒转一下 —— 只错一帧，肉眼几乎抓不到。
/// - `factor` 非有限或 ≤ 0：停转。返回原值而不是原地不动地「加 0」，是为了让
///   「时钟只增」这条不变量在浮点上严格成立。
/// - `factor > 1`：`governorFactor` 不可能给出大于 1 的值。夹住它，让「算错了」
///   表现为速度不对，而不是时钟飞走。
double advanceClock(double clockSeconds, double dtSeconds, double factor) {
  if (!dtSeconds.isFinite || dtSeconds <= 0) {
    return clockSeconds;
  }
  if (!factor.isFinite || factor <= 0) {
    return clockSeconds;
  }
  final double step = dtSeconds * (factor > 1 ? 1 : factor);
  final double next = clockSeconds + step;
  return next.isFinite ? next : clockSeconds;
}
