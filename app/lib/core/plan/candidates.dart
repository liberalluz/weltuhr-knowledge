/// 三段候选的装载与合并（`SPEC-PLAN-006`）。
///
/// ## 三处出处是**机制**对称，不是**数据**齐备
///
/// `SPEC-PLAN-006` 说源 / 体系 / 方法各有三处出处（平台内置 / 空间包默认 / 用户
/// 自建），三线对称。`P-2` 把「对称」落在**合并器**上：三段都走同一个
/// `mergeByOrigin(platform, pack, user)`，优先级 `user > pack > platform`。
/// 至于每一段当下有没有那三份数据，是内容供给问题，不是结构问题：
///
/// | 段 | 平台内置 | 空间包默认 | 用户自建 |
/// |---|---|---|---|
/// | 源 | **空**（`PLAN-006` 注记：平台档无法覆盖任何具体体系） | `excerpts` | `P-8` |
/// | 体系 | **空**（`⪯` 原序的「原序」尚未裁定，不在本笔凭空造） | `schemes` | `P-8` |
/// | 方法 | 三套组合 + 五份分支（`platform_candidates.dart`） | **空**（`PACK` 五段无 `methods`，`SPEC-PACK-006` 明文「第三次扩 schema 应暂停」） | `P-8` |
///
/// ## 源与体系是**双向**收窄，不是单向依赖
///
/// `SPEC-PLAN-014` 原写「源决定体系候选」，`B4` `P-2` 按实证修订为双向：
/// `α` 包 `scheme-first-week`（45 节点）里 `pep-484` 与 `python-asyncio-docs`
/// 覆盖 **0** —— 按「源先定」走，用户选 `pep-484` 之后两套体系会被全部排除；
/// 按「体系先定」走，这两条源被正确筛掉。同一张覆盖矩阵，两个入口。
///
/// 所以装载函数**两个参数都可空**：给 `schemeId` 就收窄源，给 `sourceId` 就收窄
/// 体系，都不给就是空间内全量。
library;

import '../entities/content.dart';
import '../enums.dart';
import '../json.dart';
import '../pack/pack_parse.dart';
import 'method_bundle.dart';
import 'ordering.dart';
import 'platform_candidates.dart';

/// Planner 的三段。声明顺序即左栏排版顺序（`P-4` 定：体系 → 源 → 方法）。
enum PlanSegment { scheme, source, method }

/// 候选的公共读法 —— 卡片形态三段一致（`SPEC-PLAN-008`）。
///
/// 只有「名字 · 出处」是共有的；等级 / 覆盖数 / 类型覆盖三段各不相同，留在各自
/// 子类上。硬把它们提上来会造出一个三段里两端为 `null` 的字段。
abstract class PlanCandidate {
  String get id;
  String get name;
  CandidateOrigin get origin;
}

/// 候选在「当前已选的另一端」下的覆盖读数。
///
/// `covered` / `total` 都是**项数**：`total` = 参照集合大小（体系节点数，或
/// 未选体系时的空间项数），`covered` = 其中与本候选有关联的项数。
class CandidateCoverage {
  const CandidateCoverage({required this.covered, required this.total});

  final int covered;
  final int total;

  /// 覆盖为 0 ⇒ 选中后一条内容也读不到（`P-2` 定：这类候选**不进候选列表**）。
  bool get isUsable => covered > 0;
}

class SourceCandidate implements PlanCandidate {
  const SourceCandidate({
    required this.source,
    required this.coverage,
    required this.origin,
  });

  final SourceRef source;

  /// 覆盖 = 参照集合中 `sourceRefs` 含本源 id 的项数。
  final CandidateCoverage coverage;

  @override
  final CandidateOrigin origin;

  @override
  String get id => source.id;

  @override
  String get name => source.name;

  /// 源自身的版本（如 `3.13`），不是包版本 —— 卡片「版本」一栏显示的是它。
  String get version => source.version;

  /// 出处等级 `L0` / `L1` / `L2` / `L4`：源段唯一的排序键（`SPEC-PLAN-020`）。
  String get authorityLevel => source.authorityLevel;

  /// 「为何推荐」—— 排序键本身就是理由（`SPEC-PLAN-021` 只做 A 级）。
  String get reason => '出处等级 $authorityLevel';
}

class SchemeCandidate implements PlanCandidate {
  const SchemeCandidate({
    required this.scheme,
    required this.coverage,
    required this.origin,
    required this.packVersion,
    required this.orderCost,
  });

  final Scheme scheme;

  /// 仅在给了 `sourceId` 时有值 —— 没给源时「这套体系被某条源覆盖多少」
  /// 无从谈起，给 `null` 比给一个假的分母诚实。
  final CandidateCoverage? coverage;

  @override
  final CandidateOrigin origin;

  /// 包版本：`Scheme` 自身没有版本字段，卡片「版本」一栏取建包版本。
  final String packVersion;

  /// 逆序代价：体系段唯一的排序键（`SPEC-PLAN-020`），同时也是卡片上那行
  /// 「本序 N 处逆序」的来源（`SPEC-PLAN-012`）。
  final SchemeOrderCost orderCost;

  @override
  String get id => scheme.id;

  @override
  String get name => scheme.name;

  /// 出处等级（`L0` / `L1` / `L2` / `L4`），驱动候选卡的等级徽标。
  String get authorityLevel => scheme.authorityLevel;

  String get reason => orderCost.display;
}

class MethodCandidate implements PlanCandidate {
  const MethodCandidate({required this.bundle, required this.typeCoverage});

  final MethodBundle bundle;

  /// 类型覆盖读数：方法段唯一的排序键（`SPEC-PLAN-020`）。
  final TypeCoverage typeCoverage;

  @override
  String get id => bundle.id;

  @override
  String get name => bundle.name;

  @override
  CandidateOrigin get origin => bundle.origin;

  String get reason => typeCoverage.display;
}

class CandidateSet {
  const CandidateSet({
    required this.sources,
    required this.schemes,
    required this.methods,
  });

  /// 三段**都已按各自的键排好序**（`SPEC-PLAN-020`），面板直接按列表顺序渲染。
  ///
  /// 排序只重排、不删（`SPEC-PLAN-013`）：逆序多的体系仍在 `schemes` 里，
  /// 只是靠后。
  final List<SourceCandidate> sources;
  final List<SchemeCandidate> schemes;
  final List<MethodCandidate> methods;

  List<PlanCandidate> of(PlanSegment segment) {
    switch (segment) {
      case PlanSegment.scheme:
        return <PlanCandidate>[...schemes];
      case PlanSegment.source:
        return <PlanCandidate>[...sources];
      case PlanSegment.method:
        return <PlanCandidate>[...methods];
    }
  }
}

// ────────────────────────────── 装载 ──────────────────────────────

/// 一次装载三段候选，**并各自排好序**（`SPEC-PLAN-020` / `021` 的 A 级）。
///
/// [schemeId] 给出时源候选按「覆盖 > 0」收窄；[sourceId] 给出时体系候选按同样
/// 规则收窄。两者可同时给出（重入时预填两支）。
///
/// 用户自建的三份入参在 `P-8` 之前恒为空 —— 但**通道现在就打通**，否则
/// 「优先级 `user > pack > platform`」这条要等到 `P-8` 才第一次被走过，
/// 届时才发现写错就是重做。
CandidateSet loadCandidates(
  LoadedPack pack, {
  String? schemeId,
  String? sourceId,
  List<SourceRef> userSources = const <SourceRef>[],
  List<Scheme> userSchemes = const <Scheme>[],
  List<MethodBundle> userMethodBundles = const <MethodBundle>[],
}) {
  final List<String> nodes = _referenceNodes(pack, schemeId);
  final List<Item> refItems = <Item>[
    for (final String id in nodes)
      if (pack.itemOf(id) != null) pack.itemOf(id)!,
  ];

  return CandidateSet(
    sources: stableSorted<SourceCandidate>(
      _sources(pack, nodes, schemeId != null, userSources),
      (SourceCandidate a, SourceCandidate b) =>
          authorityRank(a.authorityLevel) - authorityRank(b.authorityLevel),
    ),
    schemes: stableSorted<SchemeCandidate>(
      _schemes(pack, sourceId, userSchemes),
      (SchemeCandidate a, SchemeCandidate b) =>
          a.orderCost.inversions - b.orderCost.inversions,
    ),
    methods: stableSorted<MethodCandidate>(
      _methods(refItems, userMethodBundles),
      // 覆盖率高者靠前 ⇒ 反向比较。并列（如都覆盖 4/4）回落到声明顺序。
      (MethodCandidate a, MethodCandidate b) => b.typeCoverage.ratio
          .compareTo(a.typeCoverage.ratio),
    ),
  );
}

/// 参照集合：给了体系就是它的节点，没给就是空间内全部项。
///
/// 体系 id 不存在 ⇒ 抛 [ArgumentError]：那不是「没有候选」，是调用方拿错了 id，
/// 静默返回空列表会让人以为这套体系一条源都不覆盖。
List<String> _referenceNodes(LoadedPack pack, String? schemeId) {
  if (schemeId == null) {
    return <String>[for (final Item item in pack.items) item.id];
  }
  final List<String>? nodes = pack.schemeNodes(schemeId);
  if (nodes == null) {
    throw ArgumentError('不存在的体系 id：`$schemeId`（`pack.schemes` 里没有）');
  }
  return nodes;
}

List<SourceCandidate> _sources(
  LoadedPack pack,
  List<String> nodes,
  bool narrowed,
  List<SourceRef> userSources,
) {
  final List<Origined<SourceRef>> merged = mergeByOrigin<SourceRef>(
    platform: const <SourceRef>[],
    pack: pack.excerpts,
    user: userSources,
    idOf: (SourceRef s) => s.id,
  );

  final List<SourceCandidate> out = <SourceCandidate>[];
  for (final Origined<SourceRef> entry in merged) {
    final SourceRef source = entry.value;
    if (!_spaceAllows(source.appliesTo, pack.space)) {
      continue;
    }
    int covered = 0;
    for (final String nodeId in nodes) {
      final Item? item = pack.itemOf(nodeId);
      if (item != null && item.sourceRefs.contains(source.id)) {
        covered++;
      }
    }
    final CandidateCoverage coverage = CandidateCoverage(
      covered: covered,
      total: nodes.length,
    );
    if (narrowed && !coverage.isUsable) {
      continue;
    }
    out.add(
      SourceCandidate(source: source, coverage: coverage, origin: entry.origin),
    );
  }
  return out;
}

List<SchemeCandidate> _schemes(
  LoadedPack pack,
  String? sourceId,
  List<Scheme> userSchemes,
) {
  final List<Origined<Scheme>> merged = mergeByOrigin<Scheme>(
    platform: const <Scheme>[],
    pack: pack.schemes,
    user: userSchemes,
    idOf: (Scheme s) => s.id,
  );

  final List<SchemeCandidate> out = <SchemeCandidate>[];
  for (final Origined<Scheme> entry in merged) {
    final Scheme scheme = entry.value;
    CandidateCoverage? coverage;
    if (sourceId != null) {
      int covered = 0;
      for (final String nodeId in scheme.nodes) {
        final Item? item = pack.itemOf(nodeId);
        if (item != null && item.sourceRefs.contains(sourceId)) {
          covered++;
        }
      }
      coverage = CandidateCoverage(covered: covered, total: scheme.nodes.length);
      if (!coverage.isUsable) {
        continue;
      }
    }
    out.add(
      SchemeCandidate(
        scheme: scheme,
        coverage: coverage,
        origin: entry.origin,
        packVersion: pack.space.version,
        orderCost: schemeOrderCost(
          scheme: scheme,
          edges: pack.edges,
          itemById: pack.itemById,
        ),
      ),
    );
  }
  return out;
}

/// 方法候选：平台三套组合 + 用户自建（`P-8` 前恒空）。
///
/// 类型覆盖**按参照集合算**，所以「同一套方法在这个体系下覆盖 4/4、在那个体系下
/// 覆盖 2/3」是正常的 —— 排序键就该是当前上下文里的读数。
List<MethodCandidate> _methods(List<Item> refItems, List<MethodBundle> user) {
  final List<Origined<MethodBundle>> merged = mergeByOrigin<MethodBundle>(
    platform: platformMethodBundles,
    pack: const <MethodBundle>[],
    user: user,
    idOf: (MethodBundle b) => b.id,
  );
  return <MethodCandidate>[
    for (final Origined<MethodBundle> entry in merged)
      MethodCandidate(
        bundle: entry.value,
        typeCoverage: methodTypeCoverage(bundle: entry.value, items: refItems),
      ),
  ];
}

/// 源是否属于本空间。**只看 `spaceId`** —— `type` / `layer` / `sixAxis` 在源上
/// 是「这条材料讲什么」的描述，不是准入条件（准入由覆盖决定）。
bool _spaceAllows(JsonMap appliesTo, KnowledgeSpace space) {
  final Object? spaceId = appliesTo['spaceId'];
  return spaceId == null || spaceId == space.id;
}

// ────────────────────────────── 合并 ──────────────────────────────

/// 合并结果的一格：值 + 它来自哪一处出处。
class Origined<T> {
  const Origined({required this.value, required this.origin});

  final T value;
  final CandidateOrigin origin;
}

/// 三源合并，优先级 `user > pack > platform`（`SPEC-PLAN-006`）。
///
/// 顺序：**平台 → 包 → 用户**，同 id 后者覆盖前者但**保留首次出现的位置**。
/// 位置有意义：`P-3` 的排序在 `authorityLevel` / 覆盖数都并列时，最后一级
/// 回落到「包声明顺序」，那正需要这里不重排。
List<Origined<T>> mergeByOrigin<T>({
  required List<T> platform,
  required List<T> pack,
  required List<T> user,
  required String Function(T) idOf,
}) {
  final Map<String, Origined<T>> merged = <String, Origined<T>>{};
  final List<Origined<T>> layers = <Origined<T>>[
    for (final T value in platform)
      Origined<T>(value: value, origin: CandidateOrigin.platform),
    for (final T value in pack)
      Origined<T>(value: value, origin: CandidateOrigin.pack),
    for (final T value in user)
      Origined<T>(value: value, origin: CandidateOrigin.user),
  ];
  for (final Origined<T> entry in layers) {
    merged[idOf(entry.value)] = entry;
  }
  return merged.values.toList(growable: false);
}
