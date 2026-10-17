/// 详情三区的**渲染模型**（`SPEC-VIEW-013` / `VIEW-014` / `VIEW-017`）。
///
/// 三区 = **关系 / 要件 / 来源**（`NOTE-007` 修订）。事实信息（标题、层级、类型、
/// 六轴）在**页头**，不占分区 —— 它一屏只有一行，做成分区会把关系与来源挤到
/// 窄壳抽屉的首屏之外。
///
/// 为什么单开这一层而不是让 widget 直接读 `LoadedPack`：
///
/// - `features/` 只吃**渲染模型**，不认领域实体 —— `R4` 的原始意图是「源不进
///   视觉通道」，收窄后由 `_isVisualChannel` 守；但详情页若直接拿 `Item`，
///   下一笔想在点半径里塞个来源计数就成了顺手的事。
/// - 两壳一套内容（`VIEW-017`）：三区的**字段与顺序**由这里定，宽壳 / 窄壳只
///   换布局断点。放在 widget 里定顺序，迟早出现两个壳的字段顺序不一致。
library;

import '../entities/content.dart';
import '../enums.dart';
import '../ids.dart';
import '../pack/pack_parse.dart';

/// 关系区一行的**方向**。
///
/// 三值而不是两值：缺口（`gap`）不是「某个方向的前置」—— 它是「这条边指向的
/// 东西不在册」，点不动（`VIEW-014` 的六个入口里没有它），所以必须能与实体关系
/// 区分开。
enum RelationKind {
  /// 该项的前置（边上 `to` 是本项）。
  prerequisite('前置'),

  /// 该项的后继（边上 `from` 是本项）。
  successor('后继'),

  /// 端口不在册的那一侧（`ADR-0003` §决策 5 的黑洞）。
  gap('缺口');

  const RelationKind(this.label);

  /// 分区内的小标题。
  final String label;
}

/// 关系区一行。**只带渲染需要的东西。**
class RelationRow {
  const RelationRow({
    required this.kind,
    required this.label,
    required this.dashed,
    required this.outside,
    this.itemId,
  });

  final RelationKind kind;

  /// 对方的标题；缺口时是 id 末段。
  final String label;

  /// 虚线 = 弱依赖 / 指向未知。与宇宙的线型**同源**（`edge.type`），不是各画各的。
  final bool dashed;

  /// 对方在圈外（`VIEW-007` 的圈外邻项）。详情里可跳过去，但树里它是虚线支线。
  final bool outside;

  /// `null` = 缺口：没有实体可跳。
  final String? itemId;

  /// 能否点进去（`VIEW-014`）。
  bool get tappable => itemId != null;
}

/// 要件区一行 = 六要件的一格。
class RequirementRow {
  const RequirementRow({required this.key, required this.state});

  final RequirementKey key;
  final RequirementState state;

  /// 缺的格（`missing`）—— 详情里要能一眼看出「差什么」。
  bool get isGap => state == RequirementState.missing;

  /// 不可外化的格（`SPEC-QUANT-006`：不入深度分母）。
  bool get isTacit => state == RequirementState.notExternalizable;
}

/// 来源区的一段摘录。**离线可读**是硬要求（`entity-fields` §9）。
class ProvenanceSegment {
  const ProvenanceSegment({
    required this.text,
    required this.locator,
    required this.license,
  });

  final String text;
  final String locator;
  final String license;
}

/// 来源区一行 = 一个 `SourceRef`。
class ProvenanceRow {
  const ProvenanceRow({
    required this.name,
    required this.authorityLevel,
    required this.segments,
    required this.missing,
  });

  final String name;

  /// `L0 / L1 / L2 / L4`。
  final String authorityLevel;
  final List<ProvenanceSegment> segments;

  /// 项引用了某个源 id，但包里没有这一条。
  ///
  /// **不静默跳过**：跳过会让「引用断了」看起来像「这项没有来源」，而这两件事
  /// 的处置完全不同（前者是内容缺陷，后者是标注设计）。
  final bool missing;

  /// 缺源时没有等级可显示。
  String get levelLabel => missing ? '缺源' : authorityLevel;
}

/// 一项的完整详情。
class ItemDetail {
  const ItemDetail({
    required this.id,
    required this.title,
    required this.layer,
    required this.type,
    required this.domainId,
    required this.sixAxis,
    required this.relations,
    required this.requirements,
    required this.provenance,
    required this.inScope,
  });

  final String id;
  final String title;
  final Layer layer;
  final ItemType type;
  final String domainId;
  final Map<String, String> sixAxis;

  final List<RelationRow> relations;
  final List<RequirementRow> requirements;
  final List<ProvenanceRow> provenance;
  final bool inScope;

  /// 域 id 的显示末段。
  String get domainLabel => idTail(domainId);

  /// 缺的格数 —— 页头那行「差几格」读它。
  int get gapCount => requirements.where((RequirementRow r) => r.isGap).length;

  /// 缺口（关系区里指向未知的那几条）。
  int get gapRelationCount =>
      relations.where((RelationRow r) => r.kind == RelationKind.gap).length;
}

/// 构详情。项不在册 ⇒ `null`（**不造空壳**：一个 id 对不上任何项的详情页，
/// 会让用户以为这项存在但没内容）。
///
/// 关系区**含跨域边**（`SPEC-VIEW-006`：跨域边只在宇宙与详情里画）。
ItemDetail? buildItemDetail(LoadedPack pack, String itemId) {
  final Item? item = pack.itemOf(itemId);
  if (item == null) {
    return null;
  }

  final List<RelationRow> relations = <RelationRow>[];
  for (final Edge edge in pack.edges) {
    if (edge.to == itemId) {
      relations.add(
        _relationRow(pack, RelationKind.prerequisite, edge.from, edge.type),
      );
    }
    if (edge.from == itemId) {
      relations.add(
        _relationRow(pack, RelationKind.successor, edge.to, edge.type),
      );
    }
  }

  final List<RequirementRow> requirements = <RequirementRow>[
    for (final RequirementKey key in RequirementKey.values)
      RequirementRow(key: key, state: item.requirements.states[key]!),
  ];

  final Map<String, SourceRef> refById = <String, SourceRef>{
    for (final SourceRef ref in pack.excerpts) ref.id: ref,
  };
  final List<ProvenanceRow> provenance = <ProvenanceRow>[
    for (final String refId in item.sourceRefs)
      _provenanceRow(refById[refId], refId),
  ];

  return ItemDetail(
    id: item.id,
    title: item.title,
    layer: item.layer,
    type: item.type,
    domainId: item.domainId,
    sixAxis: item.sixAxis,
    relations: relations,
    requirements: requirements,
    provenance: provenance,
    inScope: item.inScope,
  );
}

RelationRow _relationRow(
  LoadedPack pack,
  RelationKind kind,
  String otherId,
  EdgeType type,
) {
  final Item? other = pack.itemOf(otherId);
  return RelationRow(
    // 端口不在册 ⇒ 缺口，方向信息随之失效（「缺口」比「某方向的前置缺」更有用）。
    kind: other == null ? RelationKind.gap : kind,
    label: other?.title ?? idTail(otherId),
    dashed: type != EdgeType.strong,
    outside: other != null && !other.inScope,
    itemId: other?.id,
  );
}

ProvenanceRow _provenanceRow(SourceRef? ref, String refId) {
  if (ref == null) {
    return ProvenanceRow(
      name: refId,
      authorityLevel: '',
      segments: const <ProvenanceSegment>[],
      missing: true,
    );
  }
  return ProvenanceRow(
    name: ref.name,
    authorityLevel: ref.authorityLevel,
    segments: <ProvenanceSegment>[
      for (final SourceSegment segment in ref.segments)
        ProvenanceSegment(
          text: segment.text,
          locator: segment.locator,
          license: segment.license,
        ),
    ],
    missing: false,
  );
}
