/// 事件 id 的生成规则：**由 HLC 派生**，不引入 uuid 依赖。
///
/// ## 为什么 HLC 够
///
/// 事件 id 的唯一性判据只有一条：同一台设备、同一毫秒内连发多条不能撞。而
/// [Hlc] 的三元组 `(physical, counter, deviceId)` 本身就是为这件事造的 ——
/// `HlcClock.next` 在物理时间持平时把 `counter` 加一，物理时间前进时归零。
/// 所以 `(deviceId, physical, counter)` 在单设备内严格单射，跨设备靠 deviceId
/// 分开。
///
/// ## 为什么不加 UUID
///
/// 加了就等于引入一条「与排序无关的第二套唯一性」：id 看着随机，而 `hlc` 才是
/// 排序依据，两者长期并存会让人误以为 id 有序。宁可让 id 与 `hlc` **一一对应**，
/// 看 id 就知道是哪台设备哪一毫秒发的。
///
/// 分隔用 `:`：id 是 opaque 值，不需要被解析，选一个 deviceId 里几乎不会出现的
/// 字符即可（deviceId 惯用 uuid 风格，含 `-`）。
library;

import 'event.dart';

String eventIdFor(Hlc hlc) => '${hlc.deviceId}:${hlc.physical}:${hlc.counter}';
