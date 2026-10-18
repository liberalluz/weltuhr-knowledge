/// `Z1` 星系盘的几何 —— **一个 `KnowledgeSpace` 一张盘**（`SPEC-VIEW-037`）。
///
/// ## 为什么也要单独一层
///
/// `Z0` 单独一层是因为它「无项无边」（见 `galaxy_map.dart`）。`Z1` 有项，看起来
/// 该走 `FramePainter` —— 但它要的是**盘面**：核球 + 两条旋臂 + 域点，且倾角
/// 插值到 0（正对盘面，`C-59`）。走那套投影得到的是「极坐标环带 + 24° 侧视」，
/// 十圈同心环挤在同一条扇区里 ⇒ 屏幕上是一条竖列，域与域分不开（`ADR-0003`
/// 2026-10-18 修订 §1 记的就是这件事）。
///
/// 所以 `Z1` 自带一套几何。**项在这一档只是背景**（`VIEW-037`）：它们参与绘制、
/// 不参与拾取，位置也不再承载 `θ` —— 那是 `Z2` 起的事。
///
/// ## 弧长：这一步把「分位」落到实处
///
/// 对数螺线 `r(θ) = r₀·e^(bθ)`、`b = tan(螺距)`（`C-58`）的弧长有闭式解：
/// `ds/dθ = r·√(1+b²)` ⇒ `s(θ) = √(1+b²)·(r − r₀)/b`。**弧长与半径差成正比**，
/// 于是「按弧长等分」等价于「按半径等分」—— 不需要数值积分，也不需要查表：
///
/// > 分位 `f` 处的半径 `r = r₀ + f·(rMax − r₀)`，角度 `θ = ln(r/r₀)/b`。
///
/// 域 `i` 的落点仍取 `(i + 0.5) / n`（`C-30` 的公式一字未动，`ADR-0003` 修订
/// §3 明写「不得借这个改动给 `r` 加新含义」）。两条臂各一个点，关于核球对称。
///
/// ## 确定性
///
/// 起始角、项的点内偏移、暗斑的横向抖动全部由 `space.id` / `Item.id` 的
/// FNV-1a 定（复用 `galaxy_map.dart` 的 `galaxyHash01`）—— 不用 `Random`：
/// 随机数会让同一个空间每次打开都换一副样子。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/graph/subtrees.dart';
import '../../core/ids.dart';
import '../../core/pack/pack_parse.dart';
import 'galaxy_map.dart' show accentArgbOf, galaxyHash01;

/// 盘半径占视口短边的比例。留白是为了域点标注不被边缘切掉。
///
/// 与 `C-52`（`Z0` 的分布半径）分开写：两个数管的是不同的东西 —— 那个是
/// 「星系摆多开」，这个是「盘铺多大」，合成一个常数会让改其中一个时误伤另一个。
const double _discRadiusRatio = 0.42;

/// 旋臂折线的采样数（两条臂各一份）。96 段在 1080p 下一个像素级拐点都看不出来，
/// 而成本是 96 次三角 —— 与项数无关。
const int _armSamples = 96;

/// 一条旋臂在屏幕上的折线，从核球边缘一直甩到盘缘。
typedef SpiralArm = List<Offset>;

/// 一个域的落点（`VIEW-037`：域点落 = 该域弧段的中点，**两条臂各一个**）。
class DomainMark {
  const DomainMark({
    required this.domainId,
    required this.label,
    required this.itemCount,
    required this.systemCount,
    required this.points,
  });

  final String domainId;

  /// 显示名 = `domainId` 的末段（`python/lexical` → `lexical`）。
  ///
  /// 取末段而不是整串：面包屑里写全串是因为那里只有一段，盘面上十个全串
  /// 会互相压住；而 `lexical` / `data-model` 已经能把十个域分开。
  final String label;

  final int itemCount;

  /// 恒星系数 = 域内 `⪯` 子树的根数（`VIEW-037` 的暗斑数量判据）。
  final int systemCount;

  /// 两个落点：`[0]` 在第一条臂，`[1]` 在第二条臂。**顺序固定**，测试按位取。
  final List<Offset> points;

  Offset get primary => points.first;
}

/// 一次 `Z1` 布局的结果。
class SpiralLayout {
  const SpiralLayout({
    required this.center,
    required this.bulgeRadius,
    required this.discRadius,
    required this.accentArgb,
    required this.arms,
    required this.marks,
    required this.items,
    required this.blobs,
  });

  /// 空盘：没有包、或视口还没量出来。界面据此退回项场景（诊断路径）。
  static const SpiralLayout empty = SpiralLayout(
    center: Offset.zero,
    bulgeRadius: 0,
    discRadius: 0,
    accentArgb: 0xFF6E63D8,
    arms: <SpiralArm>[],
    marks: <DomainMark>[],
    items: <Offset>[],
    blobs: <Offset>[],
  );

  final Offset center;

  /// 核球半径（px）。
  final double bulgeRadius;

  /// 盘缘半径（px）。
  final double discRadius;

  final int accentArgb;

  /// 两条臂的折线（各 `_armSamples` 个点）。
  final List<SpiralArm> arms;

  /// 域点，按 `domainIds` 顺序。
  final List<DomainMark> marks;

  /// 项的位置 —— **背景**，不参与拾取（`VIEW-037`）。
  final List<Offset> items;

  /// 恒星系暗斑 —— 数量 = 域内 `⪯` 子树根数之和，**不为好看凑数**。
  final List<Offset> blobs;

  bool get isEmpty => arms.isEmpty && marks.isEmpty;

  DomainMark? markOf(String domainId) {
    for (final DomainMark mark in marks) {
      if (mark.domainId == domainId) {
        return mark;
      }
    }
    return null;
  }
}

/// 按包与视口算出 `Z1` 的盘面。
///
/// [visibleIds] 是筛选结果（`null` = 不筛）。它只影响**背景项**：域点与核球
/// 永远是全部 —— 筛的是项，不是把域筛掉；一个域被筛空仍要看得见它在哪，
/// 否则用户会以为「这个域没了」。
///
/// 空包（无项、无域）返回 [SpiralLayout.empty]：画一个没有内容的盘等于
/// 「这个空间有东西」，而它没有（`SPEC-FND-014` 未声明即不渲染）。
SpiralLayout layoutSpiral({
  required LoadedPack pack,
  required Size viewport,
  Set<String>? visibleIds,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return SpiralLayout.empty;
  }
  final List<String> domains = pack.space.domainIds;
  if (domains.isEmpty) {
    return SpiralLayout.empty;
  }

  final Offset center = Offset(viewport.width / 2, viewport.height / 2);
  final double discRadius =
      math.min(viewport.width, viewport.height) / 2 * _discRadiusRatio;
  if (discRadius <= 0) {
    return SpiralLayout.empty;
  }
  final double bulgeRadius = discRadius * galaxyBulgeRadiusRatio;

  // `b = tan(螺距)`（`C-58` 的勘误见 `constants.md`）。`r₀` 取核球半径 ——
  // 旋臂从核球边缘起，不从圆心起：从圆心起的臂会在中心叠成一个亮点，
  // 而那正是核球该在的位置。
  final double b = math.tan(spiralPitchDeg * math.pi / 180);
  final double span = discRadius - bulgeRadius;

  /// 弧长分位 → 屏幕点。`f = 0` 在核球边缘，`f = 1` 在盘缘。
  Offset pointAt(double f, double startAngle) {
    final double r = bulgeRadius + f * span;
    final double theta = math.log(r / bulgeRadius) / b;
    final double angle = startAngle + theta;
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  }

  // 起始角由空间 id 定：换一个空间换一股票旋臂朝向，而同一个空间每次打开
  // 朝向相同。留白足够时，朝向不影响任何判据。
  final double startAngle =
      galaxyHash01('${pack.space.id}:arm') * fullTurnRadians;

  final List<SpiralArm> arms = <SpiralArm>[
    for (int arm = 0; arm < spiralArmCount; arm++)
      <Offset>[
        for (int i = 0; i <= _armSamples; i++)
          pointAt(i / _armSamples, startAngle + arm * math.pi),
      ],
  ];

  // 域 → 项。顺序按 `domainIds`，项按其在包里的出现顺序 —— 与
  // `buildSceneNodes` 同一口径（两处排序不同会让「第 i 项」指到别的项）。
  final Map<String, List<Item>> byDomain = <String, List<Item>>{
    for (final String id in domains) id: <Item>[],
  };
  for (final Item item in pack.items) {
    byDomain[item.domainId]?.add(item);
  }

  // 域内 `⪯` 子树在 `Z2` 也要用（亮结，`VIEW-038`）⇒ 划分只有一份实现
  // （`core/graph/subtrees.dart`）。两处各写一遍的话「暗斑数 ≠ 亮结数」不会有
  // 任何东西变红，而它们本来就是同一个数的两个尺度。
  final int domainCount = domains.length;
  final List<DomainMark> marks = <DomainMark>[];
  final List<Offset> items = <Offset>[];
  final List<Offset> blobs = <Offset>[];

  for (int i = 0; i < domainCount; i++) {
    final String domainId = domains[i];
    final List<Item> inDomain = byDomain[domainId] ?? const <Item>[];
    final List<PrereqSubtree> subtrees = subtreesInDomain(
      items: inDomain,
      edges: pack.edges,
    );
    final double base = i / domainCount;
    final double step = 1 / domainCount;

    // 域点：取该段弧的中点（`(i + 0.5) / n`）。
    final double mid = base + step / 2;
    marks.add(
      DomainMark(
        domainId: domainId,
        label: domainLabel(domainId),
        itemCount: inDomain.length,
        systemCount: subtrees.length,
        points: <Offset>[
          pointAt(mid, startAngle),
          pointAt(mid, startAngle + math.pi),
        ],
      ),
    );

    // 项：落本域弧段内，按出现顺序铺开 —— 顺序只是「别叠在一个点上」，
    // 不承载任何语义（这一档的项是背景，`VIEW-037`）。
    for (int j = 0; j < inDomain.length; j++) {
      final Item item = inDomain[j];
      // 位置按**全量**下标算，筛掉谁都不挪动其余项 —— 否则一勾筛选整盘
      // 重新洗牌，看起来像换了个空间。
      //
      // `0.15 .. 0.85` 而不是 `0 .. 1`：贴到段边界会与相邻域的项混在一起，
      // 而「这项属于哪个域」是这一档唯一还看得出来的一件事。
      final double within = inDomain.length == 1
          ? 0.5
          : 0.15 + 0.7 * j / (inDomain.length - 1);
      if (visibleIds != null && !visibleIds.contains(item.id)) {
        continue;
      }
      // 径向抖动按 id 哈希，幅度只够打散一排整齐的点阵。
      final double jitter = (galaxyHash01('${item.id}:jit') - 0.5) * 0.06;
      // 两条臂交替：盘是对称的，全堆在一条臂上会像「甩出去的一串」。
      final int arm = galaxyHash01('${item.id}:arm') < 0.5 ? 0 : 1;
      items.add(
        pointAt(
          (base + within * step + jitter * step).clamp(0.0, 1.0),
          startAngle + arm * math.pi,
        ),
      );
    }

    // 恒星系暗斑：一个子树根一个。链状数据下每域 1 个，**不凑数**。
    for (final PrereqSubtree subtree in subtrees) {
      final int index = inDomain.indexWhere(
        (Item item) => item.id == subtree.rootId,
      );
      if (index < 0) {
        continue;
      }
      final double within = inDomain.length == 1
          ? 0.5
          : 0.15 + 0.7 * index / (inDomain.length - 1);
      final int arm = galaxyHash01('${subtree.rootId}:arm') < 0.5 ? 0 : 1;
      blobs.add(pointAt(base + within * step, startAngle + arm * math.pi));
    }
  }

  return SpiralLayout(
    center: center,
    bulgeRadius: bulgeRadius,
    discRadius: discRadius,
    accentArgb: accentArgbOf(pack.space.accent),
    arms: arms,
    marks: marks,
    items: items,
    blobs: blobs,
  );
}

/// 域内 `⪯` 子树的根：没有任何**同域**前置的项。顺序保持包内出现顺序。
///
/// ⚠️ 实现在 `core/graph/subtrees.dart`：`Z2` 的亮结用的是同一份划分，
/// 两处各写一遍迟早不一致（`VIEW-037` 的暗斑数与 `VIEW-038` 的亮结数
/// 是同一个数的两个尺度）。

/// 点 [point] 命中的域。`null` = 点空了（**项不在射程内**，`VIEW-037`）。
///
/// 命中半径取 `domainMarkMinTapDiameter / 2`：域点本身只画 4 px，直接按图形
/// 判会「看得见点不中」。两个等价落点里取更近的那个（`VIEW-014` 修订三）。
String? pickSpiralDomainAt({
  required SpiralLayout layout,
  required Offset point,
}) {
  const double radius = domainMarkMinTapDiameter / 2;
  String? bestId;
  double bestDistance = radius;
  for (final DomainMark mark in layout.marks) {
    for (final Offset candidate in mark.points) {
      final double distance = (candidate - point).distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        bestId = mark.domainId;
      }
    }
  }
  return bestId;
}

/// 域的显示名：`domainId` 的末段。`python/lexical` → `lexical`。
///
/// 转调 `core/ids.dart` 的 `idTail` —— 详情页的 `domainLabel`
/// （`core/view/detail.dart`）用的也是它。两处各写一遍 5 行，看起来无害，
/// 但「末段为空」这类边界一处分叉就没人发现。
String domainLabel(String domainId) => idTail(domainId);
