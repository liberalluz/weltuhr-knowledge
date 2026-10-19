/// 把面板上的三段选择组装成一份可落事件的 [PlanDraft]。
///
/// ## `target.resolved` 与预览的「项数」同源
///
/// 两者都调 [resolvePlanScope]。这不是代码复用癖 —— 预览报 12 项而事件里存
/// 120 项，是同一份计划的两个读数，用户看到哪个都觉得另一个坏了。
///
/// ## `selector` 本笔只落空对象
///
/// `PlanTarget.selector` 存「选择式」（结果会随视图与包版本变），但它的**字段级
/// 结构规格里还没定** —— Z3 子图、Z4 单项各自怎么表达选择式，归 `SPEC-PLAN-016`
/// 的三个入口（`P-7`）。本笔只接「整个空间」这一种：空 `selector` = 未按任何
/// 视图收窄，与 `Z1`（全空间）等价。
///
/// 与其现在编一个 `{kind: …}` 的假 schema 让后面照着抄，不如留空并在这里写清。
library;

import '../entities/content.dart';
import '../entities/plan.dart';
import '../pack/pack_parse.dart';
import 'method_bundle.dart';
import 'plan_events.dart';
import 'scope.dart';

/// 组装草稿。[target] 给了就沿用它的 `selector`，并把 `resolved` 按当前包
/// **重算**一遍 —— 旧 `resolved` 可能来自更早的包版本，直接抄会把已下线的项
/// 写进新计划。
PlanDraft composePlanDraft({
  required LoadedPack pack,
  required String sourceId,
  required String schemeId,
  required MethodBundle bundle,
  PlanTarget? target,
}) {
  final PlanScope scope = resolvePlanScope(
    pack: pack,
    schemeId: schemeId,
    target: target,
  );

  return PlanDraft(
    spaceId: pack.space.id,
    spaceVersion: pack.space.version,
    target: PlanTarget(
      selector: target?.selector ?? const <String, Object?>{},
      resolved: <String>[for (final Item item in scope.items) item.id],
    ),
    sourcePolicy: <String, Object?>{'primary': sourceId},
    schemeId: schemeId,
    methodProfileId: bundle.id,
  );
}
