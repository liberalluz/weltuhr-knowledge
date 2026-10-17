/// 图模型 → 场景节点。装配层，**只做取值，不做几何**（几何归 `projection.dart`）。
///
/// 三个坐标的取值口径由 [`ADR-0003`] 定，本文件是它的唯一实现处：
///
/// | 坐标 | 取值 | 依据 |
/// |---|---|---|
/// | `r` | **域带**：`(域序号 + 0.5) / 域数` | `ADR-0003` §决策 1 —— 7 段在 α 包上无对应断点 |
/// | `θ` | **主轴扇区**：`Item.primaryAxis` 缺省继承 `KnowledgeSpace.defaultPrimaryAxis` | §决策 3 修订 —— 150 项全是双轴，推不出主 |
/// | `φ` | `kahnLevels()` 层号 + **该层起始的累计分位** | §决策 4 —— 84% 的项在 `φ ≥ 10`，等距与折叠都不成立 |
///
/// 通道侧：虚实按 `C-34`（不可外化格 ≥ 3），端口不在册的边生成**占位节点**
/// （§决策 5 的黑洞，不新增线型）。
///
/// [ADR-0003]: ../../../../docs/adr/0003-view-radial-axis-and-channel-thresholds.md
library;

import '../constants.dart';
import '../entities/content.dart';
import '../enums.dart';
import '../graph/levels.dart';
import '../pack/pack_parse.dart';
import 'projection.dart';

/// 占位节点 id 的前缀。带边序号，同一空间内唯一 —— 它不在任何 `Item` 册里。
const String placeholderIdPrefix = '__missing__:';

/// 从包构场景节点。顺序与 `pack.items` 一致 —— 边按下标引用，顺序必须稳定；
/// 占位节点统一追加在末尾，不插进 `items` 的区段。
///
/// [sectorCount] 由调用方给（六轴 ⇒ 6），本层不内置默认值。
List<SceneNode> buildSceneNodes(LoadedPack pack, {required int sectorCount}) {
  final Map<String, int> levels = kahnLevels(
    nodeIds: pack.items.map((Item item) => item.id),
    edges: pack.edges,
  );
  final Map<String, int> degrees = _degrees(pack);
  final Map<int, double> phiFractions = _phiFractions(
    pack.items.map((Item item) => levels[item.id] ?? 0),
  );

  final List<String> domains = pack.space.domainIds;
  final Map<String, int> domainIndex = <String, int>{
    for (int i = 0; i < domains.length; i++) domains[i]: i,
  };
  final int domainCount = domains.isEmpty ? 1 : domains.length;

  int maxDegree = 1;
  for (final int value in degrees.values) {
    if (value > maxDegree) {
      maxDegree = value;
    }
  }

  final String? defaultAxis = pack.space.defaultPrimaryAxis;
  final Map<String, List<String>> axisValueOrder = _axisValueOrder(pack.items);
  final List<SceneNode> nodes = <SceneNode>[];
  for (final Item item in pack.items) {
    final int level = levels[item.id] ?? 0;
    final int externalizable = item.requirements.externalizableCount;
    final int sector = _sectorOf(item.primaryAxis ?? defaultAxis, sectorCount);

    nodes.add(
      SceneNode(
        id: item.id,
        radial01:
            ((domainIndex[item.domainId] ?? 0) + radialBandCenterOffset) /
            domainCount,
        sector: sector,
        // 轴内递归区间分割（`VIEW-002`「含轴内递归区间分割」）：扇区内按
        // **该轴取值的出现顺序**分成 `n` 段（`ADR-0003` 修订三）。
        sectorFraction01: _sectorFraction(
          item.primaryAxis ?? defaultAxis,
          item.sixAxis,
          axisValueOrder,
        ),
        phiLevel: level,
        phiFraction01: phiFractions[level] ?? 0,
        size01: (degrees[item.id] ?? 0) / maxDegree,
        brightness01: externalizable == 0
            ? 0
            : item.requirements.completeCount / externalizable,
        dashed: _tacitCells(item) >= tacitMinGrids,
        // 颜色通道与 `θ` 同源：主轴在六轴里的序号。
        colorIndex: sector,
        // 没有事件流输入，轨道环与脉动恒空 —— 填假数据会让帧预算吃到
        // 一份真实运行时不存在的形状。
        ringFill01: 0,
        ringClosed: false,
        pulse: 0,
      ),
    );
  }

  // 端口不在册的边：在源点外侧生成占位节点（`ADR-0003` §决策 5）。
  final Set<String> known = <String>{
    for (final Item item in pack.items) item.id,
  };
  for (int i = 0; i < pack.edges.length; i++) {
    final Edge edge = pack.edges[i];
    final bool fromKnown = known.contains(edge.from);
    final bool toKnown = known.contains(edge.to);
    if (fromKnown == toKnown) {
      continue;
    }
    final String sourceId = fromKnown ? edge.from : edge.to;
    final SceneNode source = nodes.firstWhere(
      (SceneNode node) => node.id == sourceId,
    );
    nodes.add(
      SceneNode(
        id: '$placeholderIdPrefix$i',
        radial01: (source.radial01 + placeholderRadialOffset)
            .clamp(0.0, 1.0)
            .toDouble(),
        sector: source.sector,
        sectorFraction01: source.sectorFraction01,
        phiLevel: source.phiLevel,
        phiFraction01: source.phiFraction01,
        size01: 0,
        brightness01: 0,
        dashed: true,
        colorIndex: source.colorIndex,
        ringFill01: 0,
        ringClosed: false,
        pulse: 0,
        isPlaceholder: true,
      ),
    );
  }

  return nodes;
}

/// 边区间。端点不在 `nodes` 里就跳过（`kahnLevels` 同一口径）——
/// 「指向未知」的那一侧由占位节点接住，因此**有效边数不再减少**。
List<EdgeSpan> buildEdgeSpans(LoadedPack pack, List<SceneNode> nodes) {
  final Map<String, int> indexOf = <String, int>{
    for (int i = 0; i < nodes.length; i++) nodes[i].id: i,
  };
  final List<EdgeSpan> spans = <EdgeSpan>[];
  for (int i = 0; i < pack.edges.length; i++) {
    final Edge edge = pack.edges[i];
    final int? from = indexOf[edge.from];
    final int? to = indexOf[edge.to] ?? indexOf['$placeholderIdPrefix$i'];
    if (from == null || to == null) {
      continue;
    }
    spans.add(
      EdgeSpan(
        fromIndex: from,
        toIndex: to,
        dashed: edge.type != EdgeType.strong,
      ),
    );
  }
  return spans;
}

/// 各轴的**取值出现顺序**。首次出现的次序即内容作者的编排序（`ADR-0003` 修订三）
/// —— 包与清单都只有取值、没有序列，这是唯一既稳定又不必新增 schema 的来源。
Map<String, List<String>> _axisValueOrder(List<Item> items) {
  final Map<String, List<String>> order = <String, List<String>>{};
  for (final Item item in items) {
    for (final String axis in sixAxisKeys) {
      final String? value = item.sixAxis[axis];
      if (value == null) {
        continue;
      }
      final List<String> seen = order.putIfAbsent(axis, () => <String>[]);
      if (!seen.contains(value)) {
        seen.add(value);
      }
    }
  }
  return order;
}

/// 轴内细分位置：该取值在轴上排第几，映射到 `(i + 0.5) / n`。
///
/// 取段中线而不是段端点：端点会压在扇区边界上，相邻两个取值的点看起来像跨了轴。
double _sectorFraction(
  String? axis,
  Map<String, String> sixAxis,
  Map<String, List<String>> order,
) {
  if (axis == null) {
    return 0;
  }
  final List<String>? values = order[axis];
  final String? value = sixAxis[axis];
  if (values == null || value == null || values.isEmpty) {
    return 0;
  }
  final int index = values.indexOf(value);
  if (index < 0) {
    return 0;
  }
  return (index + radialBandCenterOffset) / values.length;
}

/// 主轴 → 扇区序号。未声明时给 `sectorCount`（越界值）：调用方据此画
/// 「未声明」而不是随便塞进某个轴（`ADR-0003` §决策 3 —— 不按优先级猜）。
int _sectorOf(String? axisKey, int sectorCount) {
  if (axisKey == null) {
    return sectorCount;
  }
  final int index = sixAxisKeys.indexOf(axisKey);
  return index < 0 ? sectorCount : index;
}

/// 层号 → 该层**起始的累计分位**（0 = 最前，1 = 末尾）。
///
/// 半径（轴向高度）正比于该层项数 ⇒ 长尾不会把前几层压成一条线。
Map<int, double> _phiFractions(Iterable<int> levels) {
  final List<int> all = levels.toList();
  final Map<int, int> counts = <int, int>{};
  for (final int level in all) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  final List<int> sorted = counts.keys.toList()..sort();
  final Map<int, double> fractions = <int, double>{};
  int seen = 0;
  for (final int level in sorted) {
    fractions[level] = all.isEmpty ? 0 : seen / all.length;
    seen += counts[level] ?? 0;
  }
  return fractions;
}

/// 入度 + 出度。大小通道用它归一（`channel-table.md` 通道 2）。
Map<String, int> _degrees(LoadedPack pack) {
  final Map<String, int> degrees = <String, int>{};
  for (final Edge edge in pack.edges) {
    degrees[edge.from] = (degrees[edge.from] ?? 0) + 1;
    degrees[edge.to] = (degrees[edge.to] ?? 0) + 1;
  }
  return degrees;
}

int _tacitCells(Item item) => item.requirements.states.values
    .where(
      (RequirementState state) => state == RequirementState.notExternalizable,
    )
    .length;
