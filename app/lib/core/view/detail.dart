/// 详情三区的**渲染模型**（`SPEC-VIEW-013` / `VIEW-014` / `VIEW-017`）。
///
/// 三区 = **关系 / 要件 / 来源**（`NOTE-007` 修订）。事实信息（名字、层级、类型、
/// 轴）在**页头**，不占分区 —— 它一屏只有一行，做成分区会把关系与来源挤到
/// 窄壳抽屉的首屏之外。
///
/// 为什么单开这一层而不是让 widget 直接读 `PackContent`：
///
/// - `features/` 只吃**渲染模型**，不认领域实体 —— `R4` 的原始意图是「源不进
///   视觉通道」，收窄后由 `_isVisualChannel` 守；但详情页若直接拿 `Node`，
///   下一笔想在点半径里塞个来源计数就成了顺手的事。
/// - 两壳一套内容（`VIEW-017`）：三区的**字段与顺序**由这里定，宽壳 / 窄壳只
///   换布局断点。放在 widget 里定顺序，迟早出现两个壳的字段顺序不一致。
///
/// ## 笔 5c：`sixAxis` / `domainId` 从详情模型里消失
///
/// 两个字段随六轴一起没了（`entity-fields` 附录）。页头原来那行
/// 「域 · 层级 · 类型」现在是「轴 · 层级 · 类型」—— `Node.axis` 是三轴单值，
/// 它本来就更适合做一行的定宽事实位。
library;

import '../constants.dart';
import '../entities/edge.dart';
import '../entities/node.dart';
import '../entities/source.dart';
import '../enums.dart';
import '../graph/in_scope.dart';
import '../ids.dart';
import '../pack/pack_reader.dart';

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

  /// 对方的名字；缺口时是 id 末段。
  final String label;

  /// 虚线 = **建议**前置 / 指向未知。与宇宙的线型**同源**
  /// （`PrerequisiteEdge.strength`），不是各画各的。
  ///
  /// `strength` 从三值（`strong` / `weak` / `unknown`）收成两值
  /// （`required` / `recommended`）：`unknown` 由「`recommended` + 后继不在本包」
  /// 表达（`entity-fields` 附录）。
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

  /// 五档语义值（`entity-fields` §11）。**可空**：`kind = catalog` 的源
  /// 本身就是权威，不标等级。
  final AuthorityLevel? authorityLevel;
  final List<ProvenanceSegment> segments;

  /// 项引用了某个源 id，但包里没有这一条。
  ///
  /// **不静默跳过**：跳过会让「引用断了」看起来像「这项没有来源」，而这两件事
  /// 的处置完全不同（前者是内容缺陷，后者是标注设计）。
  final bool missing;

  /// 缺源时没有等级可显示。
  String get levelLabel {
    if (missing) {
      return '缺源';
    }
    final AuthorityLevel? level = authorityLevel;
    return level == null ? '目录' : authorityLabels[level]!;
  }
}

/// 一项的完整详情。
class ItemDetail {
  const ItemDetail({
    required this.id,
    required this.name,
    required this.axis,
    required this.layer,
    required this.type,
    required this.relations,
    required this.requirements,
    required this.provenance,
    required this.inScope,
  });

  final String id;
  final String name;

  /// 页头的事实位。**单值**：节点只属于一条轴（旧 `sixAxis` 是每轴一值的 map，
  /// 那是六轴时代的形态）。
  final Axis axis;
  final Layer layer;
  final LearnableType type;

  final List<RelationRow> relations;
  final List<RequirementRow> requirements;
  final List<ProvenanceRow> provenance;

  /// **派生**（`inScopeOf`），不是字段：同一节点在不同计划下取值不同。
  final bool inScope;

  /// 缺的格数 —— 页头那行「差几格」读它。
  int get gapCount => requirements.where((RequirementRow r) => r.isGap).length;

  /// 缺口（关系区里指向未知的那几条）。
  int get gapRelationCount =>
      relations.where((RelationRow r) => r.kind == RelationKind.gap).length;
}

/// 构详情。节点不在册 ⇒ `null`（**不造空壳**：一个 id 对不上任何节点的详情页，
/// 会让用户以为它存在但没内容）。
///
/// 结构节点没有 `NodeEntry`、也没有 `requirements` ⇒ 同样返回 `null`：
/// 详情页的「要件」区对恒星/星系无从填起，而给一个「六格全空」的页面，
/// 会被读成「这一项什么都没写」（`ADR-0007` 决策 1）。
///
/// [subtreeRoot] 用来算 `inScope`（派生，见 `graph/in_scope.dart`）。
///
/// 关系区**含跨轴边**（`SPEC-VIEW-006`：跨轴边只在宇宙与详情里画）。
ItemDetail? buildItemDetail(
  PackContent pack,
  String itemId, {
  required String subtreeRoot,
}) {
  final LearnableNode? node = pack.learnableOf(itemId);
  if (node == null) {
    return null;
  }
  // `sourceRefs` 落在内容侧；结构节点没有 entry，上面已排除，此处可直接读。
  final List<String> sourceRefs = pack.entryOf(itemId)?.sourceRefs ?? const <String>[];

  final List<RelationRow> relations = <RelationRow>[];
  for (final PrerequisiteEdge edge in pack.prerequisites) {
    if (edge.toId == itemId) {
      relations.add(
        _relationRow(pack, subtreeRoot, RelationKind.prerequisite, edge.fromId, edge),
      );
    }
    if (edge.fromId == itemId) {
      relations.add(
        _relationRow(pack, subtreeRoot, RelationKind.successor, edge.toId, edge),
      );
    }
  }

  final List<RequirementRow> requirements = <RequirementRow>[
    for (final RequirementKey key in RequirementKey.values)
      RequirementRow(key: key, state: node.requirements.states[key]!),
  ];

  final Map<String, SourceRef> refById = <String, SourceRef>{
    for (final SourceRef ref in pack.sources) ref.id: ref,
  };
  final List<ProvenanceRow> provenance = <ProvenanceRow>[
    for (final String refId in sourceRefs) _provenanceRow(refById[refId], refId),
  ];

  return ItemDetail(
    id: node.id,
    name: node.name,
    axis: node.axis,
    layer: node.layer,
    type: node.type,
    relations: relations,
    requirements: requirements,
    provenance: provenance,
    inScope: inScopeOf(node, subtreeRoot: subtreeRoot, parents: pack.parents),
  );
}

RelationRow _relationRow(
  PackContent pack,
  String subtreeRoot,
  RelationKind kind,
  String otherId,
  PrerequisiteEdge edge,
) {
  final Node? other = pack.nodeOf(otherId);
  return RelationRow(
    // 端口不在册 ⇒ 缺口，方向信息随之失效（「缺口」比「某方向的前置缺」更有用）。
    kind: other == null ? RelationKind.gap : kind,
    label: other?.name ?? idTail(otherId),
    dashed: edge.strength != EdgeStrength.required,
    // 圈外判在**任何类型的节点**上：可学节点与结构节点共用 `inScopeOf` 这一条
    // 判据（`ADR-0007` 决策 2）。限定成「结构节点才判」会让圈外的可学邻项被画
    // 成实线，而那正是 `VIEW-007` 要区分的东西。
    outside: other != null && !inScopeOf(
      other,
      subtreeRoot: subtreeRoot,
      parents: pack.parents,
    ),
    itemId: other?.id,
  );
}

ProvenanceRow _provenanceRow(SourceRef? ref, String refId) {
  if (ref == null) {
    return ProvenanceRow(
      name: refId,
      authorityLevel: null,
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
