/// 「这次计划覆盖哪些项」的**唯一**算法：圈内 ∩ 体系节点 ∩ `target`。
///
/// ## 为什么只能有一个实现
///
/// 预览报的**项数**，与建计划时写进 `Plan.target.resolved` 的列表，答的是
/// **同一个问题**。两处各写一遍，迟早出现「界面报 12 项、事件里存 120 项」——
/// 这种错不会抛异常，也不会让任何用例变红，只会让某天统计对不上而查不出原因。
///
/// 所以 `computePlannerPreview` 与 `composePlanDraft` 都调这里。
///
/// ## 分母为什么不跟着一起收
///
/// [PlanScope.denominator] 恒为圈内项数，不随体系、不随 `target` 变化 ——
/// 它是**空间规模**，不是计划规模。理由见 `preview.dart` 头部那张差额图。
library;

import '../entities/content.dart';
import '../entities/plan.dart';
import '../pack/pack_parse.dart';

/// 一次落点解算的结果：具体哪些项 + 它们占空间多大。
class PlanScope {
  const PlanScope({required this.items, required this.denominator});

  /// 落点项，按 `pack.items` 顺序。
  ///
  /// 顺序**不承载学习次序** —— 那是 `Scheme.nodes` 的事。这里只保证同一个输入
  /// 给出同一个列表，好让 `target.resolved` 落盘之后可以逐字比对。
  final List<Item> items;

  /// 分母 = 圈内项数。**不随体系覆盖度、也不随 `target` 变化。**
  final int denominator;
}

/// 解算落点。纯函数：不读盘、不看时钟。
///
/// [schemeId] 不存在时抛 `ArgumentError`（与 `loadCandidates` 同一口径：那是
/// 调用方拿错了 id，静默回落到全量会让人以为这套体系覆盖了全部）。
///
/// [userSchemes] 是用户自建的体系（`SPEC-PLAN-007` 的「+ 自建」）。**必须由
/// 调用方显式传**：`LoadedPack` 只装包里那两套，自建的体系不在包里 —— 不传
/// 就会在选到自建体系时抛「不存在的体系 id」，而那不是「自建失败」，是本函数
/// 看不到它。查找顺序与 `mergeByOrigin` 同：**user 优先于包**。
///
/// [target] 为 `null` = 不按计划范围收窄。给了它就只在 `target.resolved` 圈定
/// 的项里取 [PlanScope.items]。
PlanScope resolvePlanScope({
  required LoadedPack pack,
  String? schemeId,
  PlanTarget? target,
  List<Scheme> userSchemes = const <Scheme>[],
}) {
  final List<Item> inScope = <Item>[
    for (final Item item in pack.items)
      if (item.inScope) item,
  ];

  final List<Item> scoped;
  if (schemeId == null) {
    scoped = inScope;
  } else {
    final List<String>? nodes = schemeNodesOf(
      pack: pack,
      schemeId: schemeId,
      userSchemes: userSchemes,
    );
    if (nodes == null) {
      throw ArgumentError('不存在的体系 id：`$schemeId`（包与自建里都没有）');
    }
    // 只取**圈内**项：圈外项是邻项（`VIEW-004`），既不能落点也不该进计划。
    // 不拦的话，体系节点一旦含圈外项，项数会超过分母 —— 一份计划覆盖的项比
    // 空间总量还多，是自相矛盾。用集合查而非按节点顺序取：同一项在 `nodes`
    // 里出现两次也只算一项。
    final Set<String> nodeSet = nodes.toSet();
    scoped = <Item>[
      for (final Item item in inScope)
        if (nodeSet.contains(item.id)) item,
    ];
  }

  if (target == null) {
    return PlanScope(items: scoped, denominator: inScope.length);
  }

  final Set<String> keep = target.resolved.toSet();
  return PlanScope(
    items: <Item>[
      for (final Item item in scoped)
        if (keep.contains(item.id)) item,
    ],
    denominator: inScope.length,
  );
}

/// 体系节点：**自建优先，其次包**（与 `mergeByOrigin` 的 `user > pack` 同序）。
///
/// 两处都找不到才是 `null`。**只有这一处查节点** —— `resolvePlanScope` 与
/// `loadCandidates` 的参照集合都走它。各写一份的话，自建体系在候选列表里看得
/// 见、一选中就抛「不存在的体系 id」，而抛错的那一处与显示的那一处看起来毫无
/// 关系（`P-8` 首次跑用例就是这么红的）。
List<String>? schemeNodesOf({
  required LoadedPack pack,
  required String schemeId,
  List<Scheme> userSchemes = const <Scheme>[],
}) {
  for (final Scheme scheme in userSchemes) {
    if (scheme.id == schemeId) {
      return scheme.nodes;
    }
  }
  return pack.schemeNodes(schemeId);
}
