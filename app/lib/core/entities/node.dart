/// 树节点：**按槽位 `sealed` 两分**（`ADR-0007` 决策 1）。
///
/// 分型轴不是 `scope`（五个 scope 的字段集一个都不差），也不是 `status`，
/// 而是「可学与否」。项目里唯一有行为分叉的概念就是「可学」—— 七步 Runner、
/// FSRS 排程、掌握度 `d × s`、`Plan` 的候选集，全部只对 `planet` 有意义。
/// 把它做成类型，那些地方就不必逐处判 `type != null`。
///
/// **派生三项不作字段**（`ADR-0007` 决策 2）：
/// - `path` —— 父节点改名就变，存下来必然出现两份真相
/// - `inScope` —— 依赖 `Plan.subtree_root`，同一节点在不同 Plan 下取值不同
/// - `depth` —— 台账明写「仅供展示，不得用于判据」，存成字段等于邀请别人拿它判据
///
/// 四条静态检查守这条形态（`tool/lint/` 的 `R6`–`R9`）：类体字段集、非可空、
/// 无直接构造、无派生字段。**这些不是风格约束** —— 非法组合一旦可表达，
/// 就会有人在恒星上跑七步流程，而且一路绿灯。
library;

import '../constants.dart';
import '../enums.dart';
import '../errors.dart';
import '../json.dart';
import 'content.dart';

/// 树节点基类。字段集以 `docs/reference/entity-fields.md` §2 为唯一权威处。
///
/// `sealed`：子类只能在同一库里出现（本例即本文件），「一共有几种节点」
/// 因此在编译期封闭，`switch` 也不必写 `default`。
///
/// ⚠️ **`levelSlot` 是抽象 getter，不是基类字段** —— 与 `ADR-0007` 的代码片段
/// 有出入，是有意为之：结构节点的槽位是**数据**（五种），可学节点恒为 `planet`，
/// 那是**类型的一部分**。做成基类构造参数就得让 `LearnableNode` 接收它、
/// 再在构造体里校验「必须是 planet」，而 ADR 的原话是「开放就等于留一个能写错
/// 的口子」。改成 getter 后那条口子不存在：`LearnableNode` 根本收不到这个参数。
sealed class Node {
  Node({
    required this.id,
    required this.axis,
    required this.name,
    required this.slug,
    required this.scope,
    required this.packId,
    required this.status,
    required this.tags,
    required this.catalogRefs,
    this.officialCode,
  });

  /// `{plugin_id}:{local_id}`；骨架节点 `skeleton:{local_id}`。
  /// **不带版本号** —— 带上之后升级会让所有已学事件指向旧 id。
  final String id;

  final Axis axis;

  /// 语义槽位。**不是深度序号**：三轴占用的槽位不同（见 `LevelSlot`）。
  LevelSlot get levelSlot;

  final String name;

  /// `path` 段，`^[a-z0-9-]+$`；`_` 开头的段为保留段。
  final String slug;

  /// 只影响可写性，不影响字段集（`ADR-0007` 决策 3）。
  final Scope scope;

  /// 来源包；骨架为 `skeleton`，`S4` 自建为空串。
  final String packId;

  final NodeStatus status;

  /// 骨架事实标签（如 `digital` / `green`），**与内容侧 `keywords` 不是一回事**。
  final List<String> tags;

  /// 引用 `SourceRef.id`（`kind = catalog`）。多值：同一节点可受两份目录覆盖。
  final List<String> catalogRefs;

  /// 可空：`S4` 自建、载荷行星系与行星均无官方码。
  final String? officialCode;
}

/// 结构节点：骨架五槽位之一（`supercluster` / `group` / `galaxy` / `cluster` /
/// `star`），或载荷容器 `system`。
///
/// **没有** `type` / `layer` / `requirements` —— 那三项只对可学节点有意义，
/// 出现在这里就是「恒星上也能跑七步」的入口（`R6` 守这条）。
final class StructuralNode extends Node {
  StructuralNode({
    required super.id,
    required super.axis,
    required super.name,
    required super.slug,
    required super.scope,
    required super.packId,
    required super.status,
    required super.tags,
    required super.catalogRefs,
    super.officialCode,
    required this.levelSlot,
  }) {
    // `system`（行星系）轴继承自父恒星，三轴都合法，故不查表；
    // 其余槽位必须命中 12 对静态表（`ADR-0007` 决策 4）。
    final bool payloadContainer = levelSlot == LevelSlot.system;
    if (!payloadContainer && !legalSkeletonSlots.contains((axis, levelSlot))) {
      throw IllegalNodeSlotError(axis, levelSlot);
    }
  }

  /// 结构节点的槽位是数据：五种骨架槽位 + 载荷容器 `system`。
  @override
  final LevelSlot levelSlot;
}

/// 可学节点：恒为 `planet`。
///
/// 它的槽位是**类型的一部分**，不是字段 —— 没有参数可以传错，也没有字段可以改。
final class LearnableNode extends Node {
  LearnableNode({
    required super.id,
    required super.axis,
    required super.name,
    required super.slug,
    required super.scope,
    required super.packId,
    required super.status,
    required super.tags,
    required super.catalogRefs,
    super.officialCode,
    required this.type,
    required this.layer,
    required this.requirements,
  });

  @override
  LevelSlot get levelSlot => LevelSlot.planet;

  /// 三项**非可空**：`null` 不是合法取值（`R7` 守这条）。
  final LearnableType type;
  final Layer layer;

  /// 六要件 × 三态。**量化层 `d`（知识深度）的唯一来源**，`mastery = d × s` 依赖它。
  ///
  /// ⚠️ 类型名仍叫 `ItemRequirements`（旧实体遗物）：`B13a` 笔 5 随 `Item` 删除
  /// 一并改名为 `Requirements`。本笔不改 —— 改名会让 47 个引用点同时断，
  /// 与「每笔各自可验证」的分笔口径冲突。
  final ItemRequirements requirements;
}

/// 按 `level_slot` 分派（**唯一入口**，`ADR-0007` 决策 3）。
///
/// 分派轴是槽位而不是 `scope`，理由见类文档：五个 `scope` 的字段集完全相同，
/// 唯一的形态分叉是「可学与否」，而它恰好等于「槽位是不是 `planet`」。
///
/// 未知槽位不在这里拦：`LevelSlot.fromWire` 已经抛了「取值不在册」，
/// 那比「分派失败」更能说明数据哪里错了。`StructuralNode` 构造体再判
/// `(axis, level_slot)` 的 12 对 —— 两道关都在，且都不靠自觉。
Node nodeFromJson(JsonMap json) {
  final Axis axis = Axis.fromWire(requireString(json, 'axis'));
  final LevelSlot slot = LevelSlot.fromWire(requireString(json, 'level_slot'));
  final String id = requireString(json, 'id');
  final String name = requireString(json, 'name');
  final String slug = requireString(json, 'slug');
  final Scope scope = Scope.fromWire(requireString(json, 'scope'));
  final String packId = requireString(json, 'pack_id');
  final NodeStatus status = NodeStatus.fromWire(requireString(json, 'status'));
  final List<String> tags = requireStringList(json, 'tags');
  final List<String> catalogRefs = requireStringList(json, 'catalog_refs');
  final String? officialCode = optionalString(json, 'official_code');

  if (slot == LevelSlot.planet) {
    return LearnableNode(
      id: id,
      axis: axis,
      name: name,
      slug: slug,
      scope: scope,
      packId: packId,
      status: status,
      tags: tags,
      catalogRefs: catalogRefs,
      officialCode: officialCode,
      // 三项在结构节点上不存在 ⇒ 行星缺了它们不是「默认值」，是坏数据。
      // `requireX` 会让它当场报字段缺名，而不是塞一个默认值继续跑。
      type: LearnableType.fromWire(requireString(json, 'type')),
      layer: Layer.fromWire(requireString(json, 'layer')),
      requirements: ItemRequirements.fromJson(requireMap(json, 'requirements')),
    );
  }

  return StructuralNode(
    id: id,
    axis: axis,
    name: name,
    slug: slug,
    scope: scope,
    packId: packId,
    status: status,
    tags: tags,
    catalogRefs: catalogRefs,
    officialCode: officialCode,
    levelSlot: slot,
  );
}
