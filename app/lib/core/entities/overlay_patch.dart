/// 覆盖补丁（`entity-fields` §8）—— 低层改表述、加内容、加边的唯一入口。
///
/// 四条铁律（原文，四条都是「违反它不会有任何东西变红」的那种，所以抄在这里）：
///
/// ① `id` / `official_code` / 主父 / `level_slot` **绝对不可覆盖**
/// ② 删除只在视图层（`visible = false`），不得物理删除
/// ③ `M3` 派生字段默认禁改，需显式 `frozen` 声明
/// ④ `profile` ≠ `scope`：`profile` 是被激活的 scope 链，不是一层
///
/// 本类**只承载数据，不做校验**：铁律 ① 的字段名是 `Node` / `ParentEdge` 的
/// 知识，写在这里会让一个纯数据类反向依赖树结构。校验落 `NodeEntry` 的可
/// patch 集 + 写入路径。
library;

import '../enums.dart';
import '../json.dart';

/// 一条字段级补丁。
class OverlayPatch {
  const OverlayPatch({
    required this.scope,
    required this.targetId,
    required this.field,
    required this.value,
    required this.baseHash,
    required this.state,
  });

  factory OverlayPatch.fromJson(JsonMap json) => OverlayPatch(
    scope: Scope.fromWire(requireString(json, 'scope')),
    targetId: requireString(json, 'target_id'),
    field: requireString(json, 'field'),
    value: json['value'],
    baseHash: requireString(json, 'base_hash'),
    state: PatchState.fromWire(requireString(json, 'state')),
  );

  /// `S0`–`S4`。优先级「最具体者胜出」：`S4 > S3 > S2 > S1 > S0`。
  final Scope scope;

  /// 被补丁的 `Node.id`。
  final String targetId;

  /// 字段路径，须在 `NodeEntry` 的可 patch 集内（`entity-fields` §9）。
  final String field;

  /// 任意 JSON 值。**不强制类型**：补丁改的是「值的这一格」，
  /// 类型对不对由目标字段自己判 —— 在这里收窄等于把 §9 的字段表抄一遍。
  final Object? value;

  /// 打补丁时目标值的指纹。
  final String baseHash;

  final PatchState state;

  /// 指纹失配 ⇒ `stale`，**不自动应用**。
  ///
  /// 自动应用等于让一次静默的数据漂移改写作者的表述 —— 而作者不会知道
  /// 自己写的话被换掉了。
  bool get isStale => state == PatchState.stale;

  JsonMap toJson() => <String, Object?>{
    'scope': scope.name,
    'target_id': targetId,
    'field': field,
    'value': value,
    'base_hash': baseHash,
    'state': state.name,
  };
}
