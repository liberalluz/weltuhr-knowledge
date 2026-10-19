/// Planner 右栏的实时预览（`SPEC-PLAN-015`）：**只三项** —— 项数 · 分母 · 预计时长。
///
/// ## 为什么不给难度分布
///
/// `D` 在建计划时**还不存在**（FSRS 首次评分才初始化），而 `φ` 不能当难度代理。
/// 硬画一张分布图，等于把一个尚未产生的量画出来给人看。
///
/// ## 分母为什么与项数分开
///
/// 分母 = **圈内项数**，不随体系覆盖度变化（`SPEC-PLAN-015`）。选中一套只覆盖
/// 一半节点的体系时，项数变小、分母不变 —— 那个差值本身就是信息：「这套序漏了
/// 一半内容」，而不是「这个空间只有一半内容」。
///
/// ## 项数与分母回答两个不同的问题
///
/// 分母答「这个空间一共多大」，项数答「这次要走多少」。两者相减是**两笔不同的
/// 差额**，混成一笔就再也分不开：
///
/// ```text
/// 分母 150（圈内）
///  ├─ 体系覆盖 120          ← 分母 − 120 = 30 项游离，这套序没安排
///  │   ├─ 在 target 里 12   ← 项数
///  │   └─ 不在 target 里 108 ← 120 − 12，这套序还管着圈外的部分
///  └─ 游离 30
/// ```
///
/// 分母若跟着体系缩，「空间只有 150 项」与「这套序只覆盖 120 项」就变成一个数，
/// 用户看不出是哪种情况。
///
/// ## `target` 收窄的是这一份计划，不是空间
///
/// 传了 `target` 就只在它圈定的项里数项数（`PLAN-016` 的定位结果入口会带窄
/// `target`）。空间恒为 [PlannerPreview.denominator] 项，剩下的项靠**另建一份
/// `Plan`**（`SPEC-PLAN-003` 允许同空间并存多份），不存在一份会自己长大的计划。
/// `target` 缺省 = 圈内全量。
///
/// ## 时长
///
/// `Σ(算子系数 × 步骤数 × 项数)`，系数见 `C-14`…`C-19`。逐项按 `Item.type`
/// 派生到分支 profile 再累加 —— 同一套方法对不同类型可以给不同步骤数，先乘平均
/// 再乘项数会把这件事抹平。
///
/// 未选方法时按**平台默认组合**估，并把 [usingDefaultMethod] 置真，让界面能写
/// 「按默认估算」而不是假装这是用户选出来的读数。
library;

import '../constants.dart';
import '../entities/content.dart';
import '../entities/plan.dart';
import '../pack/pack_parse.dart';
import 'method_bundle.dart';
import 'platform_candidates.dart';

/// 预览的三个读数 + 两个「这个数有多可信」的标记。
class PlannerPreview {
  const PlannerPreview({
    required this.itemCount,
    required this.denominator,
    required this.minutes,
    required this.usingDefaultMethod,
    required this.uncoveredItems,
  });

  /// 本次计划覆盖多少项 = 圈内项 ∩ 体系节点 ∩ `target`。
  ///
  /// 三者都是「有则收窄、无则不收」：没选体系 = 圈内全量，没给 `target` = 不按
  /// 计划范围收窄。**它恒 ≤ [denominator]**。
  final int itemCount;

  /// 分母 = 圈内项数。**不随体系覆盖度变化，也不随 `target` 变化。**
  final int denominator;

  /// 预计分钟数。
  final int minutes;

  /// 未选方法，时长按平台默认组合估算。
  final bool usingDefaultMethod;

  /// 方法未覆盖类型的项数。`> 0` 时确认段必须拦住 —— 那些项没有可用步骤。
  final int uncoveredItems;

}

/// 算一次预览。纯函数：不读盘、不看时钟。
///
/// [schemeId] 不存在时抛 `ArgumentError`（与 `loadCandidates` 同一口径：那是
/// 调用方拿错了 id，静默回落到全量会让人以为这套体系覆盖了全部）。
///
/// [target] 为 `null` = 不按计划范围收窄（圈内全量）。给了它就只在
/// `target.resolved` 圈定的项里数 [PlannerPreview.itemCount]；
/// [PlannerPreview.denominator] **不受它影响** —— 分母是空间规模，不是计划规模。
PlannerPreview computePlannerPreview({
  required LoadedPack pack,
  String? schemeId,
  PlanTarget? target,
  MethodBundle? bundle,
  List<MethodProfile> profiles = platformMethodProfiles,
}) {
  final List<Item> inScope = <Item>[
    for (final Item item in pack.items)
      if (item.inScope) item,
  ];
  final int denominator = inScope.length;

  final List<Item> scoped;
  if (schemeId == null) {
    scoped = inScope;
  } else {
    final List<String>? nodes = pack.schemeNodes(schemeId);
    if (nodes == null) {
      throw ArgumentError('不存在的体系 id：`$schemeId`（`pack.schemes` 里没有）');
    }
    // 只数**圈内**项：圈外项是邻项（`VIEW-004`），既不能落点也不该进计划。
    // 不拦的话，体系节点一旦含圈外项，项数会超过分母 —— 一份计划覆盖的项比
    // 空间总量还多，是自相矛盾。用集合查而非按节点顺序取：这里只数个数与累加
    // 分钟，与顺序无关，重复节点也顺带折成一项。
    final Set<String> nodeSet = nodes.toSet();
    scoped = <Item>[
      for (final Item item in inScope)
        if (nodeSet.contains(item.id)) item,
    ];
  }

  final List<Item> scope;
  if (target == null) {
    scope = scoped;
  } else {
    final Set<String> keep = target.resolved.toSet();
    scope = <Item>[
      for (final Item item in scoped)
        if (keep.contains(item.id)) item,
    ];
  }

  final MethodBundle effective = bundle ?? platformMethodBundles.first;
  final Map<String, MethodProfile> byId = <String, MethodProfile>{
    for (final MethodProfile p in profiles) p.id: p,
  };

  int minutes = 0;
  int uncovered = 0;
  for (final Item item in scope) {
    final String? profileId = effective.profileIdFor(item.type);
    final MethodProfile? profile = profileId == null ? null : byId[profileId];
    if (profile == null) {
      uncovered++;
      continue;
    }
    for (final MethodStep step in profile.steps) {
      minutes += operatorMinutes[step.operator] ?? 0;
    }
  }

  return PlannerPreview(
    itemCount: scope.length,
    denominator: denominator,
    minutes: minutes,
    usingDefaultMethod: bundle == null,
    uncoveredItems: uncovered,
  );
}
