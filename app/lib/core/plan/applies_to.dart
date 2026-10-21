/// `appliesTo` 的匹配器 —— 一条候选「适不适用于这一项」。
///
/// 三段的候选都带 `appliesTo`（`entity-fields` §一.5 / §一.6 / §一.7），三个键
/// **全是硬约束**：
///
/// - `spaceId` / `type` / `layer`：项在这三个维度上必有取值，声明了就必须相符。
///
/// **`sixAxis` 键已移除**（`B13a` 笔 5b，随 `ADR-0005`）。六条轴降为「三条容器轴 +
/// 四类标签」之后，项身上不再有「每轴单值」这个东西 —— 旧实现的 `_matchesSixAxis`
/// 是软约束（项未标注该轴则跳过），而在新本体里**每一轴都必然「未标注」**，
/// 于是它恒真。留着它就是留一个永远返回 `true` 的函数，读者会以为约束还在生效。
/// 内容侧 10 条摘录的 `appliesTo.sixAxis` 一并摘除（`content/{english,german,python}/excerpts.json`）。
///
/// **不校验轴名册**：轴取值与标签归内容校验阶段（`content/tools/validator.py`），
/// 客户端再写一份就是两份会分叉的判据 —— 与 `pack_parse.dart` 顶部「不守字段级
/// 语义」同一条理由。
library;

import '../entities/content.dart';
import '../json.dart';

/// 已认的三个键。**未认的键直接报错**：静默忽略一个新键，等于让作者
/// 以为约束生效了，而实际没有任何一处会检查它。
const Set<String> appliesToKeys = <String>{'spaceId', 'type', 'layer'};

/// 候选对项 [item] 是否适用。
///
/// 未给任何键 ⇒ 恒真（「不限」）。出现不认的键 ⇒ 抛 [FormatException]。
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
      _matchesName(appliesTo['layer'], item.layer.name, 'layer');
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
