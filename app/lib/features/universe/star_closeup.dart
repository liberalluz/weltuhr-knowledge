/// `Z4` 的几何 —— **一颗恒星的特写**（`SPEC-VIEW-040`）。
///
/// ## 这一档画什么
///
/// `Z3` → `Z4` 是**推近**，与 `Z0` → `Z1` 同构（`VIEW-040`）：同一个恒星系，
/// 恒星从「短边的 4.5%」放大到「短边的 46%」，轨道只剩最内的 `C-81` 条。
///
/// | 通道 | 在 `Z4` 里的落法 | 依据 |
/// |---|---|---|
/// | `φ` | **不落** —— 轨道序号已被 `Z3` 用完，这一档只剩「这一项本身」 | `VIEW-040` |
/// | `θ` / `r` | 不落 —— `Z3` 起已退化（`ADR-0003` 修订五） | 同上 |
///
/// 五档里唯一**一个通道都不承载语义**的一档。这不是退化，是它的职责：`Z4`
/// 是「看这一项」，不是「看它在哪」。
///
/// ## 不转
///
/// 恒星自转在这个视野下不可见（`VIEW-040` 原话），动起来反而读不清纹理。
/// 「这一层是活的」的职责已由 `Z1` 自转承担，`Z3` 的行星公转由 `V-1i` 承担。
///
/// ## ⚠️ 本档最大的一处妥协
///
/// 真实里把太阳填满画面时，最近的行星在画面外 42 个太阳直径处 —— `Z4` 视野里
/// **一颗行星都不该出现**。所以 `C-79` / `C-80` 那两条比例是**为了让轨道出现在
/// 画面里**而定的，不承载任何语义。规格的边界也正在这里：只露 1–2 条，
/// **不做成太阳系示意图**（不画完整轨道族、不标注行星名）。
///
/// ## 三条必写（`VIEW-040`）
///
/// 1. **所有项一律画成同一类天体**。`Item.type` 是**知识属性**（概念 / 事实 /
///    技能…），不是天文类型 —— 按它分「红巨星 / 白矮星」是私开一条通道，且与
///    `C-34` 那批（`type = tacit` ≡ 不可外化 ≥ 3 格）同集重合，等于同一个事实
///    表达两次。所以本文件**不读 `Item.type`**；恒星外观只由空间 accent 与
///    `item.id` 的哈希定。
/// 2. **米粒组织 / 黑子的位置由 `item.id + index` 哈希定，禁随机** —— 否则
///    第二次打开像换了一颗星。
/// 3. **邻域只能靠抽屉文字，不靠空间展开**。真实邻域在几十万倍外，不可能同屏；
///    在画面里拉开几个「邻居星」会被读成「它们就在旁边」—— 所以这一档**不画
///    任何邻项**，只有恒星、表面纹理与最内两条轨道上的行星。
///
/// ## 孤星也画
///
/// 与 `Z3` 不同：`Z3` 的 `isEmpty` 判「有没有后继」（一颗孤星加一圈空轨道等于
/// 说「它有两颗行星」），而 `Z4` 是**单星特写**，这一项没有后继正是它的常态。
/// 这里只有「项不在包里」才算空。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/motion.dart' show spunRadians;
import 'galaxy_map.dart' show accentArgbOf, galaxyHash01;
import 'star_map.dart'
    show
        StarOrbit,
        StarPlanet,
        StarSystemLayout,
        layoutStarSystem,
        pointOnOrbit,
        starOrbitPeriodSeconds;

/// 恒星表面的一颗斑点（米粒或黑子）。两种只差颜色与分布区间，形状是同一个。
class StarSpeck {
  const StarSpeck({required this.center, required this.radius});

  final Offset center;
  final double radius;
}

/// 一次 `Z4` 布局的结果。
class StarCloseupLayout {
  const StarCloseupLayout({
    required this.starCenter,
    required this.starRadius,
    required this.accentArgb,
    required this.itemId,
    required this.itemLabel,
    required this.domainId,
    required this.levelCount,
    required this.orbits,
    required this.planets,
    required this.granules,
    required this.spots,
  });

  /// 空：**没有包 / 选中项不在包里**。
  ///
  /// ⚠️ **不含「这一项没有后继」** —— 见文件头「孤星也画」。
  static const StarCloseupLayout empty = StarCloseupLayout(
    starCenter: Offset.zero,
    starRadius: 0,
    accentArgb: 0xFF6E63D8,
    itemId: '',
    itemLabel: '',
    domainId: '',
    levelCount: 0,
    orbits: <StarOrbit>[],
    planets: <StarPlanet>[],
    granules: <StarSpeck>[],
    spots: <StarSpeck>[],
  );

  final Offset starCenter;
  final double starRadius;
  final int accentArgb;

  /// 这颗恒星对应的项 —— 也就是详情抽屉里正在显示的那一项。
  final String itemId;
  final String itemLabel;
  final String domainId;

  /// `Z3` 的**真实层数**（不是本档露出来的条数）。
  ///
  /// 只用于算开普勒周期（[starOrbitPeriodSeconds]）：分母若取本档的
  /// `C-81`，同一颗行星在 `Z3` 与 `Z4` 里会得到两个周期 —— 推近的一瞬间
  /// 它会突然变速，而两档看的是同一颗。
  final int levelCount;

  /// 露出来的轨道（`≤ C-81` 条），按层号升序。
  final List<StarOrbit> orbits;

  /// 这些轨道上的行星（筛掉的没有）。**不标名**（`VIEW-040` 边界）。
  final List<StarPlanet> planets;

  /// 米粒组织：亮斑，`C-82` 颗。
  final List<StarSpeck> granules;

  /// 黑子：暗斑，`C-84` 个。
  final List<StarSpeck> spots;

  bool get isEmpty => itemId.isEmpty;

  /// 按 id 取一颗行星。与 `StarSystemLayout.planetOf` 同名同义 —— 两档看的是
  /// 同一颗行星，取法不该有两套。
  StarPlanet? planetOf(String id) {
    for (final StarPlanet planet in planets) {
      if (planet.id == id) {
        return planet;
      }
    }
    return null;
  }

  /// 行星公转 [clockSeconds] 秒之后的一份布局（`C-56`）。
  ///
  /// 与 `StarSystemLayout.advanced` 同一套：只搬行星落点，不动恒星、轨道、纹理。
  /// ⚠️ 这里**必须自己算一遍**而不是把 `Z3` 的布局整套搬过来 —— 本档的椭圆是
  /// `C-79` / `C-80` 的尺度，`Z3` 的落点搬进来行星会跑出画面。参数角共用，
  /// 半长轴各用各的，这正是 [pointOnOrbit] 只吃 `orbit` 不吃 `a` 的原因。
  StarCloseupLayout advanced(double clockSeconds) {
    if (planets.isEmpty ||
        orbits.isEmpty ||
        clockSeconds == 0 ||
        !clockSeconds.isFinite) {
      return this;
    }
    final Map<int, StarOrbit> byLevel = <int, StarOrbit>{
      for (final StarOrbit orbit in orbits) orbit.level: orbit,
    };
    final List<StarPlanet> moved = <StarPlanet>[];
    for (final StarPlanet planet in planets) {
      final StarOrbit? orbit = byLevel[planet.level];
      if (orbit == null) {
        moved.add(planet);
        continue;
      }
      final double angle =
          planet.phase +
          spunRadians(
            clockSeconds,
            starOrbitPeriodSeconds(planet.level, levelCount),
          );
      moved.add(
        StarPlanet(
          id: planet.id,
          level: planet.level,
          center: pointOnOrbit(orbit, angle, starCenter),
          phase: planet.phase,
        ),
      );
    }
    return StarCloseupLayout(
      starCenter: starCenter,
      starRadius: starRadius,
      accentArgb: accentArgb,
      itemId: itemId,
      itemLabel: itemLabel,
      domainId: domainId,
      levelCount: levelCount,
      orbits: orbits,
      planets: moved,
      granules: granules,
      spots: spots,
    );
  }
}

/// 按包、恒星项与视口算出一次 `Z4` 特写。
///
/// [visibleIds] 是筛选结果（`null` = 不筛）。与 `Z3` 同口径：它只减**行星**，
/// 轨道数与相位仍按全量算 —— 筛掉一颗不该让另一颗换个位置。
StarCloseupLayout layoutStarCloseup({
  required LoadedPack pack,
  required String itemId,
  required Size viewport,
  Set<String>? visibleIds,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return StarCloseupLayout.empty;
  }
  final Item? item = pack.itemOf(itemId);
  if (item == null) {
    return StarCloseupLayout.empty;
  }

  final Offset center = Offset(viewport.width / 2, viewport.height / 2);
  final double half = math.min(viewport.width, viewport.height) / 2;
  final double starRadius = half * closeupStarRadiusRatio;

  // 复用 `Z3` 那一套：层号、偏心率、长轴朝向、相位全在那边算好了。这一档只
  // 换**尺度**（`C-79` / `C-80` 而不是 `C-73` / `C-74`），不换关系 —— 两档
  // 各算一遍 BFS 的话，「推近」会变成「另一张图」。
  //
  // ⚠️ 空系统是常态（孤星），不是在报错：见文件头「孤星也画」。
  final StarSystemLayout system = layoutStarSystem(
    pack: pack,
    rootId: itemId,
    viewport: viewport,
    visibleIds: visibleIds,
  );
  final List<StarOrbit> srcOrbits = system.orbits
      .take(closeupMaxOrbits)
      .toList();
  final int orbitCount = srcOrbits.length;

  final double innerA = starRadius * closeupOrbitInnerRatio;
  final double outerA = starRadius * closeupOrbitOuterRatio;

  final List<StarOrbit> orbits = <StarOrbit>[];
  for (final StarOrbit each in srcOrbits) {
    // 只有一条轨道时用**内**比例：那是「最内那条」，也就是这一档唯一该有的
    // 那条。用中点会让「有没有第二层」在画面上看不出来。
    final double a = orbitCount <= 1
        ? innerA
        : innerA + (outerA - innerA) * ((each.level - 1) / (orbitCount - 1));
    orbits.add(
      StarOrbit(
        level: each.level,
        semiMajor: a,
        semiMinor: a * math.sqrt(1 - each.eccentricity * each.eccentricity),
        rotation: each.rotation,
        eccentricity: each.eccentricity,
      ),
    );
  }

  // 行星落点必须按**这一档的**椭圆重算。参数角直接取 `Z3` 的（`StarPlanet.phase`），
  // 所以推近之后行星还在同一条半径方向上，只是离恒星更近。
  final List<StarPlanet> planets = <StarPlanet>[];
  if (orbits.isNotEmpty) {
    final Map<int, StarOrbit> byLevel = <int, StarOrbit>{
      for (final StarOrbit orbit in orbits) orbit.level: orbit,
    };
    for (final StarPlanet each in system.planets) {
      final StarOrbit? orbit = byLevel[each.level];
      if (orbit == null) {
        continue;
      }
      planets.add(
        StarPlanet(
          id: each.id,
          level: each.level,
          center: pointOnOrbit(orbit, each.phase, center),
          phase: each.phase,
        ),
      );
    }
  }

  // 表面纹理。**两处都不读 `item.type`**（`VIEW-040` 第 1 条）：只取 `itemId`
  // 的哈希 —— 同一项每次打开是同一张脸，换一项就换一张。
  //
  // 半径用 `sqrt(h)` 而不是 `h`：`h` 直接当半径会让斑点挤在圆心的四分之一面积
  // 里（面积是半径的平方）。
  //
  // `0.88` 而不是 `0.94`（贴到盘边更自然）：米粒自己是**有半径的圆**，圆心分布
  // 到 `0.94 R` 时加上 `C-83` 的半径会突出盘外 1.5%。有光晕在，画面上看不出，
  // 但「米粒都在恒星盘内」这条就没有一条能判的断言了 —— 0.88 + 0.075 = 0.955。
  final List<StarSpeck> granules = <StarSpeck>[];
  for (int i = 0; i < closeupGranuleCount; i++) {
    final double h1 = galaxyHash01('$itemId:granule:$i:r');
    final double h2 = galaxyHash01('$itemId:granule:$i:t');
    final double h3 = galaxyHash01('$itemId:granule:$i:s');
    final double r = starRadius * 0.88 * math.sqrt(h1);
    final double theta = h2 * fullTurnRadians;
    granules.add(
      StarSpeck(
        center: Offset(
          center.dx + r * math.cos(theta),
          center.dy + r * math.sin(theta),
        ),
        // 0.55…1.0 倍：一样大的一圈圆点像网点纸。
        radius: starRadius * closeupGranuleRadiusRatio * (0.55 + 0.45 * h3),
      ),
    );
  }

  final List<StarSpeck> spots = <StarSpeck>[];
  for (int i = 0; i < closeupSpotCount; i++) {
    final double h1 = galaxyHash01('$itemId:spot:$i:r');
    final double h2 = galaxyHash01('$itemId:spot:$i:t');
    final double h3 = galaxyHash01('$itemId:spot:$i:s');
    // 黑子**不落在盘边**：`0.12…0.62` 这一段。贴边的黑子会被光晕吃掉一半，
    // 看起来像恒星缺了个口。
    final double r = starRadius * (0.12 + 0.5 * h1);
    final double theta = h2 * fullTurnRadians;
    spots.add(
      StarSpeck(
        center: Offset(
          center.dx + r * math.cos(theta),
          center.dy + r * math.sin(theta),
        ),
        radius: starRadius * closeupSpotRadiusRatio * (0.7 + 0.6 * h3),
      ),
    );
  }

  return StarCloseupLayout(
    starCenter: center,
    starRadius: starRadius,
    accentArgb: accentArgbOf(pack.space.accent),
    itemId: itemId,
    itemLabel: item.title,
    domainId: item.domainId,
    // 真实层数取 `Z3` 那一份的轨道条数 —— 本档的 `orbits` 只到 `C-81`。
    levelCount: system.orbits.length,
    orbits: orbits,
    planets: planets,
    granules: granules,
    spots: spots,
  );
}
