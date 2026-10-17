/// 场景装配的两条路：真实 α 包 / 合成重建。
///
/// 这一层是 spike 的**数据侧**，`B3` 会把它换掉 —— 它存在的唯一理由是让
/// 「帧率实测」能在两种输入上各跑一遍：
///
/// - **真实 α 包**：数据 100% 真实，评审时没人能质疑「是不是你造的形状」。
/// - **合成重建**：按 α 包实测形状（150 项 / 167 有效边 / `φ` 最大 63 /
///   7 环 6 扇区）重建。**×2 档只能靠它** —— 真包只有 150 项，要测 300 项
///   就得复制节点并重映射边，那本来就是合成。
///
/// 两路同规模对比是这一笔的**校准**：若 fps 接近，合成形状可信、×2 可外推；
/// 若差得远，说明成本主要由像素覆盖而非调用数决定，×2 的数字不能线性外推。
/// 这个结论比任何一个 fps 值都重要。
///
/// ## 为什么真实包这一路要带回落
///
/// `PackLoader` 按**运行期 CWD** 找 `<仓根>/content/<空间>/dist/pack.json`，
/// 而 `dist/` 不入库（`SPEC-PACK-018`）。任一处不对，spike 会画出一片空白，
/// 而空白帧的 fps 一律很好看 —— 那是这个测量最坏的失败形态：**看起来通过**。
/// 所以探测不到就回落合成，并在屏幕上把原因写出来。
library;

import '../../core/entities/content.dart';
import '../../core/frame/projection.dart';
import '../../core/frame/scene.dart';
import '../../core/pack/dart_io_pack_fs.dart';
import '../../core/pack/pack_fs.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/pack/pack_probe.dart';

/// 六轴 ⇒ 扇区数。`scene.dart` 要求调用方给，本层不内置默认值。
const int spikeSectorCount = 6;

/// α 包的目录名（`content/python`）。换包只改这一处。
const String _alphaSpaceDir = '/python';

/// 场景从哪来 —— 必须显示在屏幕上，否则读到的 fps 不知道在说哪一份数据。
enum SceneOrigin {
  alphaPack('真实 α 包'),
  synthetic('合成 ×1'),
  syntheticDoubled('合成 ×2');

  const SceneOrigin(this.label);

  final String label;
}

/// 一份可以直接交给投影层的场景。
class SceneBundle {
  SceneBundle({
    required this.origin,
    required this.nodes,
    required this.edges,
    required this.notes,
    this.radialSegments = 7,
  }) : maxPhi = _maxPhiOf(nodes);

  final SceneOrigin origin;
  final List<SceneNode> nodes;
  final List<EdgeSpan> edges;

  /// 装配过程中值得写在屏幕上的事（回落原因、与真实包的偏差）。
  final List<String> notes;

  /// `φ` 最大层号。
  final int maxPhi;

  /// 径向段数 = **域数**（`ADR-0003` §决策 1）。合成场景按 7 段建，故默认 7；
  /// 真实包由 `resolveAlphaScene` 传 `domainIds.length`。
  final int radialSegments;

  int get itemCount => nodes.length;
  int get edgeCount => edges.length;
}

/// 一次装配的结果。`bundle` 恒有值（真实包失败就回落合成）。
class SceneResolution {
  const SceneResolution({required this.bundle, this.pack, this.fallbackReason});

  final SceneBundle bundle;

  /// 真实包的 `LoadedPack`。**合成回落的路径没有它** —— 合成节点是凭空造的
  /// 编号（`s0…s149`），背后没有 `Item`，所以树视图与详情都**无从谈起**。
  /// 这一层只如实转达「有没有包」，由界面决定降级成什么样。
  final LoadedPack? pack;

  /// 非 `null` 表示走的是回落路径，内容是原因。
  final String? fallbackReason;

  bool get fellBack => fallbackReason != null;
}

/// 装真实 α 包；探测不到 / 解析失败 / 一个节点都没有 ⇒ 回落合成。
///
/// 不抛异常：spike 的目的不是测错误处理，中途崩掉比回落更没有信息量。
///
/// **只装一个空间**，供绘制 spike（`universe_spike_screen`）复用 —— 那里测的是
/// 「同一份输入下的帧成本」，多根没有意义。产品界面的入口是 [resolveAllScenes]。
SceneResolution resolveAlphaScene() {
  const PackFs fs = DartIoPackFs();
  final ProbeResult probe = const PackProbe(fs).scanRoots(devPackRoots());

  if (probe.isEmpty) {
    return _fallback(_probeFailure(probe));
  }

  PackLocation? chosen;
  for (final PackLocation location in probe.locations) {
    if (location.spaceRoot.endsWith(_alphaSpaceDir)) {
      chosen = location;
      break;
    }
  }
  chosen ??= probe.locations.first;

  final SceneResolution? resolution = bundleFromPack(fs, chosen);
  return resolution ?? _fallback('包解析成功但一个节点都没有：${chosen.spaceRoot}');
}

/// **全部**可渲染的空间，每个一份装配结果（`SPEC-VIEW-031` 的多根入口）。
///
/// 为什么产品界面要一次装全部，而不是「先装一个、换根时再装」：换根发生在点击
/// 的那一帧里，那时不能有 IO。一次装完的代价是内存，而这是单机、书只有几本。
///
/// 顺序按 `KnowledgeSpace.order`（`Z0` 的排序字段），`id` 收尾保证两次启动
/// 顺序一致 —— 不一致的话「第 i 个根」在两次运行里会指到不同的空间。
///
/// 一个包都没有时给一份合成回落，**仍然返回非空列表**：界面永远有一个根可画，
/// 空列表会让「没有内容包」这件事变成空白窗口，而不是一句写清原因的降级。
List<SceneResolution> resolveAllScenes() {
  const PackFs fs = DartIoPackFs();
  final ProbeResult probe = const PackProbe(fs).scanRoots(devPackRoots());

  if (probe.isEmpty) {
    return <SceneResolution>[_fallback(_probeFailure(probe))];
  }

  final List<SceneResolution> resolved = <SceneResolution>[];
  for (final PackLocation location in probe.locations) {
    final SceneResolution? resolution = bundleFromPack(fs, location);
    if (resolution != null) {
      resolved.add(resolution);
    }
  }
  if (resolved.isEmpty) {
    return <SceneResolution>[
      _fallback('探测到 ${probe.locations.length} 个包目录，但没有一个装得出来'),
    ];
  }
  resolved.sort((SceneResolution a, SceneResolution b) {
    final KnowledgeSpace left = a.pack!.space;
    final KnowledgeSpace right = b.pack!.space;
    return left.order == right.order
        ? left.id.compareTo(right.id)
        : left.order.compareTo(right.order);
  });
  return resolved;
}

/// 从磁盘上的一个包目录装出一份场景。失败（读不出 / 解析错 / 零节点）给 `null`。
///
/// 抽出来是因为「首次装配」与「换根」必须是**同一个函数**：两处各写一遍，
/// 换根之后画出来的东西就不是首帧那个函数的结果，而形状一旦不同，用户会以为
/// 自己进错了空间（`R-08` 同族 —— 违反它不会有任何东西变红）。
SceneResolution? bundleFromPack(PackFs fs, PackLocation location) {
  final String? manifest = fs.readString(location.manifestPath);
  final String? body = fs.readString(location.packPath);
  if (manifest == null || body == null) {
    return null;
  }

  final LoadedPack pack;
  try {
    pack = parsePack(manifestJson: manifest, packJson: body);
  } on PackFormatException {
    // 解析失败的原因由调用方决定怎么说：单根路径写进 `fallbackReason`，
    // 多根路径直接丢掉这个空间（它画不出来，给不出根）。
    return null;
  }

  final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: spikeSectorCount);
  if (nodes.isEmpty) {
    return null;
  }
  final List<EdgeSpan> edges = buildEdgeSpans(pack, nodes);

  return SceneResolution(
    pack: pack,
    bundle: SceneBundle(
      origin: SceneOrigin.alphaPack,
      nodes: nodes,
      edges: edges,
      radialSegments: pack.space.domainIds.length,
      notes: <String>[
        '空间 ${pack.space.id} v${pack.space.version}',
        '${location.spaceRoot.split('/').last}/dist/pack.json',
        '边 ${pack.edges.length} 条 → 有效 ${edges.length} 条'
            '（${pack.edges.length - edges.length} 条端点不在册，投影时跳过）',
      ],
    ),
  );
}

/// 探测失败的说明。「探测不到」与「探测到但有问题」是两件事，两者都要说出来。
String _probeFailure(ProbeResult probe) =>
    '探测不到内容包（候选根 ${devPackRoots().join(" · ")}）'
    '${probe.problems.isEmpty ? "" : "，问题 ${probe.problems.join("; ")}"}';

SceneResolution _fallback(String reason) {
  return SceneResolution(bundle: buildSyntheticScene(), fallbackReason: reason);
}

/// α 包的实测口径（`B2` 第 4 笔量到的，不是随手取的）。
const int _alphaItems = 150;
const int _alphaDanglingEdges = 3;

/// 真包 170 条边里 3 条端点不在册 ⇒ 有效 167 条。合成按**有效**数量建。
const int _alphaValidEdges = 170 - _alphaDanglingEdges;

/// `φ` 最大层号。
const int _alphaMaxPhi = 63;

/// 0 层（无前置）的项数 —— α 包的 `⪯` 近乎一条长链，只 3 项在根上。
const int _alphaRootItems = 3;

/// 非根项铺满 `1…63` 时的分母。
const int _alphaPhiSpan = _alphaItems - _alphaRootItems - 1;

/// 链之外的跨接边数（补到 167 条）。
const int _syntheticCrossingEdges = _alphaValidEdges - (_alphaItems - 1);

/// `VIEW-002`：`r` 是 7 段径向分层。
const int _alphaRadialSegments = 7;

/// 合成份数上限，防止误触把内存吃满。
const int _maxCopies = 4;

/// 按 α 包实测形状重建一份场景。
///
/// [copies] 为 1 给 150 项 / 167 边，为 2 给 300 项 / 334 边（第二份的 id
/// 加 `#2`、边索引整体偏移）。
///
/// **形状是近似，不是复制**：真实的逐项 `φ` 分布、域归属与边拓扑不可知
/// （`buildSceneNodes` 里有三处占位，那几个字段本身就没有承载位）。
/// 这里只对齐会让成本变化的量：项数、边数、层号跨度、环与扇区的铺开程度。
SceneBundle buildSyntheticScene({int copies = 1}) {
  final int round = copies.clamp(1, _maxCopies);

  final List<SceneNode> nodes = <SceneNode>[];
  final List<EdgeSpan> edges = <EdgeSpan>[];

  for (int copy = 0; copy < round; copy++) {
    final int base = nodes.length;
    final String suffix = copy == 0 ? '' : '#${copy + 1}';

    for (int i = 0; i < _alphaItems; i++) {
      final int band = i % _alphaRadialSegments;
      nodes.add(
        SceneNode(
          id: 's$i$suffix',
          radial01: (band + 0.5) / _alphaRadialSegments,
          sector: i % spikeSectorCount,
          sectorFraction01: (i % _alphaRadialSegments) / _alphaRadialSegments,
          phiLevel: _syntheticPhi(i),
          size01: _noise(i, 1),
          brightness01: _noise(i, 2),
          // 「高比例不可外化」的阈值未裁定（`scene.dart` 文件头第 3 条）。
          dashed: _noise(i, 3) > 0.62,
          colorIndex: i % spikeSectorCount,
          // 无事件流输入 ⇒ 轨道环与脉动恒空，与真实首启一致。
          ringFill01: 0,
          ringClosed: false,
          pulse: 0,
        ),
      );
    }

    // 链：i → i+1（149 条）—— α 包的 `⪯` 近乎一条长链，这一条占大头。
    for (int i = 0; i + 1 < _alphaItems; i++) {
      edges.add(
        EdgeSpan(fromIndex: base + i, toIndex: base + i + 1, dashed: i.isOdd),
      );
    }
    // 跨接：补到 167 条，让图不是纯链（纯链的边全落在同一环带里，覆盖偏低）。
    for (int i = 0; i < _syntheticCrossingEdges; i++) {
      final int from = (i * 11 + 5) % _alphaItems;
      final int to = (from + 37) % _alphaItems;
      edges.add(EdgeSpan(fromIndex: base + from, toIndex: base + to, dashed: i % 3 != 0));
    }
  }

  return SceneBundle(
    origin: round == 1 ? SceneOrigin.synthetic : SceneOrigin.syntheticDoubled,
    nodes: nodes,
    edges: edges,
    notes: <String>[
      '合成重建：$round × ($_alphaItems 项 / $_alphaValidEdges 边)',
      'φ 取 0…$_alphaMaxPhi，0 层 $_alphaRootItems 项',
      '形状为近似 —— 逐项 φ 分布与边拓扑属 B3 的三处待定',
    ],
  );
}

/// 层号：前 3 项在 0 层，其余铺到 1…63。
int _syntheticPhi(int index) {
  if (index < _alphaRootItems) {
    return 0;
  }
  return 1 + ((index - _alphaRootItems) * (_alphaMaxPhi - 1)) ~/ _alphaPhiSpan;
}

/// 确定性伪随机：同一 [index] / [salt] 每次得到同一个值。
///
/// 用随机数会让两次启动画出不同形状，两次读数就没法比 ——
/// 而这一笔的全部价值在于「同一份输入下的数可复现」。
double _noise(int index, int salt) {
  final int hash = (index * 1103515245 + salt * 12345) & 0x7fffffff;
  return (hash % 1000) / 1000;
}

int _maxPhiOf(List<SceneNode> nodes) {
  int maxPhi = 0;
  for (final SceneNode node in nodes) {
    if (node.phiLevel > maxPhi) {
      maxPhi = node.phiLevel;
    }
  }
  return maxPhi;
}
