/// 三类边：**按判别符分派**，不靠字段名推断（`entity-fields` §3–§5）。
///
/// `sealed` 的理由与 `Node` 同源（`ADR-0007` 决策 1）：三类边的端点语义不同 ——
/// `parent` 有主/附之分，`wormhole` 是双向跳转、只影响呈现，`prerequisite` 是
/// 有向先修、参与 `⪯` 闭包。做成三个类型，`⪯` 的计算就不必在遍历时反复
/// `if (edge.type == 'prerequisite')`，也不可能把虫洞误算进偏序。
///
/// **判别符是 `type` 字段**（`minimal-pack.md` §3.3）：`wormhole` 与
/// `prerequisite` 都有 `from_id` / `to_id`，靠字段名猜必然分不清 —— 一条
/// `from_id`/`to_id` 的边到底是跳转还是先修，只取决于作者写的那一个字。
/// `ADR-0007`「反序列化按判别符分派为唯一入口、不允许旁路构造」即指此。
library;

import '../enums.dart';
import '../json.dart';

/// 边类型判别符的线上取值。
const String edgeTypeParent = 'parent';
const String edgeTypeWormhole = 'wormhole';
const String edgeTypePrerequisite = 'prerequisite';

/// 一条边。字段集以 `docs/specs/entity-fields.md` §3–§5 为唯一权威处。
sealed class NodeEdge {
  const NodeEdge();

  /// 线上判别符。**不是**枚举名 —— 它是 JSON 里那个字面值。
  String get type;
}

/// 父子边：主父唯一 + 附加归属（`entity-fields` §3）。
///
/// > 载荷内 `parent_id` 只允许指向**同包节点**或 `attach_to` 申报的那一个骨架
/// > 节点，禁止跨包 —— 否则卸载 A 会拆掉 B 的树。跨包只用 `deps` 表达。
///
/// ⚠️ **这条不在这里校验**：边只能看到自己的两个端点，看不到「本包是谁」，
/// 判据在 `triple_validator.dart`（需要 manifest 的 `plugin_id` 与 `attach_to`）。
/// 把校验塞进构造体的话，`ParentEdge` 就得持有整份包上下文 —— 那会让它无法
/// 单独构造，反例夹具也造不出来。
final class ParentEdge extends NodeEdge {
  const ParentEdge({
    required this.childId,
    required this.parentId,
    required this.kind,
  });

  @override
  String get type => edgeTypeParent;

  final String childId;
  final String parentId;

  /// `main` 每节点恰好一条；`secondary` 是 0..N 的附加归属。
  final ParentEdgeKind kind;

  bool get isMain => kind == ParentEdgeKind.main;
}

/// 虫洞边：跨轴 / 跨枝跳转（`entity-fields` §4）。
///
/// **双向**：跳转后 A 仍是 B 的出口，反之亦然。所以它没有 `from` / `to` 的
/// 方向语义 —— 字段名沿用 `from_id` / `to_id` 只为与数据同形，**不表示有向**。
final class WormholeEdge extends NodeEdge {
  const WormholeEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
    this.note,
  });

  @override
  String get type => edgeTypeWormhole;

  final String fromId;
  final String toId;
  final WormholeKind kind;

  /// 呈现用说明，可空。
  final String? note;
}

/// 先修边：地形（`entity-fields` §5）。
///
/// **允许跨轴**（`Python → 框架调参` 同时涉及学科轴与角色轴），所以这里
/// 不做任何同轴校验。`⪯` 只由 `required` 边构成 —— `recommended` 不参与闭包。
final class PrerequisiteEdge extends NodeEdge {
  const PrerequisiteEdge({
    required this.fromId,
    required this.toId,
    required this.strength,
  });

  @override
  String get type => edgeTypePrerequisite;

  /// 前置 → 后继。
  final String fromId;
  final String toId;
  final EdgeStrength strength;

  bool get isRequired => strength == EdgeStrength.required;
}

/// 按 `type` 判别符分派（**唯一入口**）。
///
/// 未知判别符直接抛 —— 静默跳过会让一条打错字的边凭空消失，而「图里少一条边」
/// 的表象与「数据本来就没有」完全相同，没有断言会红。
NodeEdge nodeEdgeFromJson(JsonMap json) {
  final String type = requireString(json, 'type');
  switch (type) {
    case edgeTypeParent:
      return ParentEdge(
        childId: requireString(json, 'child_id'),
        parentId: requireString(json, 'parent_id'),
        kind: ParentEdgeKind.fromWire(requireString(json, 'kind')),
      );
    case edgeTypeWormhole:
      return WormholeEdge(
        fromId: requireString(json, 'from_id'),
        toId: requireString(json, 'to_id'),
        kind: WormholeKind.fromWire(requireString(json, 'kind')),
        note: optionalString(json, 'note'),
      );
    case edgeTypePrerequisite:
      return PrerequisiteEdge(
        fromId: requireString(json, 'from_id'),
        toId: requireString(json, 'to_id'),
        strength: EdgeStrength.fromWire(requireString(json, 'strength')),
      );
    default:
      throw FormatException(
        '边类型不在册：`$type`（允许 '
        '$edgeTypeParent / $edgeTypeWormhole / $edgeTypePrerequisite）',
      );
  }
}
