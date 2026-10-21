/// 计划（意图）。**键是 `subtree_root`**：同一子树可并存多份 Plan（如
/// 「入门跑通」与「专攻异步」），不存在跨子树的「总 Plan」。
///
/// 旧版的键是 `spaceId` —— 一空间一包时代的遗留。载荷包可独立安装之后，
/// 「这份计划管哪一片」只能由节点 id 回答（`entity-fields` §13）。
library;

import '../enums.dart';
import '../json.dart';

/// 建计划那一刻装载的包版本快照。
///
/// **为什么是复合值而不是一个字符串**：旧 `spaceVersion` 是单值，装不下
/// 「骨架 v3 + 中文包 v2 + 英语包 v1」这种组合，而旧计划必须按**建时的组合**
/// 解释 —— 载荷包各自独立升级，任何一个换了版本都可能让已学过的节点 id 语义变化。
class PackVersions {
  const PackVersions({required this.skeleton, required this.payloads});

  factory PackVersions.fromJson(JsonMap json) => PackVersions(
    skeleton: requireString(json, 'skeleton'),
    payloads: requireStringMap(json, 'payloads'),
  );

  /// 骨架版本。骨架是所有载荷的父，单独一格。
  final String skeleton;

  /// `plugin_id → version`。**不含骨架** —— 混进来会与 [skeleton] 两处记账。
  final Map<String, String> payloads;

  JsonMap toJson() => <String, Object?>{
    'skeleton': skeleton,
    'payloads': payloads,
  };
}

/// 计划。`progress` / `resolved` / `sessions` 都是派生值，不存字段。
///
/// `resolved`（子树下全部可学项 id）尤其不能存：载荷安装变化时必须重算，
/// 存下来就会出现「参照集合指向已卸载的项」而没有任何一处会报错。
class Plan {
  const Plan({
    required this.id,
    required this.subtreeRoot,
    required this.primaryAxis,
    required this.packVersions,
    required this.sourcePolicy,
    required this.schemeId,
    required this.methodProfileId,
    required this.version,
  });

  factory Plan.fromJson(JsonMap json) => Plan(
    id: requireString(json, 'id'),
    subtreeRoot: requireString(json, 'subtreeRoot'),
    primaryAxis: Axis.fromWire(requireString(json, 'primaryAxis')),
    packVersions: PackVersions.fromJson(requireMap(json, 'packVersions')),
    sourcePolicy: requireMap(json, 'sourcePolicy'),
    schemeId: requireString(json, 'schemeId'),
    methodProfileId: requireString(json, 'methodProfileId'),
    version: requireInt(json, 'version'),
  );

  final String id;

  /// **节点 id**，不是 `path` —— `id` 稳定，`path` 会随父节点改名而变。
  ///
  /// 取代旧的 `spaceId`。`spaceId` 不进 payload：信封上已有 `Event.spaceId`，
  /// 它还是 `fold(spaceId:)` 的过滤维度，payload 再写一份就会出现「过滤按信封、
  /// 还原按 payload」的分裂。
  final String subtreeRoot;

  /// 主序轴。**默认由模式给出**，可被体系显式覆盖 —— 模式锁的是默认值，
  /// 不是访问权。
  final Axis primaryAxis;

  final PackVersions packVersions;

  /// 主源 + 按类型 + 例外，引用 `SourceRef.id`。
  final JsonMap sourcePolicy;
  final String schemeId;

  /// `MethodBundle.id`（`entity-fields` §12）。
  final String methodProfileId;

  /// 重规划时 +1，**由 `fold` 数该计划名下事件条数得出**，payload 不写。
  final int version;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'subtreeRoot': subtreeRoot,
    'primaryAxis': primaryAxis.name,
    'packVersions': packVersions.toJson(),
    'sourcePolicy': sourcePolicy,
    'schemeId': schemeId,
    'methodProfileId': methodProfileId,
    'version': version,
  };
}
