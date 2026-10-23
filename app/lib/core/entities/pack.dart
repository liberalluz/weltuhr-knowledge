/// 插件包（`entity-fields` §1，取代 `KnowledgeSpace`）。
///
/// **一个插件可含多个包**（分发单元 ≠ 逻辑单元）；`skeleton` 全量内置、
/// 不走插件、不进审核 ⇒ 本文件只覆盖四类。
///
/// ⚠️ **`kinds[]` 不是判别符**。「这段数据是什么」由边上的 `type` 与节点上的
/// `level_slot` 回答；`kinds[]` 回答的是「这个包干几件事」。一个包既是载荷
/// 又带地形是合法形态，所以不能像 [NodeEdge] 那样 `sealed` 四分 —— 那会把
/// 「一个包只能干一件事」变成一条没人声明过的约束。
///
/// 四类特化字段因此落地为四个**可空**对象，由构造体校验「`kinds` 与 facts
/// 一一对应」，违反即抛 [IllegalPackKindError]。选可空 + 校验而不是
/// `sealed`：多 kind 组合共 `2^4 - 1 = 15` 种，`sealed` 要枚举 15 个子类，
/// 而其中 11 种从来没有出现的理由。
library;

import '../enums.dart';
import '../errors.dart';
import '../json.dart';

/// 跨包依赖（`entity-fields` §1 `deps[]`）。
///
/// 跨包父子（A 出 L5、B 补 L6）**必须**在此声明 —— 树的 `parent_id` 不许跨包，
/// 否则卸载 A 会拆掉 B 的树。
class PackDep {
  const PackDep({required this.pluginId, required this.range});

  factory PackDep.fromJson(JsonMap json) => PackDep(
    pluginId: requireString(json, 'plugin_id'),
    range: requireString(json, 'range'),
  );

  final String pluginId;

  /// semver 区间，与 `Pack.version` 参与匹配。
  final String range;

  JsonMap toJson() => <String, Object?>{
    'plugin_id': pluginId,
    'range': range,
  };
}

/// 装前路径预留（`entity-fields` §1 `path_reservations[]`）。
///
/// **侧载无审核**，所以这是判 `path` 冲突的唯一依据：装之前就要知道
/// `(父节点, slug)` 这一对被谁占了。
class PathReservation {
  const PathReservation({required this.parentId, required this.slug});

  factory PathReservation.fromJson(JsonMap json) => PathReservation(
    parentId: requireString(json, 'parent_id'),
    slug: requireString(json, 'slug'),
  );

  final String parentId;
  final String slug;

  JsonMap toJson() => <String, Object?>{
    'parent_id': parentId,
    'slug': slug,
  };
}

/// `payload` 特化字段（`entity-fields` §1）。
class PayloadFacts {
  const PayloadFacts({
    required this.attachTo,
    required this.subtreeRoot,
    required this.levelRange,
    required this.counts,
    required this.officialCodeCoverage,
    required this.pathReservations,
    required this.sources,
    required this.schemes,
    required this.hasSteps,
    required this.hasCriteria,
    required this.hasQuiz,
    required this.quizTypes,
    required this.estMinutesCoverage,
  });

  factory PayloadFacts.fromJson(JsonMap json) => PayloadFacts(
    attachTo: requireString(json, 'attach_to'),
    subtreeRoot: LevelSlot.fromWire(requireString(json, 'subtree_root')),
    levelRange: requireStringList(
      json,
      'level_range',
    ).map(LevelSlot.fromWire).toList(growable: false),
    counts: PayloadCounts.fromJson(requireMap(json, 'counts')),
    officialCodeCoverage: requireBool(json, 'official_code_coverage'),
    pathReservations: requireMapList(
      json,
      'path_reservations',
    ).map(PathReservation.fromJson).toList(growable: false),
    sources: requireStringList(json, 'sources'),
    schemes: requireStringList(json, 'schemes'),
    hasSteps: requireBool(json, 'has_steps'),
    hasCriteria: requireBool(json, 'has_criteria'),
    hasQuiz: requireBool(json, 'has_quiz'),
    quizTypes: requireStringList(
      json,
      'quiz_types',
    ).map(QuizType.fromWire).toList(growable: false),
    estMinutesCoverage: requireDouble(json, 'est_minutes_coverage'),
  );

  /// **节点 id**（非 path）。骨架已有该恒星时填其 id；编外节点填 `@extra/root`。
  final String attachTo;

  /// 本包提供的最上层槽位。
  final LevelSlot subtreeRoot;

  final List<LevelSlot> levelRange;

  /// **必须分级** —— `planet` 数才是「能不能跑七步」的依据。
  final PayloadCounts counts;

  final bool officialCodeCoverage;
  final List<PathReservation> pathReservations;

  /// 源与体系摘要（正文在 `sources` / `schemes` 段）。
  final List<String> sources;
  final List<String> schemes;

  /// 决定 ④ ⑤ 能否跑。
  final bool hasSteps;
  final bool hasCriteria;
  final bool hasQuiz;

  final List<QuizType> quizTypes;

  /// 有时长的项占比（0..1）。
  final double estMinutesCoverage;

  JsonMap toJson() => <String, Object?>{
    'attach_to': attachTo,
    'subtree_root': subtreeRoot.name,
    'level_range': levelRange.map((LevelSlot s) => s.name).toList(),
    'counts': counts.toJson(),
    'official_code_coverage': officialCodeCoverage,
    'path_reservations': pathReservations
        .map((PathReservation r) => r.toJson())
        .toList(),
    'sources': sources,
    'schemes': schemes,
    'has_steps': hasSteps,
    'has_criteria': hasCriteria,
    'has_quiz': hasQuiz,
    'quiz_types': quizTypes.map((QuizType t) => t.name).toList(),
    'est_minutes_coverage': estMinutesCoverage,
  };
}

/// 载荷节点分级计数（`entity-fields` §1 `counts`）。
///
/// 三个字段固定：`LearnableNode` = 行星层，所以「这个包能学多少东西」只看 [planet]。
/// 用对象而不是 `Map<String,int>` —— 后者少一个键时不报错，而 `planet` 缺失
/// 会让「零可学项」与「计数写漏」长得一模一样。
class PayloadCounts {
  const PayloadCounts({
    required this.star,
    required this.system,
    required this.planet,
  });

  factory PayloadCounts.fromJson(JsonMap json) => PayloadCounts(
    star: requireInt(json, 'star'),
    system: requireInt(json, 'system'),
    planet: requireInt(json, 'planet'),
  );

  final int star;
  final int system;
  final int planet;

  JsonMap toJson() => <String, Object?>{
    'star': star,
    'system': system,
    'planet': planet,
  };
}

/// `terrain` 特化字段（`entity-fields` §1）。
class TerrainFacts {
  const TerrainFacts({
    required this.requiredCount,
    required this.recommendedCount,
    required this.axesCovered,
  });

  factory TerrainFacts.fromJson(JsonMap json) {
    final JsonMap counts = requireMap(json, 'edge_counts');
    return TerrainFacts(
      requiredCount: requireInt(counts, 'required'),
      recommendedCount: requireInt(counts, 'recommended'),
      axesCovered: requireStringList(
        json,
        'axes_covered',
      ).map(Axis.fromWire).toList(growable: false),
    );
  }

  final int requiredCount;
  final int recommendedCount;
  final List<Axis> axesCovered;

  JsonMap toJson() => <String, Object?>{
    'edge_counts': <String, Object?>{
      'required': requiredCount,
      'recommended': recommendedCount,
    },
    'axes_covered': axesCovered.map((Axis a) => a.name).toList(),
  };
}

/// `overlay` 特化字段（`entity-fields` §1）。
class OverlayFacts {
  const OverlayFacts({required this.targetScope, required this.patchCount});

  factory OverlayFacts.fromJson(JsonMap json) => OverlayFacts(
    targetScope: Scope.fromWire(requireString(json, 'target_scope')),
    patchCount: requireInt(json, 'patch_count'),
  );

  final Scope targetScope;
  final int patchCount;

  JsonMap toJson() => <String, Object?>{
    'target_scope': targetScope.name,
    'patch_count': patchCount,
  };
}

/// `method` 特化字段（`entity-fields` §1 `methods[]`）。
class MethodFacts {
  const MethodFacts({required this.methods});

  factory MethodFacts.fromJson(JsonMap json) => MethodFacts(
    methods: requireMapList(
      json,
      'methods',
    ).map(MethodSummary.fromJson).toList(growable: false),
  );

  final List<MethodSummary> methods;

  JsonMap toJson() => <String, Object?>{
    'methods': methods.map((MethodSummary m) => m.toJson()).toList(),
  };
}

/// 方法摘要（装前可见的那部分，正文在 `methods` 段）。
class MethodSummary {
  const MethodSummary({
    required this.id,
    required this.name,
    required this.itemTypes,
    required this.stepCount,
    required this.hasReviewStep,
    required this.phaseDistribution,
  });

  factory MethodSummary.fromJson(JsonMap json) => MethodSummary(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    itemTypes: requireStringList(
      json,
      'item_types',
    ).map(LearnableType.fromWire).toList(growable: false),
    stepCount: requireInt(json, 'step_count'),
    hasReviewStep: requireBool(json, 'has_review_step'),
    phaseDistribution: requireStringMap(json, 'phase_distribution'),
  );

  final String id;
  final String name;
  final List<LearnableType> itemTypes;
  final int stepCount;

  /// **`STEP-027` 的装前可见项**：没有 `review` 步骤的方法装了也白装。
  final bool hasReviewStep;

  /// 相位分布（`first` / `review` / `both` → 步数）。台账未定死键集，故存原文。
  final Map<String, String> phaseDistribution;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'item_types': itemTypes.map((LearnableType t) => t.name).toList(),
    'step_count': stepCount,
    'has_review_step': hasReviewStep,
    'phase_distribution': phaseDistribution,
  };
}

/// 插件包。字段集以 `docs/specs/entity-fields.md` §1 为唯一权威处。
class Pack {
  Pack({
    required this.pluginId,
    required this.name,
    required this.version,
    required this.kinds,
    required this.namespace,
    required this.schemaVersion,
    required this.skeletonRequires,
    required this.deps,
    required this.license,
    required this.author,
    required this.origin,
    required this.reviewState,
    required this.axes,
    this.signature,
    this.payload,
    this.terrain,
    this.overlay,
    this.method,
  }) {
    _verifyFacts();
  }

  factory Pack.fromJson(JsonMap json) => Pack(
    pluginId: requireString(json, 'plugin_id'),
    name: requireString(json, 'name'),
    version: requireString(json, 'version'),
    kinds: requireStringList(
      json,
      'kinds',
    ).map(PackKind.fromWire).toList(growable: false),
    namespace: requireString(json, 'namespace'),
    schemaVersion: requireInt(json, 'schema_version'),
    skeletonRequires: requireString(json, 'skeleton_requires'),
    deps: requireMapList(
      json,
      'deps',
    ).map(PackDep.fromJson).toList(growable: false),
    license: requireString(json, 'license'),
    author: requireString(json, 'author'),
    origin: requireString(json, 'origin'),
    reviewState: ReviewState.fromWire(requireString(json, 'review_state')),
    axes: requireStringList(
      json,
      'axes',
    ).map(Axis.fromWire).toList(growable: false),
    signature: optionalString(json, 'signature'),
    payload: json['payload'] == null
        ? null
        : PayloadFacts.fromJson(requireMap(json, 'payload')),
    terrain: json['terrain'] == null
        ? null
        : TerrainFacts.fromJson(requireMap(json, 'terrain')),
    overlay: json['overlay'] == null
        ? null
        : OverlayFacts.fromJson(requireMap(json, 'overlay')),
    method: json['method'] == null
        ? null
        : MethodFacts.fromJson(requireMap(json, 'method')),
  );

  /// **永久唯一、不可复用**（`^[a-z][a-z0-9-]*$`）。
  final String pluginId;
  final String name;

  /// semver，参与 [PackDep.range] 匹配。
  final String version;

  /// 见文件头：**不是判别符**，可多值。
  final List<PackKind> kinds;

  /// 节点 id 前缀：实际 id = `{pluginId}:{localId}`。
  final String namespace;

  /// **插件格式版本**，与 [version] 独立演进。
  final int schemaVersion;

  /// 骨架版本区间。载荷节点挂骨架父节点，骨架升版会让 `attachTo` 失配。
  final String skeletonRequires;

  final List<PackDep> deps;
  final String license;
  final String author;
  final String origin;
  final ReviewState reviewState;

  /// **可空**：侧载与私有包可以没有签名。
  final String? signature;

  /// 全类必填，但可以是单元素。
  final List<Axis> axes;

  final PayloadFacts? payload;
  final TerrainFacts? terrain;
  final OverlayFacts? overlay;
  final MethodFacts? method;

  bool hasKind(PackKind kind) => kinds.contains(kind);

  /// `kinds` 与四个 facts 必须一一对应。
  ///
  /// 两个方向都要查：声明了 `payload` 却没有 facts ⇒ 装前显示一片空白；
  /// 带了 facts 却没声明 `kind` ⇒ 那份数据永远不会被读。后者更隐蔽 ——
  /// 包里明明有 150 个行星，界面却说「零可学项」。
  void _verifyFacts() {
    _checkFact(PackKind.payload, payload != null);
    _checkFact(PackKind.terrain, terrain != null);
    _checkFact(PackKind.overlay, overlay != null);
    _checkFact(PackKind.method, method != null);
  }

  void _checkFact(PackKind kind, bool present) {
    final bool declared = hasKind(kind);
    if (declared != present) {
      throw IllegalPackKindError(pluginId, kind, declared: declared);
    }
  }

  JsonMap toJson() => <String, Object?>{
    'plugin_id': pluginId,
    'name': name,
    'version': version,
    'kinds': kinds.map((PackKind k) => k.name).toList(),
    'namespace': namespace,
    'schema_version': schemaVersion,
    'skeleton_requires': skeletonRequires,
    'deps': deps.map((PackDep d) => d.toJson()).toList(),
    'license': license,
    'author': author,
    'origin': origin,
    'review_state': reviewState.name,
    'signature': signature,
    'axes': axes.map((Axis a) => a.name).toList(),
    if (payload != null) 'payload': payload!.toJson(),
    if (terrain != null) 'terrain': terrain!.toJson(),
    if (overlay != null) 'overlay': overlay!.toJson(),
    if (method != null) 'method': method!.toJson(),
  };
}
