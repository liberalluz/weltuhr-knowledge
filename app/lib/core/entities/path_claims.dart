/// path 的两份账：**占用**与**重定向**（`entity-fields` §6–§7）。
///
/// 两者装在同一文件，因为解析顺序把它们绑成一件事：
/// **`live` → `tombstone`（命中即报「此地址已停用」）→ `alias` 重定向**。
/// 反过来先查 alias，已复用的旧地址会盖掉现役节点 —— 这个顺序错了不会崩，
/// 只会把用户送到一个不该去的节点上。
library;

import '../enums.dart';
import '../json.dart';

/// path 占用（`entity-fields` §6）。
///
/// **只管插件节点**：骨架 path 由构建过程一次性保证唯一，运行时无需再维护一份账。
class PathClaim {
  const PathClaim({
    required this.path,
    required this.nodeId,
    required this.state,
  });

  factory PathClaim.fromJson(JsonMap json) => PathClaim(
    path: requireString(json, 'path'),
    nodeId: requireString(json, 'node_id'),
    state: ClaimState.fromWire(requireString(json, 'state')),
  );

  /// 完整 path。
  final String path;

  /// 占用者。
  final String nodeId;

  /// `tombstone` 表示「这个地址曾经有人用、现在停用了」。
  ///
  /// **墓碑不能随插件卸载一起删**：删了之后「A 卸载 → B 装上 → A 再装回」，
  /// A 会以为自己是首次占用，直接覆盖 B。
  final ClaimState state;

  bool get isTombstone => state == ClaimState.tombstone;

  JsonMap toJson() => <String, Object?>{
    'path': path,
    'node_id': nodeId,
    'state': state.name,
  };
}

/// 路径重定向（`entity-fields` §7）。
///
/// **禁止成链**：写入 `A→B` 时若 `B` 已是某个别名的 `oldPath`，把 `A` 直接
/// 改指 `B` 的目标。解析只需一跳，不可能成环。
class PathAlias {
  const PathAlias({
    required this.oldPath,
    required this.nodeId,
    required this.reason,
    this.fromVer,
    this.toVer,
  });

  factory PathAlias.fromJson(JsonMap json) => PathAlias(
    oldPath: requireString(json, 'old_path'),
    nodeId: requireString(json, 'node_id'),
    reason: PathAliasReason.fromWire(requireString(json, 'reason')),
    fromVer: optionalString(json, 'from_ver'),
    toVer: optionalString(json, 'to_ver'),
  );

  final String oldPath;

  /// 现役节点。
  final String nodeId;
  final PathAliasReason reason;

  /// **仅 `parentChange` 必填** —— 骨架升版改主父。
  final String? fromVer;
  final String? toVer;

  /// `parentChange` 时版本区间缺失即为坏数据（`entity-fields` §7）。
  ///
  /// 返回判据而不抛错，理由同 `NodeEntry.isQuizAligned`：这不是类型级不变式，
  /// 坏数据的表象是「旧链接跳到最新版本」，归包构建期与写入路径校验。
  bool get hasVersionRange =>
      reason != PathAliasReason.parentChange ||
      (fromVer != null && toVer != null);

  JsonMap toJson() => <String, Object?>{
    'old_path': oldPath,
    'node_id': nodeId,
    'reason': reason.wire,
    if (fromVer != null) 'from_ver': fromVer,
    if (toVer != null) 'to_ver': toVer,
  };
}
