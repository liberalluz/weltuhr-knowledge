/// 跨包地形图 —— 把若干已解析的包的先修边合成一张图（`B15` 笔 3）。
///
/// ## 为什么需要它
///
/// `ADR-0005` 决策 4 把先修边独立成 `terrain` 包、且跨轴，于是
/// `A 包的 i → B 包的 j` 与 `B 包的 j → A 包的 i` 可以同时成立。而
/// `pack_reader` 的环检测**只看单个包** —— 从任何一个包的视角看，这两条都只是
/// 普通边，两边都判不出问题。跨包环因此没有任何一处会报，后果却与包内环相同：
/// `φ` 是 `⪯` 上的 Kahn 层号，有环就取不出层号，整个宇宙的径向坐标直接塌掉。
///
/// 本类只做「合成」这一件事，判不判环由调用方定 —— 装载层在装 `terrain` 包前
/// 拿它判一次（`PackLoader.install`），构建期工具将来可以拿它判整包集合。
///
/// ## 与 `precedence.dart` 的分工
///
/// 「哪些边参与 `⪯`」仍只有 `requiredEdgesOf` 一处定义，本类**委托**它，不另写
/// 一遍 `strength == required` 过滤（`B15` 出口判据「全项目只有一套偏序源」）。
///
/// 环检测走 `findCyclesFrom`，输入是 [edges]（**两类强度都在**）：拿
/// [requiredEdges] 去判环，`recommended` 成环就再也报不出来 —— 那不是收紧判据，
/// 是把判据删掉一半（`B15` 出口判据「环检测覆盖两类边」）。
///
/// ## `V1` 不物化闭包
///
/// 本类只持有**边**，不持有任何传递闭包矩阵；前置集合每次现算。加一份缓存就是
/// 第二份事实，而它与边集不同步的唯一表现是「算错」—— 没有断言会红
/// （`entity-fields` §5 末句）。
///
/// ## 为什么放在 `core/graph/` 却 import 包层类型
///
/// 它读的是 `PackContent`，产出的却是图，所以放在图这一侧 —— 同一层里
/// `levels.dart` 早就这么做了（它同样 import `pack_reader`）。`cycle_check.dart`
/// 仍在 `core/pack/`：它是纯算法（只吃端点对、不 import 任何包类型），位置只是
/// 历史 —— 诞生时唯一的调用方是 `pack_reader`。本笔不搬它，搬动会让一笔改动
/// 同时落在「加能力」与「挪文件」两件事上。
library;

import '../entities/edge.dart';
import '../pack/cycle_check.dart';
import '../pack/pack_reader.dart';
import 'precedence.dart' as precedence;

/// 若干包的先修边合成的一张图。
class TerrainGraph {
  TerrainGraph._(this.edges);

  /// 把若干已解析的包合成一张图。
  ///
  /// **边的顺序 = 入参顺序、包内顺序**。同一份输入每次给出同一个序列 ——
  /// 顺序不是语义（集合就是集合），但两次算出不同顺序会让比对与排错无从下手。
  factory TerrainGraph.of(Iterable<PackContent> packs) {
    final List<PrerequisiteEdge> edges = <PrerequisiteEdge>[];
    for (final PackContent pack in packs) {
      edges.addAll(pack.prerequisites);
    }
    return TerrainGraph._(List<PrerequisiteEdge>.unmodifiable(edges));
  }

  /// 全部先修边，**两类强度都在**。环检测要用这个全集。
  final List<PrerequisiteEdge> edges;

  /// 参与 `⪯` 的那些边。委托 `precedence.requiredEdgesOf`，不在这里重写过滤。
  Iterable<PrerequisiteEdge> get requiredEdges =>
      precedence.requiredEdgesOf(edges);

  /// 某节点**跨包**的 `required` 前置（传递闭包，不含自身）。
  ///
  /// 端点可以落在不同的包里 —— 这正是本类存在的意义：`plan` 侧要判「这一项还差
  /// 什么」时，先修边可能来自一个与它不同包的 `terrain` 包。
  List<String> requiredPredecessorsOf(String nodeId) =>
      precedence.requiredPredecessorsOf(nodeId: nodeId, edges: edges);

  /// 全部**基本环**，每条首尾为同一 id（`[a, b, a]`）。
  ///
  /// 端点跨包时同样成立 —— `pack_reader` 的单包视角看不到这种环。
  List<List<String>> get cycles => findCyclesFrom(<({String from, String to})>[
    for (final PrerequisiteEdge edge in edges)
      (from: edge.fromId, to: edge.toId),
  ]);
}
