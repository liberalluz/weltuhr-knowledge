/// 内容侧实体：全部来自 pack，客户端只读（`docs/reference/entity-fields.md` §一）。
library;

import '../enums.dart';
import '../json.dart';

/// 六要件 × 三态。键集合固定为 [RequirementKey] 的六个，缺一即格式错误。
class ItemRequirements {
  const ItemRequirements(this.states);

  factory ItemRequirements.fromJson(JsonMap json) {
    final result = <RequirementKey, RequirementState>{};
    for (final RequirementKey key in RequirementKey.values) {
      final Object? raw = json[key.name];
      if (raw is! String) {
        throw FormatException('requirements.${key.name} 缺失或非字符串');
      }
      result[key] = RequirementState.values.byName(raw);
    }
    return ItemRequirements(Map<RequirementKey, RequirementState>.unmodifiable(result));
  }

  final Map<RequirementKey, RequirementState> states;

  /// 可外化格数 = 深度 `d` 的分母（`SPEC-QUANT-006`：不可外化不入分母）。
  int get externalizableCount => states.values
      .where((RequirementState s) => s != RequirementState.notExternalizable)
      .length;

  /// 齐备格数 = 深度 `d` 的分子。
  int get completeCount =>
      states.values.where((RequirementState s) => s == RequirementState.complete).length;

  Map<String, Object?> toJson() => <String, Object?>{
    for (final MapEntry<RequirementKey, RequirementState> e in states.entries)
      e.key.name: e.value.name,
  };
}

/// 知识空间（容器）。三条边界判据全齐才是独立空间（`SPEC-PACK-001`）。
class KnowledgeSpace {
  const KnowledgeSpace({
    required this.id,
    required this.name,
    required this.version,
    required this.sixAxis,
    required this.accent,
    required this.order,
    required this.domainIds,
  });

  factory KnowledgeSpace.fromJson(JsonMap json) => KnowledgeSpace(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    version: requireString(json, 'version'),
    sixAxis: requireStringMap(json, 'sixAxis'),
    accent: requireString(json, 'accent'),
    order: requireInt(json, 'order'),
    domainIds: requireStringList(json, 'domainIds'),
  );

  final String id;
  final String name;
  final String version;

  /// 本空间在六轴上的取值（用于 Z0 分组与筛选）。**每轴单值**。
  final Map<String, String> sixAxis;

  /// 主题强调色，随包下发。
  final String accent;

  /// Z0 星系列表排序。
  final int order;

  final List<String> domainIds;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'version': version,
    'sixAxis': sixAxis,
    'accent': accent,
    'order': order,
    'domainIds': domainIds,
  };
}

/// 知识项（KST 三元组的 Q）。
class Item {
  const Item({
    required this.id,
    required this.title,
    required this.sixAxis,
    required this.layer,
    required this.type,
    required this.requirements,
    required this.sourceRefs,
    required this.domainId,
    required this.inScope,
  });

  factory Item.fromJson(JsonMap json) => Item(
    id: requireString(json, 'id'),
    title: requireString(json, 'title'),
    sixAxis: requireStringMap(json, 'sixAxis'),
    layer: Layer.values.byName(requireString(json, 'layer')),
    type: ItemType.values.byName(requireString(json, 'type')),
    requirements: ItemRequirements.fromJson(requireMap(json, 'requirements')),
    sourceRefs: requireStringList(json, 'sourceRefs'),
    domainId: requireString(json, 'domainId'),
    inScope: requireBool(json, 'inScope'),
  );

  /// **与版本无关的稳定 id**（`SPEC-PACK-008`）。带版本号会让升级后
  /// 所有已学事件指向旧 id。
  final String id;
  final String title;

  /// 六轴取值，每轴单值 —— 这是「同轴多选取 OR」的前提。
  final Map<String, String> sixAxis;
  final Layer layer;
  final ItemType type;
  final ItemRequirements requirements;
  final List<String> sourceRefs;
  final String domainId;
  final bool inScope;

  // `depth`（= phi，`⪯` 上的 Kahn 层号）是**派生值，不入库**。

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'sixAxis': sixAxis,
    'layer': layer.name,
    'type': type.name,
    'requirements': requirements.toJson(),
    'sourceRefs': sourceRefs,
    'domainId': domainId,
    'inScope': inScope,
  };
}

/// 前提边。`⪯` 必须是 DAG，任意环须在内容校验阶段拒绝（`SPEC-FND-005`）。
class Edge {
  const Edge({required this.id, required this.from, required this.to, required this.type});

  factory Edge.fromJson(JsonMap json) => Edge(
    id: requireString(json, 'id'),
    from: requireString(json, 'from'),
    to: requireString(json, 'to'),
    type: EdgeType.values.byName(requireString(json, 'type')),
  );

  final String id;

  /// 前置。
  final String from;

  /// 后继。
  final String to;
  final EdgeType type;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'from': from,
    'to': to,
    'type': type.name,
  };
}

/// 体系（顺序）。`nodes` 必须是 `⪯` 的一个线性扩展。
class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.nodes,
    required this.authorityLevel,
  });

  factory Scheme.fromJson(JsonMap json) => Scheme(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    nodes: requireStringList(json, 'nodes'),
    authorityLevel: requireString(json, 'authorityLevel'),
  );

  final String id;
  final String name;
  final List<String> nodes;

  /// `L0 / L1 / L2 / L4`，驱动候选卡的等级徽标。
  final String authorityLevel;

  // `inversions`（逆序数）是**派生值**，由 `⪯` 与 `nodes` 算出，不入库。

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'nodes': nodes,
    'authorityLevel': authorityLevel,
  };
}

/// 源（材料）的一段最小结构化摘录 —— 保证离线可读。
class SourceSegment {
  const SourceSegment({required this.text, required this.locator, required this.license});

  factory SourceSegment.fromJson(JsonMap json) => SourceSegment(
    text: requireString(json, 'text'),
    locator: requireString(json, 'locator'),
    license: requireString(json, 'license'),
  );

  final String text;

  /// 页码 / 锚点。
  final String locator;
  final String license;

  JsonMap toJson() => <String, Object?>{'text': text, 'locator': locator, 'license': license};
}

/// 源（材料）。**换源不改观感**：源不进任何视觉通道（`SPEC-VIEW-004`）。
class SourceRef {
  const SourceRef({
    required this.id,
    required this.name,
    required this.authorityLevel,
    required this.version,
    required this.segments,
    required this.appliesTo,
  });

  factory SourceRef.fromJson(JsonMap json) => SourceRef(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    authorityLevel: requireString(json, 'authorityLevel'),
    version: requireString(json, 'version'),
    segments: requireMapList(json, 'segments')
        .map(SourceSegment.fromJson)
        .toList(growable: false),
    appliesTo: requireMap(json, 'appliesTo'),
  );

  final String id;
  final String name;
  final String authorityLevel;
  final String version;
  final List<SourceSegment> segments;
  final JsonMap appliesTo;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'authorityLevel': authorityLevel,
    'version': version,
    'segments': segments.map((SourceSegment s) => s.toJson()).toList(),
    'appliesTo': appliesTo,
  };
}

/// 方法的一步。算子必须在册、`phase` 可覆盖、`criteria` 为空即打卡式。
class MethodStep {
  const MethodStep({
    required this.operator,
    this.params = const <String, Object?>{},
    this.phase,
    this.hint,
    this.criteria,
  });

  factory MethodStep.fromJson(JsonMap json) {
    final Object? phase = json['phase'];
    return MethodStep(
      operator: ExecutionOperator.values.byName(requireString(json, 'operator')),
      params: json['params'] == null ? const <String, Object?>{} : requireMap(json, 'params'),
      phase: phase == null ? null : StepPhase.values.byName('$phase'),
      hint: optionalString(json, 'hint'),
      criteria: optionalString(json, 'criteria'),
    );
  }

  final ExecutionOperator operator;
  final JsonMap params;

  /// 为空时由 [effectivePhase] 派生。
  final StepPhase? phase;

  /// **脚手架能被观测的前提**：未声明则该项无提示可给。
  final String? hint;

  /// **为空 = 打卡式**（`checked`）；非空 = 验证式（`verified`）。
  final String? criteria;

  /// 派生规则：读 / 例 → `first`；忆 / 练 / 讲 / 做 → `both`；作者可覆盖。
  StepPhase get effectivePhase {
    final StepPhase? explicit = phase;
    if (explicit != null) {
      return explicit;
    }
    switch (operator) {
      case ExecutionOperator.read:
      case ExecutionOperator.example:
        return StepPhase.first;
      case ExecutionOperator.recall:
      case ExecutionOperator.practice:
      case ExecutionOperator.teach:
      case ExecutionOperator.build:
        return StepPhase.both;
    }
  }

  JsonMap toJson() => <String, Object?>{
    'operator': operator.name,
    if (phase != null) 'phase': phase!.name,
    if (params.isNotEmpty) 'params': params,
    if (hint != null) 'hint': hint,
    if (criteria != null) 'criteria': criteria,
  };
}

/// 方法 = 动作 + 判据。可自建，但**只能自定配方，不能自创机制**（`not-list` §三）。
class MethodProfile {
  const MethodProfile({
    required this.id,
    required this.name,
    required this.steps,
    required this.appliesTo,
    required this.origin,
  });

  factory MethodProfile.fromJson(JsonMap json) => MethodProfile(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    steps: requireMapList(json, 'steps').map(MethodStep.fromJson).toList(growable: false),
    appliesTo: requireMap(json, 'appliesTo'),
    origin: MethodOrigin.values.byName(requireString(json, 'origin')),
  );

  final String id;
  final String name;
  final List<MethodStep> steps;

  /// **必填**：适用哪类项（`Item.type` / 六轴 / 三层）。
  final JsonMap appliesTo;
  final MethodOrigin origin;

  /// 校验 ②：至少有一个 `review` 步骤（防静默绕过遗忘曲线）。
  bool get hasReviewStep =>
      steps.any((MethodStep s) => s.effectivePhase != StepPhase.first);

  /// 校验 ③：全步骤无 `hint` ⇒ Planner ③ 须提示「本方法无提示可给」。
  bool get hasAnyHint => steps.any((MethodStep s) => s.hint != null);

  /// 打卡式：全部步骤都没有判据。
  bool get isCheckin => steps.every((MethodStep s) => s.criteria == null);

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'steps': steps.map((MethodStep s) => s.toJson()).toList(),
    'appliesTo': appliesTo,
    'origin': origin.name,
  };
}
