/// `Z3` 恒星系的几何 —— **一条 `⪯` 链 = 一颗恒星 + 共面轨道**（`SPEC-VIEW-039`）。
///
/// ## 这一档画什么
///
/// 恒星 = 当前选中的那一项（`_selectedItemId`，`V-1d` 的 `_jumpToKnot()` 落的
/// 是亮结的子树根）。行星 = 它在**同域内**的 `⪯` 后继，按层号落进同心轨道。
///
/// ⚠️ **只画这一棵子树，不画整个域**：`VIEW-039` 写的是「`Z3` 画的是**一条**
/// `⪯` 链」。一个域里有几个根就有几个恒星系，`Z2` 的亮结正是它们的入口 ——
/// 把整域的项都铺到这一档，等于把 `Z2` 又画了一遍，只是换成了圆。
///
/// | 通道 | 在 `Z3` 里的落法 | 依据 |
/// |---|---|---|
/// | `φ` | **轨道序号**（相对恒星的层号 → 第几条轨道） | `VIEW-039` 正文 |
/// | `θ` | 退化 —— 行星方位角由「同层均分 + 哈希抖动」定，不是六轴 | `ADR-0003` 修订五 |
/// | `r` | 退化 —— 只有一个域，没有相邻域可比 | 同上 |
///
/// 一档里两个通道同时退化，这是第一次：`Z0`–`Z2` 至少保住 `θ` 或 `φ`。代价是
/// 「这一档不能靠位置读出轴与域」—— 但那本来也不是它的职责，它读的是
/// **「学这一项之前要先学哪些」这条链的形状**。
///
/// ## 三条真实约束（`VIEW-039`）
///
/// 1. **同向**：所有轨道的角速度方向一致。本笔还没有运动（归 `V-1i`），但
///    相位已经全部按**同一方向**递增，接上 `C-56` 时不需要重排。
/// 2. **共面**：轨道倾角差 0。屏幕上正对黄道面看 —— 不压扁，所以长短轴都是
///    实数，不是投影出来的。
/// 3. **开普勒 `T ∝ a^1.5`**：本笔**不实现** —— 没有运动就没有周期可验。
///    `C-56`（内轨 8 s）仍登记在表里，归 `V-1i`。
///
/// ## 同层多颗共轨
///
/// 链状数据（`english` / `german` 每域 10 项 9 边）每层恰好一颗，不会触发。
/// `python` 的域有分支，同层可能有多颗 —— 它们落在**同一条轨道**上按方位均分。
///
/// ⚠️ 真实里同轨两颗会共振、很快散掉。这里是妥协，但它守住了规格明写的两条
/// （共面、同向），而违反其中任何一条都更显眼。**不为了避开这个妥协去改 `φ`
/// 的映射**：`φ` → 轨道序号是 `VIEW-039` 的正文，改它就是改规格。
///
/// ## 确定性
///
/// 偏心率、长轴朝向、相位抖动、云气位置全部由 `rootId` 与 `item.id` 的 FNV-1a
/// 定（复用 `galaxy_map.dart` 的 `galaxyHash01`）—— 同一个恒星系两次打开必须是
/// 同一张图。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/motion.dart' show spunRadians;
import 'galaxy_map.dart' show accentArgbOf, galaxyHash01;

/// 相位抖动的幅度（占该层均分角的比例）。
///
/// 均分是为了同层几颗不叠在一起；抖动是为了让它们看起来不像刻度盘。
/// 0.06 与 `Z2` 出口的 `_exitAngleJitter` 同量级 —— 两处都在「等分 + 一点手抖」。
const double _phaseJitterRatio = 0.06;

/// 一条轨道。**共面**：椭圆的长短轴都在屏幕平面里，倾角差 0。
class StarOrbit {
  const StarOrbit({
    required this.level,
    required this.semiMajor,
    required this.semiMinor,
    required this.rotation,
    required this.eccentricity,
  });

  /// `φ` 层号（相对恒星，`1` = 最内）。
  final int level;

  final double semiMajor;
  final double semiMinor;

  /// 长轴的方位角（rad）。由哈希定，**不承载语义**。
  final double rotation;

  final double eccentricity;
}

/// 椭圆参数角 [phase] 上的那一点（画布坐标）。
///
/// 三处要用同一个算式：`layoutStarSystem` 的静态落点、`StarSystemLayout.advanced`
/// 的逐帧推进、`layoutStarCloseup` 的换尺度重算。各写一遍的话，日后调偏心率或
/// 长轴朝向的换算，漏一处就是「推近之后行星跑偏」—— 画面上看着像新画的，不会有
/// 任何断言变红（`R-08` 同族）。
///
/// 参数角不是极角：`a·cos t` 与 `b·sin t` 是椭圆的参数式，`t` 只有在正圆时才
/// 等于方位角。这里保留参数角口径，是因为相位均分（`Z3`）与开普勒推进（`C-56`）
/// 都以它为自变量。
Offset pointOnOrbit(StarOrbit orbit, double phase, Offset center) {
  final double cosR = math.cos(orbit.rotation);
  final double sinR = math.sin(orbit.rotation);
  final Offset local = Offset(
    orbit.semiMajor * math.cos(phase),
    orbit.semiMinor * math.sin(phase),
  );
  return Offset(
    center.dx + local.dx * cosR - local.dy * sinR,
    center.dy + local.dx * sinR + local.dy * cosR,
  );
}

/// 第 [level] 层行星的公转周期（秒）—— `C-56` 开普勒 `T ∝ a^1.5`。
///
/// [levelCount] 是**真实层数**（`Z3` 的轨道条数），不是当前档画出来的条数：
/// `Z4` 只露 `C-81` 条，用它的条数当分母会让同一颗行星在两档里周期不同 ——
/// 推近的一瞬间行星会突然变速，而两档看的是同一颗。
///
/// 半长轴之比按 `C-73` / `C-74` 与层号推：`Z3` 的轨道半径是层号等分，所以
/// `a_level / a_inner = 1 + (C-74/C-73 - 1)·(level-1)/(n-1)`。这样周期只依赖
/// 常量与层号，两档必然一致 —— 不必把 `Z3` 的 `semiMajor` 带进 `Z4`。
double starOrbitPeriodSeconds(int level, int levelCount) {
  if (levelCount <= 1 || level <= 1) {
    return innerOrbitPeriodSeconds.toDouble();
  }
  final double innerA = math.min(stellarOrbitInnerRatio, stellarOrbitOuterRatio);
  final double outerA = math.max(stellarOrbitInnerRatio, stellarOrbitOuterRatio);
  final double t = (level - 1) / (levelCount - 1);
  final double ratio = (innerA + (outerA - innerA) * t) / innerA;
  return (innerOrbitPeriodSeconds * math.pow(ratio, 1.5)).toDouble();
}

/// 一颗行星 = `⪯` 上的一个后继项。**可点** ⇒ `Z4`。
class StarPlanet {
  const StarPlanet({
    required this.id,
    required this.level,
    required this.center,
    required this.phase,
  });

  final String id;

  /// 它落在第几条轨道。
  final int level;

  final Offset center;

  /// 椭圆**参数角**（rad，`0` = 长轴正方向）。
  ///
  /// 单列出来是给 `Z4` 用的：那一档的轨道比例与这里不同（`C-79` / `C-80` vs
  /// `C-73` / `C-74`），要按自己的半长轴重算落点。带上参数角就不必在 `Z4` 里
  /// 把「同层均分 + 哈希抖动」再写一遍 —— 两处各写一遍，迟早一处改了另一处
  /// 没改，而表现只是「推近之后行星换了位置」（`R-08` 同族）。
  final double phase;
}

/// 一团残余云气。数量固定（`C-77`），**不跟项数走**。
class StarWisp {
  const StarWisp({required this.center, required this.radius});

  final Offset center;
  final double radius;
}

/// 一次 `Z3` 布局的结果。
class StarSystemLayout {
  const StarSystemLayout({
    required this.starCenter,
    required this.starRadius,
    required this.accentArgb,
    required this.rootId,
    required this.rootLabel,
    required this.domainId,
    required this.memberCount,
    required this.orbits,
    required this.planets,
    required this.wisps,
  });

  /// 空系统：没有包 / 选中项不在域内 / **这一项没有后继**。
  ///
  /// 最后一条是常态而不是异常：单项子树由 `VIEW-038` 在 `Z2` 就送去 `Z4` 了，
  /// 走不到这里。真走到了（从树或搜索直接跳 `Z3`），一颗孤星没有轨道可画，
  /// 界面退回项场景 —— 画一颗恒星加一圈空轨道等于说「它有两颗行星」。
  static const StarSystemLayout empty = StarSystemLayout(
    starCenter: Offset.zero,
    starRadius: 0,
    accentArgb: 0xFF6E63D8,
    rootId: '',
    rootLabel: '',
    domainId: '',
    memberCount: 0,
    orbits: <StarOrbit>[],
    planets: <StarPlanet>[],
    wisps: <StarWisp>[],
  );

  /// 恒星位置（视口正中）。
  final Offset starCenter;
  final double starRadius;
  final int accentArgb;

  /// 恒星对应的项 —— 点它进 `Z4`（它就是根项的特写）。
  final String rootId;

  /// 恒星名 = 根项标题。行星不标名（同 `Z2`：只有容器 / 焦点标名）。
  final String rootLabel;

  final String domainId;

  /// 成员数（含恒星，**全量**、不受筛选影响）—— 与 `Z2` 的亮结计数同口径。
  final int memberCount;

  final List<StarOrbit> orbits;

  /// 画出来的行星（筛掉的没有）。可点 ⇒ `Z4`。
  final List<StarPlanet> planets;

  final List<StarWisp> wisps;

  /// 只有**一条轨道都没有**才算空 —— 也就是这一项没有任何同域后继。
  ///
  /// ⚠️ **不看 [planets]**：筛选把行星筛光了，恒星与轨道仍然在（同 `Z2` 的
  /// 「粒子与亮结永远全量」）。若把「行星为空」也算空，筛选就会让整个恒星系
  /// 退回项场景 —— 用户会以为「这个域没有恒星系了」，而它只是被筛过。
  bool get isEmpty => orbits.isEmpty;

  int get planetCount => planets.length;

  StarPlanet? planetOf(String id) {
    for (final StarPlanet planet in planets) {
      if (planet.id == id) {
        return planet;
      }
    }
    return null;
  }

  /// 行星公转 [clockSeconds] 秒之后的一份布局（`C-56` 开普勒）。
  ///
  /// 只动**行星落点**：轨道、恒星、云气、层号一概不动 —— 于是这一份可以每帧调。
  /// 反过来，若每帧重跑 [layoutStarSystem] 就是每帧重算一遍 BFS 拓扑，那是
  /// 一整遍图遍历（`GalaxyLayout.spun` / `SpiralLayout.spun` 出于同一理由只搬点）。
  ///
  /// ⚠️ 推进加在**参数角**上，不是把椭圆整体转一个角：椭圆有偏心率与长轴朝向，
  /// 转椭圆会把轨道形状一起转走，行星于是「换了一条轨道」。
  ///
  /// ⚠️ 周期按 [starOrbitPeriodSeconds] 的层号口径，不用本布局的 `semiMajor`：
  /// `Z4` 的 `C-79` / `C-80` 与 `Z3` 的 `C-73` / `C-74` 不是同一个比例。
  StarSystemLayout advanced(double clockSeconds) {
    if (planets.isEmpty ||
        orbits.isEmpty ||
        clockSeconds == 0 ||
        !clockSeconds.isFinite) {
      return this;
    }
    final Map<int, StarOrbit> byLevel = <int, StarOrbit>{
      for (final StarOrbit orbit in orbits) orbit.level: orbit,
    };
    final int levelCount = orbits.length;
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
          // 保留静态相位：这一份可能被再一次 `advanced`，累加基准必须是它。
          phase: planet.phase,
        ),
      );
    }
    return StarSystemLayout(
      starCenter: starCenter,
      starRadius: starRadius,
      accentArgb: accentArgb,
      rootId: rootId,
      rootLabel: rootLabel,
      domainId: domainId,
      memberCount: memberCount,
      orbits: orbits,
      planets: moved,
      wisps: wisps,
    );
  }
}

/// 按包、恒星项与视口算出一个恒星系。
///
/// [visibleIds] 是筛选结果（`null` = 不筛）。⚠️ 它只减**画出来的行星**：轨道
/// 数量与相位均分仍按全量算 —— 筛掉一颗不该让其余几颗换个位置（那样同一份数据
/// 在两次筛选里会变成两个恒星系）。
StarSystemLayout layoutStarSystem({
  required LoadedPack pack,
  required String rootId,
  required Size viewport,
  Set<String>? visibleIds,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return StarSystemLayout.empty;
  }
  final Item? root = pack.itemOf(rootId);
  if (root == null) {
    return StarSystemLayout.empty;
  }

  // 同域后继图。跨域边不算 —— 与 `subtreesInDomain()` 口径 1 同一条理由：
  // 把跨域前置算进来会让一个域里的项「没有根」，而这个恒星系的根是给定的。
  final List<Item> inDomain = <Item>[
    for (final Item item in pack.items)
      if (item.domainId == root.domainId) item,
  ];
  if (inDomain.isEmpty) {
    return StarSystemLayout.empty;
  }
  final Set<String> domainIds = <String>{
    for (final Item item in inDomain) item.id,
  };
  final Map<String, List<String>> successors = <String, List<String>>{};
  for (final Edge edge in pack.edges) {
    if (!domainIds.contains(edge.from) || !domainIds.contains(edge.to)) {
      continue;
    }
    successors.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
  }

  // 从恒星出发的 BFS 深度 = 层号。**每项只归一层**（取最短路径），所以一颗
  // 行星不会同时出现在两条轨道上 —— 这是与 `subtreesInDomain()` 那处已知缺口
  // （多前置的项同时属于两棵子树）不同的一点：那里划的是集合，这里定的是位置。
  final Map<String, int> depth = <String, int>{rootId: 0};
  final List<String> queue = <String>[rootId];
  for (int head = 0; head < queue.length; head++) {
    final int next = depth[queue[head]]! + 1;
    for (final String to in successors[queue[head]] ?? const <String>[]) {
      if (depth.containsKey(to)) {
        continue;
      }
      depth[to] = next;
      queue.add(to);
    }
  }
  int maxLevel = 0;
  for (final int level in depth.values) {
    if (level > maxLevel) {
      maxLevel = level;
    }
  }
  if (maxLevel == 0) {
    // 一个后继都没有 —— 孤星。见 [StarSystemLayout.empty] 的说明。
    return StarSystemLayout.empty;
  }

  final Offset center = Offset(viewport.width / 2, viewport.height / 2);
  final double half = math.min(viewport.width, viewport.height) / 2;
  final double starRadius = half * stellarRadiusRatio;

  // ⚠️ `min` / `max` 而不是直接用两个常量：`C-73` 与 `C-74` 写反时画出来是
  // 负半径的圈（不可见），而那种错**不会有任何东西变红**。这里挡一下，代价是
  // 一行。
  final double innerA = half * math.min(stellarOrbitInnerRatio, stellarOrbitOuterRatio);
  final double outerA = half * math.max(stellarOrbitInnerRatio, stellarOrbitOuterRatio);

  // 层号 → 轨道半径：**等分**。真实轨道不是等分的（太阳系相邻比 1.4–3.4），
  // 但等分是可读的那个：层数一多，任何单调映射都会把外侧压成一片。
  final List<StarOrbit> orbits = <StarOrbit>[];
  for (int level = 1; level <= maxLevel; level++) {
    final double t = maxLevel == 1 ? 0 : (level - 1) / (maxLevel - 1);
    final double a = innerA + (outerA - innerA) * t;
    final double e =
        galaxyHash01('$rootId:orbit:$level:e') * stellarOrbitEccentricityMax;
    orbits.add(
      StarOrbit(
        level: level,
        semiMajor: a,
        semiMinor: a * math.sqrt(1 - e * e),
        rotation: galaxyHash01('$rootId:orbit:$level:rot') * fullTurnRadians,
        eccentricity: e,
      ),
    );
  }

  // 同层成员按**包内顺序**分组 —— 均分方位要用一个稳定次序，而 `depth` 是
  // `Map`，遍历顺序虽然在 Dart 里是插入序，但把顺序写在代码里比依赖它强。
  final Map<int, List<String>> byLevel = <int, List<String>>{};
  for (final Item item in inDomain) {
    final int? level = depth[item.id];
    if (level == null || level == 0) {
      continue;
    }
    byLevel.putIfAbsent(level, () => <String>[]).add(item.id);
  }

  final List<StarPlanet> planets = <StarPlanet>[];
  for (int level = 1; level <= maxLevel; level++) {
    final List<String> members = byLevel[level] ?? const <String>[];
    if (members.isEmpty) {
      continue;
    }
    final StarOrbit orbit = orbits[level - 1];
    for (int i = 0; i < members.length; i++) {
      final String id = members[i];
      // 均分 + 一点手抖。抖动的幅度按「该层均分角的 6%」算，所以永远小于
      // 半个间距 —— 同层的两颗不会因为抖动而交叉。
      final double base = i / members.length;
      final double jitter =
          (galaxyHash01('$id:phase') - 0.5) *
          _phaseJitterRatio /
          members.length;
      final double t = (base + jitter) * fullTurnRadians;
      if (visibleIds != null && !visibleIds.contains(id)) {
        continue;
      }
      planets.add(
        StarPlanet(
          id: id,
          level: level,
          // 倾角为 0（共面），所以这里是黄道面上的真实形状，不需要投影。
          center: pointOnOrbit(orbit, t, center),
          // `phase` 存的是**静态**参数角，时钟不进来：推进由 [advanced] 现算。
          // 存成「当前角」的话，同一份布局在两次取用之间会自相矛盾。
          phase: t,
        ),
      );
    }
  }

  // 残余云气：`C-77` 颗，落在恒星 `1.2…4.6` 倍半径之间 —— 不越过内轨
  // （内轨是 `C-73 / C-72 ≈ 5.3` 倍半径），否则云会盖住最里面那颗行星。
  final List<StarWisp> wisps = <StarWisp>[];
  for (int i = 0; i < stellarWispCount; i++) {
    final double h1 = galaxyHash01('$rootId:wisp:$i:a');
    final double h2 = galaxyHash01('$rootId:wisp:$i:b');
    final double r = starRadius * (1.2 + 3.4 * math.sqrt(h1));
    final double theta = h2 * fullTurnRadians;
    wisps.add(
      StarWisp(
        center: Offset(
          center.dx + r * math.cos(theta),
          center.dy + r * math.sin(theta),
        ),
        radius: 1.0 + 2.2 * galaxyHash01('$rootId:wisp:$i:c'),
      ),
    );
  }

  return StarSystemLayout(
    starCenter: center,
    starRadius: starRadius,
    accentArgb: accentArgbOf(pack.space.accent),
    rootId: rootId,
    rootLabel: root.title,
    domainId: root.domainId,
    memberCount: depth.length,
    orbits: orbits,
    planets: planets,
    wisps: wisps,
  );
}

/// 命中的行星；没有则 `null`。
///
/// 命中半径是 **12 px**（`domainMarkMinTapDiameter` 24 的一半，与 `Z1` 域点、
/// `Z2` 亮结同一套），不是绘制半径 2.6 px —— 后者点不中。
StarPlanet? pickStarPlanetAt({
  required StarSystemLayout layout,
  required Offset point,
}) {
  const double hit = domainMarkMinTapDiameter / 2;
  for (final StarPlanet planet in layout.planets) {
    if ((planet.center - point).distance <= hit) {
      return planet;
    }
  }
  return null;
}

/// 点到的位置是不是恒星。
///
/// 取 `max(恒星半径, 12 px)`：恒星半径随视口缩放，小窗口下会掉到 12 以下
/// （400×300 时只有 6.8 px），直接按绘制半径判就成了「看得见、点不中」——
/// 与 `Z1` 域点遇到的是同一个问题。
bool hitsStarAt({
  required StarSystemLayout layout,
  required Offset point,
}) {
  final double hit = math.max(layout.starRadius, domainMarkMinTapDiameter / 2);
  return (layout.starCenter - point).distance <= hit;
}

/// 指针离**最近一颗天体中心**多远（px）—— `C-57` 减速停转的判据输入。
///
/// 恒星也算：它是可点对象（⇒ `Z4`，`VIEW-039`）。用**中心距**而不是「到天体
/// 边缘」不是偷懒 —— 这一档的天体是圆点，绘制半径只有几 px，中心距与边缘距
/// 在 24 px 的停转阈值上差不到一成；而前者不需要为每个天体再取一次半径。
///
/// 轨道不算可点对象：行星在轨道上跑，指针贴在轨道线上时该看到它跑过去。
double distanceToNearestStarBody(StarSystemLayout layout, Offset point) {
  double best = (layout.starCenter - point).distance;
  for (final StarPlanet planet in layout.planets) {
    final double distance = (planet.center - point).distance;
    if (distance < best) {
      best = distance;
    }
  }
  return best;
}
