/// 本地 HLC 发号器（`SPEC-FND-011`）。
///
/// 只做三件事：**发号**、**接收远端推进**、**重启后接着走**。
/// 不做 clamp —— 物理时间由服务端校正，客户端越权校正会让「本地时钟被谁改过」
/// 变成第二个真相源。
///
/// 三条不变量（任一破了，事件流就不再是全序，`D`/`S` 的折叠顺序会飘）：
/// 1. 同一个 clock 实例发出的 HLC **严格递增**；
/// 2. 物理时间**只进不退** —— 用户把系统时钟调回 2020，`physical` 仍留在高水位；
/// 3. 发出的 HLC **恒带本地 `deviceId`** —— 拿远端 HLC 直接复用会把别人的
///    事件记到自己名下。
library;

import 'event.dart';

/// 一台设备的事件发号器。
///
/// 状态只有两个整数：`(physical, counter)`。`deviceId` 不是时钟状态，
/// 而是「谁发的」—— 所以 `seed` 传入别的设备的 HLC 时，只取它的
/// `physical` / `counter`，`deviceId` 仍用本地的。
class HlcClock {
  HlcClock({required this.deviceId, Hlc? seed})
    : _physical = seed?.physical ?? 0,
      _counter = seed?.counter ?? 0;

  /// 本机标识。**发出的每条事件都用它**，不从远端继承。
  final String deviceId;

  int _physical;
  int _counter;

  /// 当前高水位（= 最后发出或最后观测到的 HLC，带本地 `deviceId`）。
  Hlc get last => Hlc(physical: _physical, counter: _counter, deviceId: deviceId);

  /// 发下一条。`now` 由调用方给 —— 便于测试注入，不是为了让它可选。
  ///
  /// - 物理时间**前进** ⇒ `counter` 归零（新的一毫秒）；
  /// - 物理时间**持平或回拨** ⇒ `physical` 不动、`counter` 加一
  ///   （回拨若照抄 `now`，会让新事件排到旧事件之前）。
  Hlc next(DateTime now) {
    final int physical = now.millisecondsSinceEpoch;
    if (physical > _physical) {
      _physical = physical;
      _counter = 0;
    } else {
      _counter += 1;
    }
    return last;
  }

  /// 观测到一条远端事件后推进本地时钟（HLC 的 receive 规则）。
  ///
  /// | 远端 `physical` | 本地动作 |
  /// |---|---|
  /// | 更晚 | 跳到远端 `physical`，`counter = 远端 + 1` |
  /// | 相同 | `physical` 不动，`counter = max(本地, 远端) + 1` |
  /// | 更早 | `physical` / `counter` 都保持本地，`counter += 1` |
  ///
  /// 第三种是**必须**的：远端的旧事件不能把本地时钟拽回去，但下一个本地
  /// 事件仍要严格大于「上一个本地事件」，否则两条本地事件同号。
  Hlc observe(Hlc remote) {
    if (remote.physical > _physical) {
      _physical = remote.physical;
      _counter = remote.counter + 1;
    } else if (remote.physical == _physical) {
      _counter = (remote.counter > _counter ? remote.counter : _counter) + 1;
    } else {
      _counter += 1;
    }
    return last;
  }

  /// 重启后从库里最后一条事件恢复（`seed` 也能在构造时给，二者等价）。
  ///
  /// 只前进不后退：传入比当前水位更低的 HLC 是空操作 —— 恢复顺序不该
  /// 影响发号结果（`readAll` 的顺序本来是 `hlc` 全序，但订阅与回填可能乱）。
  void reseed(Hlc persisted) {
    if (persisted.physical > _physical) {
      _physical = persisted.physical;
      _counter = persisted.counter;
    }
  }
}
