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

  /// 本次计划覆盖多少项：选了体系 = 该体系的节点数，否则 = 圈内全量。
  final int itemCount;

  /// 分母 = 圈内项数。**不随体系覆盖度变化。**
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
PlannerPreview computePlannerPreview({
  required LoadedPack pack,
  String? schemeId,
  MethodBundle? bundle,
  List<MethodProfile> profiles = platformMethodProfiles,
}) {
  final int denominator = pack.items.where((Item i) => i.inScope).length;

  final List<Item> scope;
  if (schemeId == null) {
    scope = <Item>[
      for (final Item item in pack.items)
        if (item.inScope) item,
    ];
  } else {
    final List<String>? nodes = pack.schemeNodes(schemeId);
    if (nodes == null) {
      throw ArgumentError('不存在的体系 id：`$schemeId`（`pack.schemes` 里没有）');
    }
    scope = <Item>[
      for (final String id in nodes)
        if (pack.itemOf(id) != null) pack.itemOf(id)!,
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
