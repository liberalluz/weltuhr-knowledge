/// `appliesTo` 的匹配器 —— 一条候选「适不适用于这一项」。
///
/// 三段的候选都带 `appliesTo`（`entity-fields` §一.5 / §一.6 / §一.7），但四个键的
/// **强度不同**（`B4` `P-2` 定，写入 `entity-fields` §一.7 附注）：
///
/// - `spaceId` / `type` / `layer`：**硬约束**。项在这三个维度上必有取值，
///   声明了就必须相符。
/// - `sixAxis`：**软约束** —— 项在该轴上**没有标注**时**不据此否决**。
///   `α` 包 150 项只标了 `subject` / `ability`，而 4 条源都声明
///   `sixAxis.stack = Python`；若按硬约束处理，这 4 条源会被自己的
///   `appliesTo` 全部筛掉。六轴是筛选坐标，项未标注某轴即不受该轴约束。
///
/// **不校验轴名册**：六轴取值与轴名归内容校验阶段（`content/tools/validator.py`），
/// 客户端再写一份就是两份会分叉的判据 —— 与 `pack_parse.dart` 顶部「不守字段级
/// 语义」同一条理由。
library;

import '../entities/content.dart';
import '../json.dart';

/// 已认的四个键。**未认的键直接报错**：静默忽略一个新键，等于让作者
/// 以为约束生效了，而实际没有任何一处会检查它。
const Set<String> appliesToKeys = <String>{'spaceId', 'type', 'layer', 'sixAxis'};

/// 候选对项 [item] 是否适用。
///
/// 未给任何键 ⇒ 恒真（「不限」）。四个键都不认 ⇒ 抛 [FormatException]。
bool appliesToItem(
  JsonMap appliesTo, {
  required KnowledgeSpace space,
  required Item item,
}) {
  for (final String key in appliesTo.keys) {
    if (!appliesToKeys.contains(key)) {
      throw FormatException(
        '`appliesTo` 出现未认的键 `$key`（只认 ${appliesToKeys.join(" / ")}）',
      );
    }
  }

  final Object? spaceId = appliesTo['spaceId'];
  if (spaceId != null && spaceId != space.id) {
    return false;
  }

  return _matchesName(appliesTo['type'], item.type.name, 'type') &&
      _matchesName(appliesTo['layer'], item.layer.name, 'layer') &&
      _matchesSixAxis(appliesTo['sixAxis'], item.sixAxis);
}

/// `type` / `layer`：单值或数组，数组取「任一命中」。
bool _matchesName(Object? raw, String actual, String key) {
  if (raw == null) {
    return true;
  }
  if (raw is String) {
    return raw == actual;
  }
  if (raw is List) {
    return raw.contains(actual);
  }
  throw FormatException('`appliesTo.$key` 必须是 String 或 String[]，实际是 ${raw.runtimeType}');
}

/// 六轴：逐轴比对，**项未标注该轴时跳过**（软约束）。
bool _matchesSixAxis(Object? raw, Map<String, String> actual) {
  if (raw == null) {
    return true;
  }
  if (raw is! Map) {
    throw FormatException('`appliesTo.sixAxis` 必须是对象，实际是 ${raw.runtimeType}');
  }
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    final String axis = '${entry.key}';
    final String? value = actual[axis];
    if (value == null) {
      continue;
    }
    final Object? want = entry.value;
    if (want is String) {
      if (want != value) {
        return false;
      }
      continue;
    }
    if (want is List) {
      if (!want.contains(value)) {
        return false;
      }
      continue;
    }
    throw FormatException('`appliesTo.sixAxis.$axis` 必须是 String 或 String[]');
  }
  return true;
}
