/// 计划（意图）。**键是 `spaceId`**：一空间可并存多份 Plan，不存在跨空间的总 Plan。
library;

import '../json.dart';

/// 计划的范围。**粒度随视距**（Z1 ≈150 项 / Z3 ≈12 项 / Z4 = 1 项）。
class PlanTarget {
  const PlanTarget({required this.selector, required this.resolved});

  factory PlanTarget.fromJson(JsonMap json) => PlanTarget(
    selector: requireMap(json, 'selector'),
    resolved: requireStringList(json, 'resolved'),
  );

  /// 存的是**选择式**，不是结果列表 —— 结果会随视图与包版本变。
  final JsonMap selector;

  /// 解析后的项 id。
  final List<String> resolved;

  /// 派生于 [resolved]，**不入库也不序列化**（避免两份可能不一致的真相）。
  int get count => resolved.length;

  JsonMap toJson() => <String, Object?>{
    'selector': selector,
    'resolved': resolved,
  };
}

/// 计划。`progress` 与 `sessions` 都是派生值，不存字段。
class Plan {
  const Plan({
    required this.id,
    required this.spaceId,
    required this.spaceVersion,
    required this.target,
    required this.sourcePolicy,
    required this.schemeId,
    required this.methodProfileId,
    required this.version,
  });

  factory Plan.fromJson(JsonMap json) => Plan(
    id: requireString(json, 'id'),
    spaceId: requireString(json, 'spaceId'),
    spaceVersion: requireString(json, 'spaceVersion'),
    target: PlanTarget.fromJson(requireMap(json, 'target')),
    sourcePolicy: requireMap(json, 'sourcePolicy'),
    schemeId: requireString(json, 'schemeId'),
    methodProfileId: requireString(json, 'methodProfileId'),
    version: requireInt(json, 'version'),
  );

  final String id;
  final String spaceId;

  /// 建计划时的包版本。
  final String spaceVersion;
  final PlanTarget target;

  /// 主源 + 按类型 + 例外，引用 `SourceRef.id`。
  final JsonMap sourcePolicy;
  final String schemeId;
  final String methodProfileId;

  /// 重规划时 +1。
  final int version;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'spaceId': spaceId,
    'spaceVersion': spaceVersion,
    'target': target.toJson(),
    'sourcePolicy': sourcePolicy,
    'schemeId': schemeId,
    'methodProfileId': methodProfileId,
    'version': version,
  };
}
