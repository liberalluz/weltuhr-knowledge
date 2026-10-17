/// 树视图的**行模型**（`SPEC-VIEW-006` / `007` / `008`）。
///
/// 树只表达**容器层级**：域 → 项。域层不画 `⪯` 边（`VIEW-006`）—— 标准库在
/// `⪯` 上依赖语言核心，但树里与它并列；否则整棵树退化成一柱擎天。
///
/// 四类可见集合（`VIEW-007`）在这里落成 [TreeRowKind]：
/// 圈内项 / 黑洞（有痕迹无实体）/ 圈外邻项 / 轴值分组（仅 `Z0`，本笔不做）。
library;

import '../constants.dart';
import '../entities/content.dart';
import '../frame/scene.dart';
import '../graph/levels.dart';
import '../pack/pack_parse.dart';

/// 一行属于哪一类。四类的视觉必须可区分（`SPEC-VIEW-007`）。
enum TreeRowKind {
  /// 域（树的第一层，`VIEW-006`）。可展开。
  domain,

  /// 圈内项：实心、正常行。
  item,

  /// 黑洞：有痕迹无实体。虚拟线占位，**无展开箭头**。
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
    this.phiLevel = 0,
  });

  final TreeRowKind kind;

  /// 域 id / 项 id / 黑洞的合成 id（`__missing__:<边序>`）。
  final String id;
  final String label;

  /// 0 = 域，1 = 项（含黑洞与圈外邻项）。
  final int depth;
  final bool expandable;
  final bool dashed;
  final int phiLevel;
}

/// 首屏展开到 `φ` 几层：深链空间（`maxφ ≥ C-20`）只到 `C-40`，否则全展。
int initialExpandPhi(int maxPhi) =>
    maxPhi >= deepChainPhi ? treeInitialExpandPhi : maxPhi;

/// 构树。
///
/// [expandedDomains] 里没有的域只出一行（可展开）；有的话按
/// 「`φ` 升序、同层标题升序」列出该域的项（域内排序是 `B3` 笔 3 的裁定，
/// 与宇宙的深度一致，用户在同一空间里看到的「上下」才是同一个）。
List<TreeRow> buildTree(
  LoadedPack pack, {
  required Set<String> expandedDomains,
  required int expandToPhi,
}) {
  final Map<String, int> levels = kahnLevels(
    nodeIds: pack.items.map((Item item) => item.id),
    edges: pack.edges,
  );

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
  final Map<String, List<String>> holesByDomain = <String, List<String>>{};
  for (int i = 0; i < pack.edges.length; i++) {
    final Edge edge = pack.edges[i];
    if (domainOf.containsKey(edge.to) || !domainOf.containsKey(edge.from)) {
      continue;
    }
    final String domain = domainOf[edge.from]!;
    holesByDomain
        .putIfAbsent(domain, () => <String>[])
        .add('$placeholderIdPrefix$i|${_slug(edge.to)}');
  }

  final List<TreeRow> rows = <TreeRow>[];
  for (final String domainId in pack.space.domainIds) {
    final List<Item> items = byDomain[domainId] ?? const <Item>[];
    final List<String> holes = holesByDomain[domainId] ?? const <String>[];
    final bool expandable = items.isNotEmpty || holes.isNotEmpty;

    rows.add(
      TreeRow(
        kind: TreeRowKind.domain,
        id: domainId,
        label: _slug(domainId),
        depth: 0,
        expandable: expandable,
        dashed: false,
      ),
    );
    if (!expandedDomains.contains(domainId)) {
      continue;
    }

    for (final Item item in items) {
      final int phi = levels[item.id] ?? 0;
      if (phi > expandToPhi) {
        continue;
      }
      rows.add(
        TreeRow(
          kind: item.inScope ? TreeRowKind.item : TreeRowKind.outsideNeighbor,
          id: item.id,
          label: item.title,
          depth: 1,
          expandable: false,
          dashed: !item.inScope,
          phiLevel: phi,
        ),
      );
    }
    for (final String hole in holes) {
      final List<String> parts = hole.split('|');
      rows.add(
        TreeRow(
          kind: TreeRowKind.blackHole,
          id: parts.first,
          label: parts.length > 1 ? parts[1] : '',
          depth: 1,
          // 黑洞**无展开箭头**（`VIEW-007`）：它没有实体，展开也没有内容。
          expandable: false,
          dashed: true,
        ),
      );
    }
  }
  return rows;
}

/// 末段 id：`python/lexical` → `lexical`。
String _slug(String id) {
  final int slash = id.lastIndexOf('/');
  return slash < 0 ? id : id.substring(slash + 1);
}
