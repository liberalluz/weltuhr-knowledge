/// 当日两池用量 —— `C-06` / `C-07` 的唯一计量处（`SPEC-STEP-028`）。
///
/// - **按「当天已判分」扣，不按「今天排了多少」扣**：排进队列不等于学过。按已排扣，
///   排了 20 项只做 5 项就跑，第二次进来额度显示 0 —— 那是把没做的事记成欠账。
/// - **同一项当天只计一次**，按当天第一次判分的性质归池（判分前已 `item_passed`
///   ⇒ 复习，否则新学）。
/// - **日界由调用方给的时区偏移定**，本文件不读系统时区 —— 否则同一份事件在测试机
///   上会算出不同结果。
/// - **缺口不出现在这里**：额度管两个池子，缺口是第三条源（`SPEC-STEP-003`），既不
///   计入这两个数、也不受额度约束。
library;

import '../events/event.dart';

/// 当天已用掉的两池额度。
class DailyQuotaUsage {
  const DailyQuotaUsage({required this.reviewed, required this.learned});

  /// 当天判过分、且判分前该项已学过的项数（复习池已用）。
  final int reviewed;

  /// 当天首次判分、且此前从未学过的项数（新学池已用）。
  final int learned;

  static const DailyQuotaUsage none = DailyQuotaUsage(reviewed: 0, learned: 0);
}

/// 用满为止的剩余额度：`cap − used`，负数按 0。
///
/// 分开写而不是 `clamp`：`clamp` 得写三个字面量，而这里只有一个边界要表达。
int quotaRemaining({required int cap, required int used}) =>
    used >= cap ? 0 : cap - used;

/// 折出「今天已经用掉多少」。
///
/// [events] 与 `fold` 吃的是同一份事件：用量只由事件决定，不另读一份计数表。
/// [asOf] 是「现在」，[utcOffset] 是本地时区相对 UTC 的偏移（东八区为 `+8h`）。
DailyQuotaUsage dailyQuotaUsage({
  required Iterable<Event> events,
  required DateTime asOf,
  required Duration utcOffset,
}) {
  // 与 `fold` 同序：判分「之前」有没有 `item_passed` 只能按全序读。
  final List<Event> ordered = events.toList()
    ..sort((Event a, Event b) => a.hlc.compareTo(b.hlc));

  final Set<String> passed = <String>{};
  final Set<String> reviewed = <String>{};
  final Set<String> learned = <String>{};

  for (final Event event in ordered) {
    switch (event.type) {
      case EventType.itemPassed:
        final String? passedItem = event.itemId;
        if (passedItem != null) {
          passed.add(passedItem);
        }
      case EventType.itemGraded:
        final String? gradedItem = event.itemId;
        if (gradedItem == null) {
          // 判分不带项 = 日志坏了。不计额，也不抛 —— 一条坏事件不该让整页打不开。
          continue;
        }
        if (!_sameLocalDay(event.hlc.physical, asOf, utcOffset)) {
          continue;
        }
        if (reviewed.contains(gradedItem) || learned.contains(gradedItem)) {
          // 当天已计过：一项只吃一份额度。
          continue;
        }
        if (passed.contains(gradedItem)) {
          reviewed.add(gradedItem);
        } else {
          learned.add(gradedItem);
        }
      case EventType.stepCompleted:
      case EventType.itemSkipped:
      case EventType.graduated:
      case EventType.planCreated:
      case EventType.planRevised:
      case EventType.stateCarried:
      case EventType.stateMerged:
      case EventType.itemRetired:
      case EventType.noteRevised:
        // 其余类型不改变两池用量。
        continue;
    }
  }

  return DailyQuotaUsage(reviewed: reviewed.length, learned: learned.length);
}

/// 事件时刻与 [asOf] 是否落在同一个本地日期。
///
/// 事件侧用 `hlc.physical`（毫秒时间戳）而不是 `at`：`at` 由 `hlc` 派生，只供人读，
/// 用它等于绕一层还要再信一次序列化。
bool _sameLocalDay(int physicalMs, DateTime asOf, Duration utcOffset) {
  final DateTime local = DateTime.fromMillisecondsSinceEpoch(
    physicalMs,
    isUtc: true,
  ).add(utcOffset);
  final DateTime today = asOf.toUtc().add(utcOffset);
  return local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
}
