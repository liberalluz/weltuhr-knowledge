/// 建计划 / 重规划的事件构造（`event-types.md` §二 B）。
///
/// ## `Plan` 的身份就是「哪条事件创建了它」
///
/// `payload` 里**不写 `planId`**，`Plan.id` 直接取 `plan_created` 事件的 `id`。
/// 理由：一个实体如果既有自己的 id、又有那条创建事件的 id，两者表达同一件事，
/// 迟早出现「planId 与创建事件对不上」的回放歧义 —— 而它没有任何信息增量。
///
/// 反过来，`plan_revised` **必须**带 `planId`：否则同空间多份计划（`PLAN-003`）
/// 在事件流里折不开，重规划究竟改的是哪一份无从判断。
///
/// ## `spaceId` 不进 payload
///
/// 信封上已经有 `spaceId`（`Event.spaceId`）。payload 再写一份就是两份真相，
/// 回放时还得先定「信哪个」。信封那份是过滤维度（`fold(spaceId:)`），
/// 以它为准。
///
/// ## `version` 也不进 payload
///
/// `event-types.md` 原文写 `plan_revised` 的 payload 带 `version = 前值 + 1`。
/// 那是**第二份计数**：`fold` 既在数事件条数、又在读 payload 的版本号，两者乱序
/// 或重传时必然打架。笔记版本已是先例 —— `noteVersion` = 该节 `note_revised`
/// 计数，payload 不写。计划版本照此办理（本笔已同步改表）。
library;

import '../entities/plan.dart';
import '../enums.dart';
import '../events/event.dart';
import '../events/hlc_clock.dart';
import '../events/id.dart';
import '../json.dart';

/// 建计划所需的全部输入。**只装「写进事件的东西」**，不装派生量。
///
/// [spaceId] 是例外：它**不进 payload**，只用来填事件信封（见文件头）。
/// 其余六个字段与 `event-types.md` §二 B 的 `plan_created` 键一一对应。
class PlanDraft {
  const PlanDraft({
    required this.spaceId,
    required this.subtreeRoot,
    required this.primaryAxis,
    required this.packVersions,
    required this.sourcePolicy,
    required this.schemeId,
    required this.methodProfileId,
  });

  /// 信封字段，**不写进 payload**。
  final String spaceId;

  /// 计划范围的根节点 id。取代旧的 `target{selector, resolved}` ——
  /// 子树根已足够表达范围，`resolved` 降为派生。
  final String subtreeRoot;

  final Axis primaryAxis;

  /// 建计划那一刻的包版本组合。换包之后旧计划仍按旧版解释，故必须随事件落盘。
  final PackVersions packVersions;

  /// 主源 + 按类型 + 例外，引用 `SourceRef.id`。
  ///
  /// 当下只落 `primary` 一键 —— 按类型与例外还**没有来源**（`P-8` 才做用户档），
  /// 写两个空容器会被读成「已确认无例外」，与「还没这个概念」分不开。
  final JsonMap sourcePolicy;

  final String schemeId;

  /// `MethodBundle.id`（`entity-fields` §12）。
  final String methodProfileId;

  /// 写进 payload 的那一部分。
  JsonMap toPayload() => <String, Object?>{
    'subtreeRoot': subtreeRoot,
    'primaryAxis': primaryAxis.name,
    'packVersions': packVersions.toJson(),
    'sourcePolicy': sourcePolicy,
    'schemeId': schemeId,
    'methodProfileId': methodProfileId,
  };
}

/// 造一条 `plan_created`。
///
/// [now] 由调用方给（便于测试注入，不是为了让它可选）；`hlc` 与 `id` 都由它派生，
/// 所以同一个 `HlcClock` 连发两次不会撞 id。`at` 也从 `hlc.physical` 派生 ——
/// 它标注的是「人读的时间」，排序一律用 `hlc`。
Event buildPlanCreated({
  required PlanDraft draft,
  required HlcClock clock,
  required DateTime now,
  required String userId,
}) => _build(
  type: EventType.planCreated,
  draft: draft,
  clock: clock,
  now: now,
  userId: userId,
  extra: const <String, Object?>{},
);

/// 造一条 `plan_revised`（`SPEC-PLAN-019` 重入重规划）。
///
/// [planId] = 那份计划的 `plan_created` 事件 `id`。版本号**不在这里算** ——
/// 它由 `fold` 数该 `planId` 名下的事件条数得出，见本文件头部。
Event buildPlanRevised({
  required String planId,
  required PlanDraft draft,
  required HlcClock clock,
  required DateTime now,
  required String userId,
}) => _build(
  type: EventType.planRevised,
  draft: draft,
  clock: clock,
  now: now,
  userId: userId,
  extra: <String, Object?>{'planId': planId},
);

Event _build({
  required EventType type,
  required PlanDraft draft,
  required HlcClock clock,
  required DateTime now,
  required String userId,
  required JsonMap extra,
}) {
  final Hlc hlc = clock.next(now);
  return Event(
    id: eventIdFor(hlc),
    type: type,
    hlc: hlc,
    spaceId: draft.spaceId,
    userId: userId,
    at: DateTime.fromMillisecondsSinceEpoch(hlc.physical, isUtc: true),
    payload: <String, Object?>{...draft.toPayload(), ...extra},
  );
}
