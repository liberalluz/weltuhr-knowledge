/// 六要件 × 三态 —— 可学节点的「要件齐备度」。
///
/// 从 `content.dart` 的 `ItemRequirements` 改名搬出（`B13a` 笔 5b）。改名不是洁癖：
/// 旧名把「属于 `Item`」写进了类型名，而 `ADR-0007` 之后要件挂在
/// [`LearnableNode`](node.dart) 上，与 `Item` 没有任何关系 —— 留着旧名会让下一个
/// 读代码的人以为它还是 `Item` 的字段。
///
/// 键集合固定为 [`RequirementKey`] 的六个，缺一即格式错误：少一个键意味着「这一格
/// 没填」与「这一格不适用」两种语义被压成同一种，而深度 `d` 的分母正是按
/// [`RequirementState.notExternalizable`] 排除的 —— 静默补默认值会让分母悄悄变大。
library;

import '../enums.dart';
import '../json.dart';

/// 六要件 × 三态。键集合固定为 [RequirementKey] 的六个，缺一即格式错误。
class Requirements {
  const Requirements(this.states);

  factory Requirements.fromJson(JsonMap json) {
    final result = <RequirementKey, RequirementState>{};
    for (final RequirementKey key in RequirementKey.values) {
      final Object? raw = json[key.name];
      if (raw is! String) {
        throw FormatException('requirements.${key.name} 缺失或非字符串');
      }
      result[key] = RequirementState.fromWire(raw);
    }
    return Requirements(
      Map<RequirementKey, RequirementState>.unmodifiable(result),
    );
  }

  final Map<RequirementKey, RequirementState> states;

  /// 可外化格数 = 深度 `d` 的分母（`SPEC-QUANT-006`：不可外化不入分母）。
  int get externalizableCount => states.values
      .where((RequirementState s) => s != RequirementState.notExternalizable)
      .length;

  /// 齐备格数 = 深度 `d` 的分子。
  int get completeCount =>
      states.values.where((RequirementState s) => s == RequirementState.present)
          .length;

  Map<String, Object?> toJson() => <String, Object?>{
    for (final MapEntry<RequirementKey, RequirementState> e in states.entries)
      e.key.name: e.value.wire,
  };
}
