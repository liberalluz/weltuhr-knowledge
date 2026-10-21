/// 把面板上的三段选择组装成一份可落事件的 [PlanDraft]。
///
/// ## 范围与预览的「节点数」同源
///
/// 两者都调 [resolvePlanScope]。这不是代码复用癖 —— 预览报 12 项而事件里存
/// 120 项，是同一份计划的两个读数，用户看到哪个都觉得另一个坏了。
///
/// ## 范围由 `subtreeRoot` 表达，选择式已废
///
/// 旧实现的 `PlanTarget{selector, resolved}` 四个形态（`space` / `domain` /
/// `item` / `query`）随 `ADR-0005` 一并取消：子树根 id 已足够表达范围，
/// 而 `resolved` 是派生值 —— 存下来就会出现「参照集合指向已卸载的节点」。
/// 于是本函数不再需要 `target` 入参，只需要根节点与树索引。
///
/// ## `packVersions` 由调用方给，不在这里拼
///
/// 「这次计划建立在哪几个包的哪几个版本上」是**装载层**的知识：`PackContent`
/// 只装一个包，骨架版本不在它里面。在这里拼一个单包版本只会让多包场景静默
/// 少记几个版本 —— 而旧计划正是靠这份快照才能按旧语义解释。
library;

import '../entities/method.dart';
import '../entities/plan.dart';
import '../entities/scheme.dart';
import '../enums.dart';
import '../pack/pack_reader.dart';
import 'plan_events.dart';
import 'scope.dart';

/// 组装草稿。
///
/// [userSchemes] 必须与预览那次**传同一份**：两边各传各的，会出现「预览说 12
/// 项、事件里存 4 项」—— 而那不是异常，是两份不同的解算结果。
PlanDraft composePlanDraft({
  required PackContent pack,
  required String spaceId,
  required String subtreeRoot,
  required Axis primaryAxis,
  required PackVersions packVersions,
  required String sourceId,
  required String schemeId,
  required MethodBundle bundle,
  List<Scheme> userSchemes = const <Scheme>[],
}) {
  // 范围**不在这里算**：落盘形态是 `subtreeRoot` + `packVersions`，`resolved`
  // 由 fold 时按同一份算法重算（两处各存一份必然分叉）。
  //
  // 但体系 id 拿错必须**当场**抛：预览那侧走 `resolvePlanScope`，它在同一处
  // 抛出。这里不重算范围，却同样要拦住坏 id —— 否则会落下一份指向不存在体系
  // 的计划，而它读回来时看起来只是「这套体系没覆盖任何东西」。
  if (schemeNodesOf(
        pack: pack,
        schemeId: schemeId,
        userSchemes: userSchemes,
      ) ==
      null) {
    throw ArgumentError('不存在的体系 id：`$schemeId`（包与自建里都没有）');
  }

  return PlanDraft(
    spaceId: spaceId,
    subtreeRoot: subtreeRoot,
    primaryAxis: primaryAxis,
    packVersions: packVersions,
    sourcePolicy: <String, Object?>{'primary': sourceId},
    schemeId: schemeId,
    methodProfileId: bundle.id,
  );
}
