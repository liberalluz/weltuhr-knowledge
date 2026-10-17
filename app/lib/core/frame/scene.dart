/// 图模型 → 场景节点。**这一层是占位，`B3` 会重写**。
///
/// 为什么仍然放在 `lib/core/` 而不是 bench：bench 与测试都要用它，两处各写一份
/// 就会分叉；而这个映射又是「帧预算的输入口径」，写成一处才说得清本笔测的是
/// 什么分布。
///
/// ## 三处占位（都是本笔撞上的缺口，不是随手取的）
///
/// 1. **`r` 的「复合轴」怎么构造，规格没定。** `VIEW-002` 只说 `r` 是复合轴、
///    7 段径向分层，没说由哪些字段复合。这里用「域序号 + 域内位置」铺开，
///    只为让 150 个点的半径分布有层次；`B3` 定了真构造就替换本函数。
/// 2. **「主取值」在 schema 里没有承载位。** `channel-table.md` 通道 5 写
///    「按 `Item.sixAxis` 主取值着色（声明式指定，不按优先级猜）」，但 `Item`
///    只有六个轴各自的取值，**没有「哪个轴是主」的声明字段**。于是颜色通道
///    与 `θ` 扇区在真实数据上无从取值 —— 这里退回「域序号」占位。
/// 3. **虚实的「高比例」没有阈值。** 通道 4 只说「高比例不可外化」，
///    `constants.md` 里也没有对应 `C-` 项。这里取「多于一格」占位。
///
/// 三处都只影响**分布**，不影响**每项的计算步数**，所以帧预算的结论不受它们
/// 影响 —— 但正式实现前必须逐条定下来，否则渲染出来的是占位语义。
library;

import '../entities/content.dart';
import '../enums.dart';
import '../graph/levels.dart';
import '../pack/pack_parse.dart';
import 'projection.dart';

/// 从包构场景节点。顺序与 `pack.items` 一致 —— 边按下标引用，顺序必须稳定。
///
/// [sectorCount] 由调用方给（六轴 ⇒ 6），本层不内置默认值。
List<SceneNode> buildSceneNodes(LoadedPack pack, {required int sectorCount}) {
  final Map<String, int> levels = kahnLevels(
    nodeIds: pack.items.map((Item item) => item.id),
    edges: pack.edges,
  );
  final Map<String, int> degrees = _degrees(pack);

  final List<String> domains = pack.space.domainIds;
  final Map<String, int> domainIndex = <String, int>{
    for (int i = 0; i < domains.length; i++) domains[i]: i,
  };
  final Map<String, int> domainSize = <String, int>{};
  for (final Item item in pack.items) {
    domainSize[item.domainId] = (domainSize[item.domainId] ?? 0) + 1;
  }
  final Map<String, int> seenInDomain = <String, int>{};
  int maxDegree = 1;
  for (final int value in degrees.values) {
    if (value > maxDegree) {
      maxDegree = value;
    }
  }

  final List<SceneNode> nodes = <SceneNode>[];
  for (final Item item in pack.items) {
    final int index = domainIndex[item.domainId] ?? 0;
    final int slot = seenInDomain[item.domainId] ?? 0;
    seenInDomain[item.domainId] = slot + 1;

    final int size = domainSize[item.domainId] ?? 1;
    final double within = size <= 1 ? 0 : slot / (size - 1);
    final int domainCount = domains.isEmpty ? 1 : domains.length;

    final int externalizable = item.requirements.externalizableCount;
    final double brightness = externalizable == 0
        ? 0
        : item.requirements.completeCount / externalizable;

    nodes.add(
      SceneNode(
        id: item.id,
        radial01: (index + within) / domainCount,
        sector: index % sectorCount,
        sectorFraction01: within,
        phiLevel: levels[item.id] ?? 0,
        size01: (degrees[item.id] ?? 0) / maxDegree,
        brightness01: brightness,
        // 「高比例不可外化」的阈值未裁定（见文件头第 3 条），这里取「多于一格」。
        dashed: _tacitCells(item) > 1,
        colorIndex: index,
        // 没有事件流输入，轨道环与脉动恒空 —— 填假数据会让帧预算吃到
        // 一份真实运行时不存在的形状。
        ringFill01: 0,
        ringClosed: false,
        pulse: 0,
      ),
    );
  }

  return nodes;
}

/// 边区间。端点不在 `nodes` 里就跳过（`kahnLevels` 同一口径）。
List<EdgeSpan> buildEdgeSpans(LoadedPack pack, List<SceneNode> nodes) {
  final Map<String, int> indexOf = <String, int>{
    for (int i = 0; i < nodes.length; i++) nodes[i].id: i,
  };
  final List<EdgeSpan> spans = <EdgeSpan>[];
  for (final Edge edge in pack.edges) {
    final int? from = indexOf[edge.from];
    final int? to = indexOf[edge.to];
    if (from == null || to == null) {
      continue;
    }
    spans.add(
      EdgeSpan(fromIndex: from, toIndex: to, dashed: edge.type != EdgeType.strong),
    );
  }
  return spans;
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
    .where((RequirementState state) => state == RequirementState.notExternalizable)
    .length;
