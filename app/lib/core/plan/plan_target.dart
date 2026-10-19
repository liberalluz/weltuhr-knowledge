/// 计划范围的**选择式**：描述「范围是圈出来的」，不是「圈出了哪些项」。
///
/// ## 为什么存式不存表
///
/// `entity-fields` §8：`target.selector` 存选择式，`resolved` 是解析后的项 id。
/// 结果会随视图与包版本变 —— 包升版后某些项下线，存着的结果表就成了一份
/// **指向不存在项的引用**，而它没有任何地方能判出「这条已经失效」。存式则可以
/// 拿新包重算一遍。
///
/// ## 四种 kind 对应四种视距
///
/// `SPEC-PLAN-002` / `FND-006` 说“粒度随视距：Z1 ≈150 项 / Z3 ≈12 项 / Z4 = 1 项”，
/// 这里把那句话直接落成四个取值，一格不多：
///
/// | kind | 从哪来 | 解析成 |
/// |---|---|---|
/// | `space` | `Z1`（全空间） | 全部圈内项 |
/// | `domain` | `Z3`（一个域） | 该域全部圈内项 |
/// | `item` | `Z4`（单项） | 该项自身 |
/// | `query` | 定位结果「按此范围建计划」 | 命中集折算成的项集 |
///
/// **不设第五种**（如「按体系节点」）：体系是 `Plan` 的第三段，不是范围。
/// 让 selector 咬住体系会把「范围」与「怎么做」两件事混成一件 —— 而
/// `SPEC-PLAN-004` 的三级分工正是把这两件事分开的那条线。
///
/// ## 为什么 `query` 也进选择式
///
/// 定位结果带的不是「一组项 id」，是「用户搜的那个词」。只存 id 列表会丢掉
/// 这层由来 —— 之后回看这份计划，没人说得清那 12 项是按什么圈出来的，也就
/// 无法在换包后重算。存词则始终能重放（`Locator` 是纯函数）。
library;

import '../entities/content.dart';
import '../entities/plan.dart';
import '../json.dart';
import '../locate/locator.dart';
import '../pack/pack_parse.dart';

/// 选择式的四种形态（见文件头表格）。
enum PlanTargetKind { space, domain, item, query }

/// 计划范围的选择式。
///
/// 构造器按 kind 分开写而不是收一个 `(kind, {domainId, itemId, query})` 的
/// 大构造函数：后者允许「kind = `item` 但 `domainId` 也给了」这种组合，
/// 而那在解析时必然要挑一个信 —— 一个不可能构造出来的错，比一条断言便宜。
class PlanSelector {
  const PlanSelector._({
    required this.kind,
    this.domainId,
    this.itemId,
    this.query,
  });

  /// 整个空间（`Z1` 的「开始学习」）。
  const PlanSelector.space() : this._(kind: PlanTargetKind.space);

  /// 一个域（`Z3`）。
  const PlanSelector.domain(String domainId)
    : this._(kind: PlanTargetKind.domain, domainId: domainId);

  /// 一个项（`Z4`）。
  const PlanSelector.item(String itemId)
    : this._(kind: PlanTargetKind.item, itemId: itemId);

  /// 一句查询（定位结果的「按此范围建计划」）。
  const PlanSelector.query(String query)
    : this._(kind: PlanTargetKind.query, query: query);

  factory PlanSelector.fromJson(JsonMap json) {
    final String kind = requireString(json, 'kind');
    switch (kind) {
      case 'space':
        return const PlanSelector.space();
      case 'domain':
        return PlanSelector.domain(requireString(json, 'domainId'));
      case 'item':
        return PlanSelector.item(requireString(json, 'itemId'));
      case 'query':
        return PlanSelector.query(requireString(json, 'query'));
    }
    // 不认识就抛，不回落成 `space`：回落会让一份「按异步子图建的计划」在
    // 某个版本之后静默变成「整个空间」，而没有任何断言会红。
    throw ArgumentError('未知的 selector.kind：`$kind`');
  }

  final PlanTargetKind kind;

  /// 仅 `domain` 非空。
  final String? domainId;

  /// 仅 `item` 非空。
  final String? itemId;

  /// 仅 `query` 非空。
  final String? query;

  JsonMap toJson() => <String, Object?>{
    'kind': kind.name,
    if (domainId != null) 'domainId': domainId,
    if (itemId != null) 'itemId': itemId,
    if (query != null) 'query': query,
  };

  @override
  bool operator ==(Object other) =>
      other is PlanSelector &&
      other.kind == kind &&
      other.domainId == domainId &&
      other.itemId == itemId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(kind, domainId, itemId, query);

  @override
  String toString() => 'PlanSelector(${toJson()})';
}

/// 把选择式解算成 [PlanTarget]（`selector` 原样存，`resolved` 现算）。
///
/// [resolved] 的顺序**恒按 `pack.items` 的顺序**，与 [resolvePlanScope] 一致 ——
/// 两处顺序不同会让同一份计划在两次建之间产生不同的 `resolved` 数组，逐字比对
/// 就失效了。
///
/// 圈外项（`Item.inScope == false`）一律不进 `resolved`：它们是邻项
/// （`SPEC-VIEW-004`），既不能落点也不该被安排。这一条与 [resolvePlanScope]
/// 同口径 —— 反过来的话，「按域建计划」会把邻项一起圈进来，而预览那边筛掉了，
/// 于是界面报 12、事件里存 15。
PlanTarget resolvePlanTarget({
  required LoadedPack pack,
  required PlanSelector selector,
}) {
  final Set<String> keep = switch (selector.kind) {
    PlanTargetKind.space => _allInScope(pack),
    PlanTargetKind.domain => _byDomain(pack, selector.domainId!),
    PlanTargetKind.item => _oneItem(pack, selector.itemId!),
    PlanTargetKind.query => _byQuery(pack, selector.query!),
  };

  return PlanTarget(
    selector: selector.toJson(),
    resolved: <String>[
      for (final Item item in pack.items)
        if (keep.contains(item.id)) item.id,
    ],
  );
}

Set<String> _allInScope(LoadedPack pack) => <String>{
  for (final Item item in pack.items)
    if (item.inScope) item.id,
};

Set<String> _byDomain(LoadedPack pack, String domainId) => <String>{
  for (final Item item in pack.items)
    if (item.inScope && item.domainId == domainId) item.id,
};

/// 单项。**圈外项给空集**，不是给那一项 —— selector 与 resolved 必须自洽：
/// 留着一项圈外 id，`scope.dart` 那边会把它筛掉，于是同一份 `PlanTarget`
/// 的 `count` 与建计划时的项数对不上。
Set<String> _oneItem(LoadedPack pack, String itemId) {
  final Item? item = pack.itemOf(itemId);
  if (item == null || !item.inScope) {
    return const <String>{};
  }
  return <String>{itemId};
}

/// 查询式：跑一次定位，把**落点类**命中折算成项集。
///
/// 筛选类（`LocateKind.axis`）不计：它写的是 `axisFilter`、不换根
/// （`VIEW-028`），不是范围。若用户只搜到一个轴值，折算结果为空 —— 此时
/// 上层不该给「按此范围建计划」这个入口，而不是给一个圈出 0 项的计划。
///
/// 域 / 空间命中的折算**不只看命中那一条**：搜「异步」命中一个域，用户要的
/// 是「为这个域建计划」，不是「为这个域这个名字建计划」。
Set<String> _byQuery(LoadedPack pack, String query) {
  final LocateResult result = Locator.single(pack).locate(query);
  final Set<String> keep = <String>{};
  for (final LocateHit hit in result.usableHits) {
    switch (hit.kind) {
      case LocateKind.item:
        keep.add(hit.target);
      case LocateKind.domain:
        keep.addAll(_byDomain(pack, hit.target));
      case LocateKind.space:
        keep.addAll(_allInScope(pack));
      case LocateKind.axis:
        break;
    }
  }
  return keep;
}
