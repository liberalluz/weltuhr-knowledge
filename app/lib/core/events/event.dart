/// 事件：唯一的可写事实源（`SPEC-FND-010`）。
///
/// 铁律：所有可写状态由 `fold(events, asOf)` 得出；不得引入并行的可写状态表。
library;

import '../constants.dart';
import '../json.dart';

/// 事件类型全集。唯一权威处 = `docs/reference/event-types.md` §二。
///
/// **新增类型须先在该表登记**（含 payload 字段与是否写判定），再实现。
enum EventType {
  // A. 学习执行
  stepCompleted,
  itemGraded,
  itemPassed,
  itemSkipped,
  graduated,
  // B. 计划
  planCreated,
  planRevised,
  // C. 内容迁移
  stateCarried,
  stateMerged,
  itemRetired,
  // D. 笔记
  noteRevised,
}

/// 线上（pack / 服务端）用 snake_case；Dart 侧用 camelCase。
String eventTypeWireName(EventType type) {
  switch (type) {
    case EventType.stepCompleted:
      return 'step_completed';
    case EventType.itemGraded:
      return 'item_graded';
    case EventType.itemPassed:
      return 'item_passed';
    case EventType.itemSkipped:
      return 'item_skipped';
    case EventType.graduated:
      return 'graduated';
    case EventType.planCreated:
      return 'plan_created';
    case EventType.planRevised:
      return 'plan_revised';
    case EventType.stateCarried:
      return 'state_carried';
    case EventType.stateMerged:
      return 'state_merged';
    case EventType.itemRetired:
      return 'item_retired';
    case EventType.noteRevised:
      return 'note_revised';
  }
}

EventType eventTypeFromWire(String wire) {
  for (final EventType type in EventType.values) {
    if (eventTypeWireName(type) == wire) {
      return type;
    }
  }
  throw FormatException('未知事件类型：$wire');
}

/// 混合逻辑时钟（`SPEC-FND-011`）。
///
/// 离线也能生成，且保证**全序** —— 这是它取代服务端递增序号的唯一理由。
class Hlc implements Comparable<Hlc> {
  const Hlc({required this.physical, required this.counter, required this.deviceId});

  factory Hlc.fromJson(JsonMap json) => Hlc(
    physical: requireInt(json, 'physical'),
    counter: requireInt(json, 'counter'),
    deviceId: requireString(json, 'deviceId'),
  );

  /// 毫秒时间戳。**会被设备时钟偏差污染，须由服务端 clamp**。
  final int physical;
  final int counter;
  final String deviceId;

  @override
  int compareTo(Hlc other) {
    final int byPhysical = physical.compareTo(other.physical);
    if (byPhysical != 0) {
      return byPhysical;
    }
    final int byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) {
      return byCounter;
    }
    return deviceId.compareTo(other.deviceId);
  }

  JsonMap toJson() => <String, Object?>{
    'physical': physical,
    'counter': counter,
    'deviceId': deviceId,
  };

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.physical == physical &&
      other.counter == counter &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(physical, counter, deviceId);
}

/// 一条事件。
///
/// **没有 `copyWith`，也没有可变字段** —— 事件只 append（`SPEC-FND-012`）。
class Event {
  const Event({
    required this.id,
    required this.type,
    required this.hlc,
    required this.spaceId,
    required this.userId,
    required this.at,
    this.itemId,
    this.payload = const <String, Object?>{},
  });

  factory Event.fromJson(JsonMap json) => Event(
    id: requireString(json, 'id'),
    type: eventTypeFromWire(requireString(json, 'type')),
    hlc: Hlc.fromJson(requireMap(json, 'hlc')),
    spaceId: requireString(json, 'spaceId'),
    userId: requireString(json, 'userId'),
    itemId: optionalString(json, 'itemId'),
    at: DateTime.parse(requireString(json, 'at')),
    payload: requireMap(json, 'payload'),
  );

  /// 全局唯一。**`id` 建 UNIQUE 索引做上传幂等**：同一条事件被传两次只留一条。
  ///
  /// 注意与「两设备各学一遍同一项」区分：那是两个不同 `id`，**不去重**。
  final String id;
  final EventType type;
  final Hlc hlc;
  final String spaceId;

  /// **数据归属**（`SPEC-ACC-013`）。与 [hlc] 分工不同：它定「这条属于谁」，
  /// `hlc` 定「谁先谁后」。两者合并会让「A 的迟到事件排成 B 的更早事件」
  /// 变成无法排查的错。
  ///
  /// `v0.1.0` 取本地默认值（[localDefaultUserId]），**非空、不写 `null`** ——
  /// 空值会让 `fold` 的过滤维度多出第三个分支。
  final String userId;

  /// 目标知识项；迁移类事件可为空或指向旧 id。
  final String? itemId;

  /// ISO-8601，由 [hlc] 派生，**仅供人读**；排序一律用 [hlc]。
  final DateTime at;

  final JsonMap payload;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'type': eventTypeWireName(type),
    'hlc': hlc.toJson(),
    'spaceId': spaceId,
    'userId': userId,
    if (itemId != null) 'itemId': itemId,
    'at': at.toIso8601String(),
    'payload': payload,
  };
}
