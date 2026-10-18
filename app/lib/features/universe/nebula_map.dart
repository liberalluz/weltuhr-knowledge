/// `Z2` 星云的几何 —— **一个域一朵分子云**（`SPEC-VIEW-038`）。
///
/// ## 为什么又是一套几何
///
/// `Z0` 画空间之间、`Z1` 画一张盘，`Z2` 画一朵云。三档的形态不同源（`VIEW-036`
/// –`038` 各自定义），走同一套项投影只会得到「同一堆点的第三种缩放」。所以这
/// 一档也自带几何 —— 但**不新开通道**：位置仍只由 `θ` 与 `φ` 决定（`VIEW-003`）。
///
/// | 通道 | 在 `Z2` 里的落法 | 依据 |
/// |---|---|---|
/// | `θ` | 六轴扇区（`primaryAxis` → 扇区序号 + 轴内取值分位） | `ADR-0003` §决策 3 |
/// | `φ` | **云内半径**：累计项数分位（域内口径） | `ADR-0003` 修订四 |
/// | `r` | 退化 —— 整朵云就是一个域带 | `ADR-0003` §决策 1 |
///
/// ⚠️ `φ` 从「轴向高度」改成「云内半径」，是因为 `Z2` 正对云面看一眼云：
/// 这个视野里没有「上下」，硬留着高度通道等于把它画成一条竖线。**语义没变**
/// （仍是累计项数分位），变的是它在屏幕上的落法 —— 与 `Z1` 把 `r` 落到旋臂
/// 弧长上是同一类改动（`ADR-0003` 修订三），都属解释段细化，不改决策。
///
/// ## 什么承载语义，什么不承载
///
/// - **云粒子**：数量固定（`C-62`），不跟项数走 —— 否则它与盘半径、点密度
///   构成第三条「项数」通道（`VIEW-038` / `X-02`）。内圈偏红外圈偏蓝只是
///   氢 α 与尘埃反射的**物理**，不编码任何东西。
/// - **亮结**：`⪯` 子树，可点（`VIEW-038`）。数量 = 子树数，**不凑数**。
/// - **项**：云里的恒星，可点 ⇒ `Z4`（`VIEW-001`：`Z2` 容器与星都能点）。
/// - **出口标记**：跨域边，**不画断线**（`VIEW-038`）。
///
/// ## 确定性
///
/// 粒子位置、出口方位全部由 `domainId` 与目标域 id 的 FNV-1a 定（复用
/// `galaxy_map.dart` 的 `galaxyHash01`）—— 不用 `Random`：随机数会让同一个域
/// 每次打开都换一朵云。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/frame/projection.dart' show SceneNode;
import '../../core/frame/scene.dart';
import '../../core/graph/subtrees.dart';
import '../../core/ids.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/tree.dart' show phiLevelsOf;
import 'galaxy_map.dart' show accentArgbOf, galaxyHash01;

/// 云缘留白：项最远落在这里，不再往外 —— 贴到边上的点会被云的轮廓吃掉。
const double _itemRadiusOuter = 0.86;

/// 云心留白：中心的项不压在云最亮的那一块上，否则「云心亮」会读成「这一项
/// 有什么特别」。
const double _itemRadiusInner = 0.12;

/// 出口标记的方位角在均分位上的抖动幅度（占总角度的比例）。
///
/// 均分是为了几个出口不叠在一起；抖动是为了让它们看起来不像刻度盘。
const double _exitAngleJitter = 0.06;

/// 云里的一颗粒子。
class NebulaWisp {
  const NebulaWisp({
    required this.center,
    required this.radius,
    required this.argb,
  });

  final Offset center;
  final double radius;

  /// 颜色由**距云心的远近**定（内红外蓝，`VIEW-038`）。⚠️ 只表达物理，
  /// 不表达语义 —— 不得按掌握度 / 项数 / 难度调色（`X-02`）。
  final int argb;
}

/// 云里的一项（可点 ⇒ `Z4`）。
class NebulaItem {
  const NebulaItem({required this.id, required this.center});

  final String id;
  final Offset center;
}

/// 域内的一条边（两端都在这个域里，`VIEW-038`：域内边照常画）。
class NebulaThread {
  const NebulaThread({required this.from, required this.to});

  final Offset from;
  final Offset to;
}

/// 一个亮结 = 一棵 `⪯` 子树（`VIEW-038`）。**可点** ⇒ `Z3`；单项子树 ⇒ `Z4`。
class NebulaKnot {
  const NebulaKnot({
    required this.rootId,
    required this.label,
    required this.memberIds,
    required this.center,
  });

  /// 子树根的 `Item.id`。点它进 `Z3` 时选中的就是这一项。
  final String rootId;

  /// 显示名 = 根项的标题（域只有 `domainId`、子树没有名字，只能借根的标题）。
  final String label;

  final List<String> memberIds;

  final Offset center;

  int get itemCount => memberIds.length;

  /// 单项子树 ⇒ 点它**跳过 `Z3`** 直接 `Z4`（`VIEW-038`）。
  bool get isSingle => memberIds.length <= 1;
}

/// 一个跨域出口（`VIEW-038`：画成出口标记，不画断线）。
class NebulaExit {
  const NebulaExit({
    required this.targetDomainId,
    required this.label,
    required this.center,
    required this.direction,
    required this.edgeCount,
  });

  final String targetDomainId;

  /// 标记文字。⚠️ 规格写的是「→ 进入〈动词形态〉」，而包里**没有**域的动词形态
  /// （没有 `Domain` 实体，只有 `domainId` 字符串）⇒ 这里退成末段域名。
  /// 与 `VIEW-018` 的中文域名同一个缺口，一并归 `PACK` 域修订，不假造。
  final String label;

  /// 云缘上的落点。
  final Offset center;

  /// 朝外单位向量 —— 箭头指向它，文字也按这个方向往外让。
  final Offset direction;

  /// 通向该域的边数（只用于自检与说明，不上屏）。
  final int edgeCount;
}

/// 一次 `Z2` 布局的结果。
class NebulaLayout {
  const NebulaLayout({
    required this.center,
    required this.cloudRadius,
    required this.accentArgb,
    required this.domainId,
    required this.domainItemCount,
    required this.wisps,
    required this.items,
    required this.knots,
    required this.threads,
    required this.exits,
  });

  /// 空云：没有包、没有域，或这个域一项都没有。界面据此退回项场景（诊断路径）。
  static const NebulaLayout empty = NebulaLayout(
    center: Offset.zero,
    cloudRadius: 0,
    accentArgb: 0xFF6E63D8,
    domainId: '',
    domainItemCount: 0,
    wisps: <NebulaWisp>[],
    items: <NebulaItem>[],
    knots: <NebulaKnot>[],
    threads: <NebulaThread>[],
    exits: <NebulaExit>[],
  );

  final Offset center;
  final double cloudRadius;
  final int accentArgb;
  final String domainId;

  /// 域内**全量**项数（不受筛选影响）—— `VIEW-038` 的「亮结 = 真实子树数」
  /// 就是按全量算的，筛掉几项不该让亮结消失。
  final int domainItemCount;

  /// 云粒子。数量 = `C-62`，**与项数无关**。
  final List<NebulaWisp> wisps;

  /// 画出来的项（筛掉的没有）。可点 ⇒ `Z4`。
  final List<NebulaItem> items;

  /// 亮结。可点 ⇒ `Z3` / 单项 ⇒ `Z4`。
  final List<NebulaKnot> knots;

  /// 域内边。
  final List<NebulaThread> threads;

  /// 跨域出口。
  final List<NebulaExit> exits;

  bool get isEmpty => wisps.isEmpty && knots.isEmpty && items.isEmpty;

  NebulaKnot? knotOf(String rootId) {
    for (final NebulaKnot knot in knots) {
      if (knot.rootId == rootId) {
        return knot;
      }
    }
    return null;
  }
}

/// 按包、域与视口算出一朵云。
///
/// [visibleIds] 是筛选结果（`null` = 不筛）。它只减**项与域内边**：粒子与亮结
/// 永远是全量 —— 筛的是项，不是把结构抹掉；一个域的项被筛空，那些亮结仍然
/// 在，否则用户会以为「这个域没有恒星系了」。
///
/// 空域（无项）返回 [NebulaLayout.empty]：给一个没有内容的域画一朵云，等于说
/// 「这里有东西」，而它没有（`SPEC-FND-014` 未声明即不渲染）。
NebulaLayout layoutNebula({
  required LoadedPack pack,
  required String domainId,
  required Size viewport,
  Set<String>? visibleIds,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return NebulaLayout.empty;
  }
  final List<Item> inDomain = <Item>[
    for (final Item item in pack.items)
      if (item.domainId == domainId) item,
  ];
  if (inDomain.isEmpty) {
    return NebulaLayout.empty;
  }

  final Offset center = Offset(viewport.width / 2, viewport.height / 2);
  final double cloudRadius =
      math.min(viewport.width, viewport.height) / 2 * nebulaRadiusRatio;
  if (cloudRadius <= 0) {
    return NebulaLayout.empty;
  }

  // `θ` 走**同一份**装配结果（`buildSceneNodes`）：`Z2` 若自己再解一遍
  // `primaryAxis` → 扇区，就成了第二套判据 —— 而那两套迟早不一致。
  final List<SceneNode> nodes = buildSceneNodes(
    pack,
    sectorCount: sixAxisKeys.length,
  );
  final Map<String, SceneNode> nodeOf = <String, SceneNode>{
    for (final SceneNode node in nodes) node.id: node,
  };
  final double sectorWidth = fullTurnRadians / sixAxisKeys.length;

  // `φ` 的域内口径：先按层号、再按包内顺序排，取 (i / n)。
  //
  // 为什么不是全局累计分位：`Z2` 只画一个域，用全局分位会让一个域里的项
  // 全部挤在 `0.3…0.5` 这样的窄带里 —— 云的半径就白留了。域内口径仍是
  // 「累计项数分位」，只是分母换成这个域的项数。
  //
  // ⚠️ 排序键里必须带**原下标**：`List.sort` 不保证稳定，只按层号比较会把
  // 同层的项排成什么样交给实现决定 —— 那样「同一个域两次打开是不是同一朵云」
  // 就挂在了排序算法的实现细节上。
  final Map<String, int> packIndex = <String, int>{
    for (int i = 0; i < inDomain.length; i++) inDomain[i].id: i,
  };
  final Map<String, int> levels = phiLevelsOf(pack);
  final List<Item> ordered = <Item>[...inDomain];
  ordered.sort((Item a, Item b) {
    final int levelA = levels[a.id] ?? 0;
    final int levelB = levels[b.id] ?? 0;
    if (levelA != levelB) {
      return levelA.compareTo(levelB);
    }
    return (packIndex[a.id] ?? 0).compareTo(packIndex[b.id] ?? 0);
  });

  final Map<String, Offset> positionOf = <String, Offset>{};
  for (int i = 0; i < ordered.length; i++) {
    final Item item = ordered[i];
    final SceneNode? node = nodeOf[item.id];
    // 未声明主轴 ⇒ `buildSceneNodes` 给越界扇区（`sectorCount`），角度会落到
    // 一整圈之外再绕回来。这与 `FramePainter` 的表现一致（那里也是越界值），
    // **不在这里替它挑一个轴**（`ADR-0003` §决策 3：不按优先级猜）。
    final double theta = node == null
        ? 0
        : node.sector * sectorWidth + node.sectorFraction01 * sectorWidth;
    final double phi01 = ordered.length == 1 ? 0.5 : i / ordered.length;
    final double radius =
        cloudRadius *
        (_itemRadiusInner + (_itemRadiusOuter - _itemRadiusInner) * phi01);
    positionOf[item.id] = Offset(
      center.dx + radius * math.cos(theta),
      center.dy + radius * math.sin(theta),
    );
  }

  // 云粒子：数量恒定（`C-62`）。半径取 √h 是为了**面积均匀** —— 直接按 h
  // 取半径会让粒子堆在云心，云看起来是个核而不是朵云。
  final List<NebulaWisp> wisps = <NebulaWisp>[];
  for (int i = 0; i < nebulaParticleCount; i++) {
    final double h1 = galaxyHash01('$domainId:wisp:$i:a');
    final double h2 = galaxyHash01('$domainId:wisp:$i:b');
    final double r01 = math.sqrt(h1) * 0.98;
    final double theta = h2 * fullTurnRadians;
    final double radius = cloudRadius * r01;
    wisps.add(
      NebulaWisp(
        center: Offset(
          center.dx + radius * math.cos(theta),
          center.dy + radius * math.sin(theta),
        ),
        radius: 1.0 + 2.4 * galaxyHash01('$domainId:wisp:$i:c'),
        argb: _wispArgb(r01),
      ),
    );
  }

  final Set<String> ids = <String>{for (final Item item in inDomain) item.id};

  // 亮结 = `⪯` 子树（`VIEW-038`）。位置取成员位置的**质心** —— 一簇星中间
  // 那一块，正是「亮结」该在的地方；单项子树就落在自己身上。
  final List<NebulaKnot> knots = <NebulaKnot>[];
  for (final PrereqSubtree subtree in subtreesInDomain(
    items: inDomain,
    edges: pack.edges,
  )) {
    double sumX = 0;
    double sumY = 0;
    int seen = 0;
    for (final String memberId in subtree.memberIds) {
      final Offset? at = positionOf[memberId];
      if (at == null) {
        continue;
      }
      sumX += at.dx;
      sumY += at.dy;
      seen += 1;
    }
    if (seen == 0) {
      continue;
    }
    final Item root = inDomain.firstWhere(
      (Item item) => item.id == subtree.rootId,
    );
    knots.add(
      NebulaKnot(
        rootId: subtree.rootId,
        label: root.title,
        memberIds: subtree.memberIds,
        center: Offset(sumX / seen, sumY / seen),
      ),
    );
  }

  // 边：域内的画线，跨域的攒成出口。⚠️ 跨域边**不画断线** —— 它本来就是
  // 「学完这里进那里」的入口，画成一条伸出去就断的线会被读成数据缺了。
  final List<NebulaThread> threads = <NebulaThread>[];
  final Map<String, int> exitCounts = <String, int>{};
  final List<String> exitOrder = <String>[];
  for (final Edge edge in pack.edges) {
    final bool fromInside = ids.contains(edge.from);
    final bool toInside = ids.contains(edge.to);
    if (fromInside && toInside) {
      if (visibleIds != null &&
          (!visibleIds.contains(edge.from) || !visibleIds.contains(edge.to))) {
        continue;
      }
      final Offset? from = positionOf[edge.from];
      final Offset? to = positionOf[edge.to];
      if (from == null || to == null) {
        continue;
      }
      threads.add(NebulaThread(from: from, to: to));
      continue;
    }
    if (!fromInside && !toInside) {
      continue;
    }
    final String targetId = fromInside ? edge.to : edge.from;
    final String? targetDomain = _domainOf(pack, targetId);
    if (targetDomain == null || targetDomain == domainId) {
      // 端点不在册（`itemOf` 取不到）⇒ 画不出目标域名。这类边由
      // `buildSceneNodes` 的占位节点接住（`ADR-0003` §决策 5），本层不重复处理。
      continue;
    }
    if (!exitCounts.containsKey(targetDomain)) {
      exitOrder.add(targetDomain);
    }
    exitCounts[targetDomain] = (exitCounts[targetDomain] ?? 0) + 1;
  }

  final List<NebulaExit> exits = <NebulaExit>[];
  for (int i = 0; i < exitOrder.length; i++) {
    final String targetDomainId = exitOrder[i];
    final double base = (i + 0.5) / exitOrder.length;
    final double jitter =
        (galaxyHash01('$domainId>exit:$targetDomainId') - 0.5) * _exitAngleJitter;
    final double theta = (base + jitter) * fullTurnRadians;
    final Offset direction = Offset(math.cos(theta), math.sin(theta));
    final double radius = cloudRadius * 0.92;
    exits.add(
      NebulaExit(
        targetDomainId: targetDomainId,
        label: '→ 进入 ${idTail(targetDomainId)}',
        center: center + direction * radius,
        direction: direction,
        edgeCount: exitCounts[targetDomainId] ?? 0,
      ),
    );
  }

  return NebulaLayout(
    center: center,
    cloudRadius: cloudRadius,
    accentArgb: accentArgbOf(pack.space.accent),
    domainId: domainId,
    domainItemCount: inDomain.length,
    wisps: wisps,
    items: <NebulaItem>[
      for (final Item item in inDomain)
        if (visibleIds == null || visibleIds.contains(item.id))
          if (positionOf[item.id] != null)
            NebulaItem(id: item.id, center: positionOf[item.id]!),
    ],
    knots: knots,
    threads: threads,
    exits: exits,
  );
}

/// 某个项属于哪个域。端点不在册时给 `null`。
String? _domainOf(LoadedPack pack, String itemId) =>
    pack.itemOf(itemId)?.domainId;

/// 云粒子颜色：内圈偏红（氢 α），外圈偏蓝（尘埃反射）。
///
/// 两端取值都压得很暗 —— 云是背景，亮起来会把可点的星与亮结淹掉。
int _wispArgb(double r01) {
  const int innerR = 0xC0;
  const int innerG = 0x70;
  const int innerB = 0x6A;
  const int outerR = 0x5C;
  const int outerG = 0x7F;
  const int outerB = 0xA8;
  int mix(int a, int b) => (a + (b - a) * r01).round();
  return 0xFF000000 |
      (mix(innerR, outerR) << 16) |
      (mix(innerG, outerG) << 8) |
      mix(innerB, outerB);
}

/// 点亮结的命中半径（`VIEW-038`：亮结可点 ⇒ `Z3`）。
///
/// 与 `Z1` 的域点同一条 24 px 口径（`VIEW-018`）：看得见、点不中等于不可点。
/// 直接复用 `domainMarkMinTapDiameter` 而不是再抄一个 `24` 进来 —— 那个数在
/// 常量表里已经有 `galaxyMinTapDiameter` / `domainMarkMinTapDiameter` 两份了。
const double _knotHitRadius = domainMarkMinTapDiameter / 2;

/// 点 [point] 命中的亮结。多个命中取更近的那个。
NebulaKnot? pickNebulaKnotAt({
  required NebulaLayout layout,
  required Offset point,
}) {
  NebulaKnot? best;
  double bestDistance = _knotHitRadius;
  for (final NebulaKnot knot in layout.knots) {
    final double distance = (knot.center - point).distance;
    if (distance <= bestDistance) {
      bestDistance = distance;
      best = knot;
    }
  }
  return best;
}

/// 点 [point] 命中的项。`null` = 点空了（空白与云粒子都不产生动作）。
///
/// 命中半径用 `C-44` 的同一条可点下限（8 px）：星画得再小也要够得着。
String? pickNebulaItemAt({
  required NebulaLayout layout,
  required Offset point,
}) {
  String? best;
  double bestDistance = pickMinHitRadius;
  for (final NebulaItem item in layout.items) {
    final double distance = (item.center - point).distance;
    if (distance <= bestDistance) {
      bestDistance = distance;
      best = item.id;
    }
  }
  return best;
}
