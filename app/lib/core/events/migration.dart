/// 内容迁移账本：把「项被拆分 / 合并」折算成事实（`event-types.md` §二 C）。
///
/// 为什么折算规则不能写在 `fold` 外面：一旦「复制多少状态」变成散落在调用方
/// 的算术，事件流之外就有了第二份魔法，事件溯源当场出破口
/// （`event-types.md` §二 C 末句）。
///
/// 边界：**本文件不产生 `S`**。`S` 由 `B6` 的 FSRS 从 `item_graded` 算出；
/// 这里只负责「已知各源项的 `S`，迁移后各目标项该拿多少」，所以函数签名
/// 是一个 `Map<String, double> → Map<String, double>`，与 FSRS 完全解耦。
library;

import '../constants.dart';
import '../json.dart';

/// 拆分：`from` 的 `S` 按 `ratio` 分给每个子项（`C-12`）。
class CarryLink {
  const CarryLink({
    required this.eventId,
    required this.from,
    required this.toItemIds,
    required this.ratio,
  });

  /// 从 `state_carried` 事件读出。
  ///
  /// `ratio` **优先取 payload**：将来若出现不等分拆分，payload 是权威值；
  /// 缺字段时按 `C-12` 由子项数算出（`1/n`），**不在这里另写一套公式**。
  factory CarryLink.fromPayload({required String eventId, required JsonMap payload}) {
    final String from = requireString(payload, 'fromItemId');
    final List<String> toItemIds = requireStringList(payload, 'toItemIds');
    final Object? rawRatio = payload['ratio'];
    final double ratio = rawRatio is num
        ? rawRatio.toDouble()
        : carryRatio(toItemIds.length);
    return CarryLink(eventId: eventId, from: from, toItemIds: toItemIds, ratio: ratio);
  }

  final String eventId;

  /// 被拆的旧项。**保留** —— 它的事件不删，只是新学习不再指向它。
  final String from;
  final List<String> toItemIds;
  final double ratio;

  JsonMap toJson() => <String, Object?>{
    'fromItemId': from,
    'toItemIds': toItemIds,
    'ratio': ratio,
  };
}

/// 合并：目标项取各源项 `S` 的最大值（`C-13`）。
class MergeLink {
  const MergeLink({required this.eventId, required this.fromItemIds, required this.toItemId});

  factory MergeLink.fromPayload({required String eventId, required JsonMap payload}) =>
      MergeLink(
        eventId: eventId,
        fromItemIds: requireStringList(payload, 'fromItemIds'),
        toItemId: requireString(payload, 'toBeId'),
      );

  final String eventId;
  final List<String> fromItemIds;

  /// 合并后的新项。
  final String toItemId;

  JsonMap toJson() => <String, Object?>{
    'fromItemIds': fromItemIds,
    'toBeId': toItemId,
  };
}

/// 把已知的 `S` 沿迁移账本折算到新项上。
///
/// 返回值**包含源项原值**（孤儿项保留，`SPEC-FND-012`），另加折算出的目标项。
/// 只加不删：一次 `fold` 之后，新旧 id 都还能查到自己的 `S`。
///
/// 为什么是迭代到不动点而不是单趟：`A → {B, C}` 之后 `B → {D, E}` 时，
/// `D` 的值依赖 `B` 的**折算后**值。单趟按账本顺序恰好能算对只是碰巧
/// （账本顺序 = 事件时间序，但拆分事件的先后不必等于依赖先后）。
Map<String, double> carryStability({
  required Map<String, double> source,
  required List<CarryLink> carries,
  required List<MergeLink> merges,
}) {
  final Map<String, double> result = <String, double>{...source};
  final int rounds = carries.length + merges.length;
  if (rounds == 0) {
    return result;
  }

  for (int round = 0; round <= rounds; round++) {
    bool changed = false;

    for (final CarryLink link in carries) {
      final double? base = result[link.from];
      if (base == null) {
        continue;
      }
      final double carried = base * link.ratio;
      for (final String to in link.toItemIds) {
        // 目标项可能已有自己的 `S`（它先被学过，之后才发生拆分）——
        // 取较大者：折算出来的历史不应该覆盖真实观测。
        final double current = result[to] ?? carried;
        final double next = carried > current ? carried : current;
        if (result[to] != next) {
          result[to] = next;
          changed = true;
        }
      }
    }

    for (final MergeLink link in merges) {
      double? best;
      for (final String from in link.fromItemIds) {
        final double? value = result[from];
        if (value != null && (best == null || value > best)) {
          best = value;
        }
      }
      if (best == null) {
        continue;
      }
      final double current = result[link.toItemId] ?? best;
      final double next = best > current ? best : current;
      if (result[link.toItemId] != next) {
        result[link.toItemId] = next;
        changed = true;
      }
    }

    if (!changed) {
      return result;
    }
  }

  return result;
}
