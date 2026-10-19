/// 把面板上的三段选择组装成一份可落事件的 [PlanDraft]。
///
/// ## `target.resolved` 与预览的「项数」同源
///
/// 两者都调 [resolvePlanScope]。这不是代码复用癖 —— 预览报 12 项而事件里存
/// 120 项，是同一份计划的两个读数，用户看到哪个都觉得另一个坏了。
///
/// ## `selector` 的四个取值已由 `P-7` 定下
///
/// `PlanTarget.selector` 存「选择式」（结果会随视图与包版本变）；四种形态
/// （`space` / `domain` / `item` / `query`）见 [PlanSelector]，解算见
/// [resolvePlanTarget]。`P-6` 曾只落空对象 —— 那时字段级结构还没定。
///
/// [target] 为 `null` 是**测试与构造输入**才走的路径，产品代码不走：三个入口
/// 都显式给一份 selector（`P-7`）。
library;

import '../entities/content.dart';
import '../entities/plan.dart';
import '../pack/pack_parse.dart';
import 'method_bundle.dart';
import 'plan_events.dart';
import 'plan_target.dart';
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
