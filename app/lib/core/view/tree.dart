/// 树视图的**行模型**（`SPEC-VIEW-006` / `007` / `008`）。
///
/// 树与宇宙的面包屑**同构**（`VIEW-006` 修订）：四层，深度 0/1/2/3 依次是
/// `知识` / 空间 / 域 / 项。域层不画 `⪯` 边（`VIEW-006` 原始裁定）—— 标准库
/// 在 `⪯` 上依赖语言核心，但树里与它并列；否则整棵树退化成一柱擎天。跨域边
/// 只在宇宙与详情里画。
///
/// ⚠️ **空间层要在树里出多行**（所有空间并列在 `知识` 之下），所以这一层收的
/// 是**一组包**而不是一个：只画当前根的树，深度 2 写着「空间」而实际只有一行，
/// 那与面包屑第 2 段不是同一个东西。
///
/// 四类可见集合（`VIEW-007`）在这里落成 [TreeRowKind]：
/// 圈内项 / 黑洞（有痕迹无实体）/ 圈外邻项 / 轴值分组（仅 `Z0`，已作废）。
library;

import '../constants.dart';
import '../entities/content.dart';
import '../frame/scene.dart';
import '../graph/levels.dart';
import '../ids.dart';
import '../pack/pack_parse.dart';

/// 一棵树只有一个根节点，它的 id 固定 —— 行 key 要唯一，而 `知识` 不对应任何
/// 数据实体（它表示「所有空间」）。
const String treeRootId = 'knowledge';

/// 一行属于哪一类。各层的视觉必须可区分（`SPEC-VIEW-007`）。
enum TreeRowKind {
  /// 第 1 层：`知识`。单行、恒展开、无折叠箭头（`VIEW-006` 修订第 3 条）。
  root,

  /// 第 2 层：空间。名字点了是**换根**（`VIEW-006` 修订第 2 条）。
  space,

  /// 第 3 层：域（对应宇宙的 `Z2`）。可展开。
  domain,

  /// 第 4 层：圈内项。实心、正常行。
  item,

  /// 黑洞：有痕迹无实体。虚线占位，**无展开箭头**。
  blackHole,

  /// 圈外邻项：有实体但不在圈内。虚线支线，只画一层。
  outsideNeighbor,
}

/// 一行。**只带渲染需要的东西**，不带业务判断。
class TreeRow {
  const TreeRow({
    required this.kind,
    required this.id,
    required this.label,
    required this.depth,
    required this.expandable,
    required this.dashed,
    this.expanded = false,
    this.phiLevel = 0,
    this.spaceId,
  });

  final TreeRowKind kind;

  /// 空间 id / 域 id / 项 id / 黑洞的合成 id（`__missing__:<边序>`）。
  final String id;
  final String label;

  /// 0 = `知识`，1 = 空间，2 = 域，3 = 项（含黑洞与圈外邻项）。
  ///
  /// 与面包屑段数一一对应（`VIEW-006` 修订）：`depth + 1` 就是「这一行在
  /// 面包屑上会站第几段」。
  final int depth;

  final bool expandable;
  final bool dashed;

  /// 这一行**当前**是否展开。`root` 恒 `true`。
  ///
  /// 渲染层拿它决定箭头朝向。不放进渲染层自己算：`root` 的「恒展开」是裁定
  /// 而不是状态，两处各写一遍就会有一处在 `知识` 上画出箭头。
  final bool expanded;

  final int phiLevel;

  /// 这一行属于哪个空间。`root` 行为 `null`。
  ///
  /// 域 / 项必须带它：树里能展开**别**的空间，点它的域就得先换根 —— 而域 id
  /// 虽然形如 `python/lexical`，前缀并不可靠（包格式没规定域 id 必须带空间前缀，
  /// 从 id 反解等于把「看起来像」当判据）。
  final String? spaceId;
}

/// 首屏展开到 `φ` 几层：深链空间（`maxφ ≥ C-20`）只到 `C-40`，否则全展。
int initialExpandPhi(int maxPhi) =>
    maxPhi >= deepChainPhi ? treeInitialExpandPhi : maxPhi;

/// 包内每项的 `φ` 层号（`⪯` 上的 Kahn 层号）。
Map<String, int> phiLevelsOf(LoadedPack pack) => kahnLevels(
  nodeIds: pack.items.map((Item item) => item.id),
  edges: pack.edges,
);

/// 包内 `φ` 的最大层号。
///
/// 树视图要它定「首屏展开到第几层」。**不要拿 `SceneBundle.maxPhi` 顶替** ——
/// 那条是场景的层号（含占位节点、按 `SceneNode` 算），口径不同。
int maxPhiOf(LoadedPack pack) {
  int maxPhi = 0;
  for (final int level in phiLevelsOf(pack).values) {
    if (level > maxPhi) {
      maxPhi = level;
    }
  }
  return maxPhi;
}

/// 构树。
///
/// [packs] 是**全部根**（`知识` = 所有空间），顺序即行顺序 —— 换根之后
/// 行序不会跳。
///
/// [spaceId] 是当前根。它管三件事：首屏展开哪一行、筛选作用在哪个包上、
/// 以及渲染层怎么标「我在哪个空间」。
///
/// [expandedSpaces] / [expandedDomains] 里没有的层级节点只出一行。
/// [visibleIds] 来自 ② 的筛选（`SPEC-VIEW-021`），`null` = 不过滤；
/// **只作用于当前根**：别的空间的项没被筛过，拿当前空间的条件去藏它们，
/// 等于替用户判了另一份数据。
/// **黑洞行不参与过滤**：它不是「某一项」，是「这里有个缺口」的结构标记，
/// 被筛掉之后用户就再也看不见缺口的痕迹了；而缺口不属于任何轴的取值。
///
/// 域内排序：「`φ` 升序、同层标题升序」（`B3` 笔 3 的裁定，与宇宙的深度一致，
/// 用户在同一空间里看到的「上下」才是同一个）。
List<TreeRow> buildTree(
  List<LoadedPack> packs, {
  required String? spaceId,
  required Set<String> expandedSpaces,
  required Set<String> expandedDomains,
  Set<String>? visibleIds,
}) {
  final List<TreeRow> rows = <TreeRow>[
    // `知识` 恒展开、无箭头（`VIEW-006` 修订第 3 条）。
    const TreeRow(
      kind: TreeRowKind.root,
      id: treeRootId,
      label: '知识',
      depth: treeDepthRoot,
      expandable: false,
      dashed: false,
      expanded: true,
    ),
  ];

  for (final LoadedPack pack in packs) {
    final String packSpaceId = pack.space.id;
    // 筛选只作用于当前根（见函数注释）。
    final Set<String>? filter = packSpaceId == spaceId ? visibleIds : null;
    final _PackRows built = _packRows(pack, filter: filter);

    final bool spaceExpanded = expandedSpaces.contains(packSpaceId);
    rows.add(
      TreeRow(
        kind: TreeRowKind.space,
        id: packSpaceId,
        label: spaceLabelOf(packSpaceId),
        depth: treeDepthSpace,
        // 箭头判在**筛后**的项数上：筛空的空间还挂着展开箭头，点开什么都没有
        // —— 那正是「假控件」的定义。黑洞也算内容：它有痕迹可看。
        expandable: built.total > 0,
        dashed: false,
        expanded: spaceExpanded,
        spaceId: packSpaceId,
      ),
    );
    if (!spaceExpanded) {
      continue;
    }

    final int expandToPhi = initialExpandPhi(built.maxPhi);
    for (final _DomainRows domain in built.domains) {
      final bool domainExpanded = expandedDomains.contains(domain.id);
      rows.add(
        TreeRow(
          kind: TreeRowKind.domain,
          id: domain.id,
          label: idTail(domain.id),
          depth: treeDepthDomain,
          expandable: domain.itemCount > 0 || domain.holes.isNotEmpty,
          dashed: false,
          expanded: domainExpanded,
          spaceId: packSpaceId,
        ),
      );
      if (!domainExpanded) {
        continue;
      }

      for (final _ItemRow item in domain.items) {
        if (item.phi > expandToPhi) {
          continue;
        }
        rows.add(
          TreeRow(
            kind: item.outside ? TreeRowKind.outsideNeighbor : TreeRowKind.item,
            id: item.id,
            label: item.title,
            depth: treeDepthItem,
            expandable: false,
            dashed: item.outside,
            phiLevel: item.phi,
            spaceId: packSpaceId,
          ),
        );
      }
      for (final _HoleRow hole in domain.holes) {
        rows.add(
          TreeRow(
            kind: TreeRowKind.blackHole,
            id: hole.id,
            label: hole.label,
            depth: treeDepthItem,
            // 黑洞**无展开箭头**（`VIEW-007`）：它没有实体，展开也没有内容。
            expandable: false,
            dashed: true,
            spaceId: packSpaceId,
          ),
        );
      }
    }
  }
  return rows;
}

/// 空间的显示名：`space.id` 首字母大写（`VIEW-036` 的标注口径）。
///
/// 与面包屑同一口径、**同一份实现** —— 同一个空间在树与面包屑里必须同名，
/// 否则「树里看到的深度 = 面包屑段数」这条就只剩深度对得上。
///
/// 不用 `space.name`：三个包的 `name` 是「Python 语法分层 / 英语语法分层 /
/// 德语语法分层」，四段面包屑里再塞这种长度就要换行；而 id 就是包目录名，
/// 用户核对得上的也正是它。
String spaceLabelOf(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// 一个包拆出来的行素材（中间结构，不对外）。
class _PackRows {
  _PackRows({
    required this.domains,
    required this.maxPhi,
    required this.total,
  });

  final List<_DomainRows> domains;
  final int maxPhi;

  /// 展开后会出现的行数（项 + 黑洞），只用于「要不要给箭头」。
  final int total;
}

class _DomainRows {
  _DomainRows({required this.id, required this.items, required this.holes});

  final String id;
  final List<_ItemRow> items;
  final List<_HoleRow> holes;

  int get itemCount => items.length;
}

class _ItemRow {
  const _ItemRow({
    required this.id,
    required this.title,
    required this.phi,
    required this.outside,
  });

  final String id;
  final String title;
  final int phi;

  /// `true` = 圈外邻项（虚线、不进详情）。
  final bool outside;
}

class _HoleRow {
  const _HoleRow({required this.id, required this.label});

  final String id;
  final String label;
}

/// 把**一个包**拆成「域 → 项」两层素材。
///
/// 与 [buildTree] 分开的理由：每层都要先算一次 `φ` 与域分组，写成嵌套循环会
/// 把「包之间」和「包内部」两种遍历糅在一处，读的人分不清哪个变量属于哪一层。
_PackRows _packRows(LoadedPack pack, {Set<String>? filter}) {
  final Map<String, int> levels = phiLevelsOf(pack);

  final Map<String, List<Item>> byDomain = <String, List<Item>>{};
  for (final Item item in pack.items) {
    byDomain.putIfAbsent(item.domainId, () => <Item>[]).add(item);
  }
  for (final List<Item> items in byDomain.values) {
    items.sort((Item a, Item b) {
      final int phiA = levels[a.id] ?? 0;
      final int phiB = levels[b.id] ?? 0;
      return phiA == phiB ? a.title.compareTo(b.title) : phiA.compareTo(phiB);
    });
  }

  // 悬空边按「源点所在域」挂黑洞行（父位取源点质心，`VIEW-007`）。
  final Map<String, String> domainOf = <String, String>{
    for (final Item item in pack.items) item.id: item.domainId,
  };
  final Map<String, List<_HoleRow>> holesByDomain =
      <String, List<_HoleRow>>{};
  for (int i = 0; i < pack.edges.length; i++) {
    final Edge edge = pack.edges[i];
    if (domainOf.containsKey(edge.to) || !domainOf.containsKey(edge.from)) {
      continue;
    }
    final String domain = domainOf[edge.from]!;
    holesByDomain
        .putIfAbsent(domain, () => <_HoleRow>[])
        .add(
          _HoleRow(
            id: '$placeholderIdPrefix$i',
            label: idTail(edge.to),
          ),
        );
  }

  int maxPhi = 0;
  for (final int level in levels.values) {
    if (level > maxPhi) {
      maxPhi = level;
    }
  }

  int total = 0;
  final List<_DomainRows> domains = <_DomainRows>[];
  for (final String domainId in pack.space.domainIds) {
    final List<_ItemRow> items = <_ItemRow>[
      for (final Item item in byDomain[domainId] ?? const <Item>[])
        if (filter == null || filter.contains(item.id))
          _ItemRow(
            id: item.id,
            title: item.title,
            phi: levels[item.id] ?? 0,
            outside: !item.inScope,
          ),
    ];
    final List<_HoleRow> holes =
        holesByDomain[domainId] ?? const <_HoleRow>[];
    total += items.length + holes.length;
    domains.add(
      _DomainRows(id: domainId, items: items, holes: holes),
    );
  }
  return _PackRows(domains: domains, maxPhi: maxPhi, total: total);
}
