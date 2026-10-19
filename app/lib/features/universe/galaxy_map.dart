/// `Z0` 宇宙层的几何 —— **一个 `KnowledgeSpace` 一个星系**（`SPEC-VIEW-036`）。
///
/// ## 为什么单独一层
///
/// `Z1` 起画的是「某个空间内部」：项、边、域带，走 `FramePainter` 那一套投影。
/// `Z0` 画的是**空间之间**：没有项、没有边，只有 N 个盘。两者共用一套投影会
/// 逼着把「盘」伪装成一个节点 —— 于是盘半径、遮挡、命中全都要在节点语义之外
/// 再挂一批字段，而节点的每条通道（`r` / `θ` / `φ` / 大小 / 虚实 / 颜色）都已经
/// 名花有主（`ADR-0003`）。所以 `Z0` 自带一套几何，与项场景各管各的。
///
/// 这一层是**纯计算**：给根列表与视口，返回盘的位置与半径。绘制与拾取都读它，
/// 于是「看得见的盘」与「点得中的盘」必然同一个数（同 `SceneFrame` 的理由）。
///
/// ## 尺寸：比值有意义，绝对值没有
///
/// `r_i = k · √n_i`（`VIEW-036`）。承载的是**比值** —— 80 项与 150 项的星系要
/// 看得出谁大。`k` 由视口反解（见 [layoutGalaxies]），`clamp` 加在 `k` 上、
/// 不加在 `r_i` 上：加在 `r_i` 上会让 80 与 150 在高分屏下同时撞上限 ⇒ 比值
/// 变 1:1，语义静默丢失。
///
/// ## 确定性
///
/// 成团构型由 `space.id` 的**哈希**定，不用随机数 —— 随机数会让每次打开像换了
/// 一批包。哈希用 FNV-1a 自己算，不用 `String.hashCode`：后者在同一进程内稳定，
/// 但不承诺跨版本稳定，而「同一输入连开两次坐标相等」这条判据要跨会话成立。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/constants.dart';
import 'scene_source.dart';

/// 一个星系盘。坐标是**画布坐标**（原点在画布左上），半径单位 px。
class GalaxyDisc {
  const GalaxyDisc({
    required this.spaceId,
    required this.label,
    required this.itemCount,
    required this.domainCount,
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.argb,
    required this.depth,
    required this.occluded,
  });

  final String spaceId;

  /// 标注主行 = `space.id` 首字母大写（`VIEW-036` 的标注口径）。
  final String label;

  final int itemCount;
  final int domainCount;

  final double centerX;
  final double centerY;

  /// 盘半径 = 椭圆半长轴。项多的大、项少的小。
  final double radius;

  /// 盘色，取自空间自己的 `accent`（包下发的真实数据），解析失败落回调色板。
  final int argb;

  /// 绘制序：0 = 最近（主星系）。越大越靠后、越可能被遮。
  final int depth;

  /// 是否被前面的盘遮住。**被遮才描边**（`VIEW-036`：完全挡住等于
  /// 「以为没有这个空间」）。未被遮的不描 —— 每个盘都描边会让轮廓失去信息量。
  final bool occluded;

  /// 椭圆的半短轴：盘倾斜 `C-59` 之后在屏幕上被压扁。
  ///
  /// 倾角是**常量**（`C-59` 只是初值，手势可改的那一笔在 `V-1i` 之后），
  /// 所以这里现算而不用字段：多存一份就多一处能跟常量不一致的地方。
  double get minorRadius => radius * _tiltCosOf(galaxyDiscTiltDeg);

  Offset get center => Offset(centerX, centerY);

  /// 只换遮挡标记的一份拷贝。`layoutGalaxies` 与 [GalaxyLayout.spun] 都要
  /// 「算完一轮再回填遮挡」，两处各手抄一遍十个字段的话，日后加一个字段就有
  /// 一处会漏（`R-08` 同族：漏了也画得出来，只是那条通道静默失效）。
  GalaxyDisc withOccluded(bool value) => occluded == value
      ? this
      : GalaxyDisc(
          spaceId: spaceId,
          label: label,
          itemCount: itemCount,
          domainCount: domainCount,
          centerX: centerX,
          centerY: centerY,
          radius: radius,
          argb: argb,
          depth: depth,
          occluded: value,
        );

  /// 搬到新落点的一份拷贝。半径、色、深度都不变 —— 公转不动盘本身。
  GalaxyDisc withCenter(Offset at) => at.dx == centerX && at.dy == centerY
      ? this
      : GalaxyDisc(
          spaceId: spaceId,
          label: label,
          itemCount: itemCount,
          domainCount: domainCount,
          centerX: at.dx,
          centerY: at.dy,
          radius: radius,
          argb: argb,
          depth: depth,
          occluded: occluded,
        );
}

double _tiltCosOf(double degrees) => math.cos(degrees * math.pi / 180);

/// 一次 `Z0` 布局的结果。
class GalaxyLayout {
  const GalaxyLayout({
    required this.discs,
    required this.degenerate,
    required this.orbitCenter,
  });

  /// 没有可画的根（一个包都没装出来）。界面据此保留诊断行、不画空盘子。
  static const GalaxyLayout empty = GalaxyLayout(
    discs: <GalaxyDisc>[],
    degenerate: false,
    orbitCenter: Offset.zero,
  );

  /// 绘制序：近 → 远。
  final List<GalaxyDisc> discs;

  /// `k` 触底（`C-53`）⇒ 该判「`Z0` 退化为列表式」并按降级处理。
  ///
  /// 这是**可计算的判据，不是「挤了再说」**（`VIEW-036`）：盘半径下限 40 px
  /// 反解出 `k` 的下限，视口给出的 `k` 低于它就说明这个包数下画不出星系。
  final bool degenerate;

  /// 构型公转（`C-55`）绕的那个点 —— 就是视口中心。
  ///
  /// 存下来而不是让 [spun] 自己再算一遍 `viewport / 2`：那一来得把视口也带进
  /// 布局，而布局的每个消费者（绘制 / 拾取 / 标注）都不需要视口 —— 它们只
  /// 需要「盘在哪」。
  final Offset orbitCenter;

  bool get isEmpty => discs.isEmpty;

  /// 构型公转 [radians]（`C-55`）之后的一份布局。
  ///
  /// **绕 [orbitCenter] 整体转**，不是各盘自转 —— 主星系（`depth == 0`）固定
  /// 在视口中心，矮星系绕着它走。这正是 `C-54` 在 `Z0` 不可观测的那件事：
  /// 盘本身只有一枚椭圆，转它看不出任何区别（`constants.md` 的 `C-54` 注）。
  ///
  /// ⚠️ **y 要先按 `C-59` 拉回正圆再转、转完压回去**：倾斜盘投影成椭圆，
  /// 直接按屏幕坐标转会让矮星系在竖直方向上「跑得比横向快」—— 公转轨道变成
  /// 一个侧躺的 8 字，而不是同一条椭圆。
  ///
  /// ⚠️ **遮挡标记不重判**：这是绕 [orbitCenter] 的刚体旋转，盘与盘的相对位置
  /// 一点没变 ⇒ 谁挡谁逐字相同。重判一遍会得到同样的结果，只是每帧多花 `n²`
  /// 次比较（`R13` 第 7 条同一条理由：空转的成本是满的，收益是零）。
  ///
  /// 依赖的前提写在这里：**整组一起转**。若日后改成「各盘按自己的周期公转」，
  /// 前提就不成立，那时必须回来补一次重判 —— 而画面上不会有任何东西变红，只有
  /// 描边会指向错的那个盘。
  GalaxyLayout spun(double radians) {
    if (radians == 0 || !radians.isFinite || discs.length < 2) {
      return this;
    }
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    final double tiltCos = _tiltCosOf(galaxyDiscTiltDeg);

    Offset orbit(Offset point) {
      final double dx = point.dx - orbitCenter.dx;
      final double dy = (point.dy - orbitCenter.dy) / tiltCos;
      return Offset(
        orbitCenter.dx + dx * c - dy * s,
        orbitCenter.dy + (dx * s + dy * c) * tiltCos,
      );
    }

    return GalaxyLayout(
      discs: <GalaxyDisc>[
        for (final GalaxyDisc disc in discs)
          // 主星系钉在构型中心：公转的是「别的小星系绕它」。
          disc.depth == 0 ? disc : disc.withCenter(orbit(disc.center)),
      ],
      degenerate: degenerate,
      orbitCenter: orbitCenter,
    );
  }

  GalaxyDisc? discOf(String spaceId) {
    for (final GalaxyDisc disc in discs) {
      if (disc.spaceId == spaceId) {
        return disc;
      }
    }
    return null;
  }
}

/// 按根列表与视口算出 `Z0` 的星系布局。
///
/// 只认**装了包**的根：合成回落没有 `KnowledgeSpace`，也就没有名字与项数 ——
/// 给它编一个星系等于凭空造一个空间（`SPEC-FND-014` 未声明即不渲染）。
GalaxyLayout layoutGalaxies({
  required List<SceneResolution> roots,
  required Size viewport,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return GalaxyLayout.empty;
  }
  final List<SceneResolution> usable = <SceneResolution>[
    for (final SceneResolution root in roots)
      if (root.pack != null) root,
  ];
  if (usable.isEmpty) {
    return GalaxyLayout.empty;
  }

  // 与 `resolveAllScenes` 同序（`order`，再 `id`）：两处排序不同的话，
  // 「第 i 个星系」在两次启动里会指到不同的空间，而界面上看不出来。
  usable.sort((SceneResolution a, SceneResolution b) {
    final int orderA = a.pack!.space.order;
    final int orderB = b.pack!.space.order;
    return orderA == orderB
        ? a.pack!.space.id.compareTo(b.pack!.space.id)
        : orderA.compareTo(orderB);
  });

  int nMax = 0;
  int nMin = 0;
  for (int i = 0; i < usable.length; i++) {
    final int n = usable[i].pack!.items.length;
    if (i == 0 || n > nMax) {
      nMax = n;
    }
    if (i == 0 || n < nMin) {
      nMin = n;
    }
  }
  // 空包（0 项）会让 `√nMin = 0`。给 1 而不是跳过它：那个空间确实存在、
  // 只是没有内容，画成一个最小的盘比让它从 `Z0` 消失更诚实。
  nMax = nMax < 1 ? 1 : nMax;
  nMin = nMin < 1 ? 1 : nMin;

  final double short = math.min(viewport.width, viewport.height);
  final double clusterR = z0OrbitRadiusRatio * short;

  // `k` 由「**最大盘的直径 = 构型分布半径**」定：主星系铺到矮星系所在的那一圈
  // 为止，尺寸关系就全部由 `C-52` 与 `√n` 决定了，不需要再补一条观感常数。
  //
  // ⚠️ 这里**不按包数摊薄** `k`：试过 `clusterR / (2·√(Σn))` 那种面积守恒的
  // 写法，在 `C-52 = 0.30` 下三个包就会让矮星系撞上 `C-53` 直接判退化 ——
  // 那是把「常数取小了」伪装成「画不出来」。包数多时的挤压由**重叠 + 描边**
  // 承担（`VIEW-036` 明确允许遮挡），不是靠把每个盘缩小。
  final double kFit = clusterR / (2 * math.sqrt(nMax));
  // `C-53` 反解出的 `k` 下限 —— clamp 加在 `k` 上，不加在 `r_i` 上。
  final double kMin = spacePlateMinRadiusPx / math.sqrt(nMin);
  final bool degenerate = kFit < kMin;
  final double k = degenerate ? kMin : kFit;

  final double cx = viewport.width / 2;
  final double cy = viewport.height / 2;
  final double tiltCos = _tiltCosOf(galaxyDiscTiltDeg);

  // 主星系 = 项数最多的那个（并列按 `order` 已在上面定序）居中，其余偏居。
  int mainIndex = 0;
  for (int i = 1; i < usable.length; i++) {
    if (usable[i].pack!.items.length > usable[mainIndex].pack!.items.length) {
      mainIndex = i;
    }
  }

  final List<int> order = <int>[mainIndex];
  for (int i = 0; i < usable.length; i++) {
    if (i != mainIndex) {
      order.add(i);
    }
  }
  // 矮星系从大到小：先画大的，小的压在后面 —— 与「主星系在前」同一套深度语义。
  final List<int> dwarfs = order.sublist(1)
    ..sort((int a, int b) {
      final int na = usable[a].pack!.items.length;
      final int nb = usable[b].pack!.items.length;
      return na == nb
          ? usable[a].pack!.space.id.compareTo(usable[b].pack!.space.id)
          : nb.compareTo(na);
    });
  final List<int> drawOrder = <int>[order.first, ...dwarfs];

  final List<GalaxyDisc> discs = <GalaxyDisc>[];
  final List<bool> occluded = <bool>[];
  for (int depth = 0; depth < drawOrder.length; depth++) {
    final SceneResolution root = usable[drawOrder[depth]];
    final int n = root.pack!.items.length;
    final String id = root.pack!.space.id;

    double x = cx;
    double y = cy;
    if (depth > 0) {
      // 角度由 `space.id` 哈希定；距离就取构型分布半径 —— 再乘一个系数就得
      // 往常量表加一条观感参数，而它现在还没有对应项（`VIEW-036` 只给了半径）。
      final double angle = galaxyHash01('$id:angle') * fullTurnRadians;
      x = cx + math.cos(angle) * clusterR;
      // 落点跟着盘一起被压扁：不均分圆、也不落在同一水平线上。
      y = cy + math.sin(angle) * clusterR * tiltCos;
    }

    final double radius = k * math.sqrt(n < 1 ? 1 : n);
    discs.add(
      GalaxyDisc(
        spaceId: id,
        label: spaceLabel(id),
        itemCount: n,
        domainCount: root.pack!.space.domainIds.length,
        centerX: x,
        centerY: y,
        radius: radius,
        argb: accentArgbOf(root.pack!.space.accent, fallbackIndex: depth),
        depth: depth,
        // 先占位，画完一轮再统一判遮挡 —— 遮挡要跟**全部**前序盘比。
        occluded: false,
      ),
    );
    occluded.add(false);
  }

  for (int i = 1; i < discs.length; i++) {
    occluded[i] = _isOccludedAt(discs, i, tiltCos);
  }

  return GalaxyLayout(
    discs: <GalaxyDisc>[
      for (int i = 0; i < discs.length; i++)
        discs[i].withOccluded(occluded[i]),
    ],
    degenerate: degenerate,
    orbitCenter: Offset(cx, cy),
  );
}

/// 第 [index] 个盘是否被**前面画过的**盘遮住（`VIEW-036`：被遮须描边）。
///
/// 用椭圆近似判重叠：把纵向按倾角拉回正圆再比圆心距。拉回这一步不能省 ——
/// 压扁之后两个竖直排列的盘看起来分得很开，实际在同一块平面上贴着。
bool _isOccludedAt(List<GalaxyDisc> discs, int index, double tiltCos) {
  final GalaxyDisc self = discs[index];
  for (int i = 0; i < index; i++) {
    final GalaxyDisc other = discs[i];
    final double dx = other.centerX - self.centerX;
    final double dy = (other.centerY - self.centerY) / tiltCos;
    if (math.sqrt(dx * dx + dy * dy) < other.radius + self.radius) {
      return true;
    }
  }
  return false;
}

/// 点 [point] 命中的星系。`null` = 点空了。
///
/// 按**绘制序**（近 → 远）取第一个命中的：重叠区点中前面那个是可接受的
/// （`VIEW-036`），点不中任何一个才是不可接受的 —— 所以还有一个命中半径下限。
String? pickGalaxyAt({required GalaxyLayout layout, required Offset point}) {
  // 命中半径的下限：盘半径由 `C-53` 兜底（≥ 40 px），这一条只在退化情形生效
  // —— 盘画得出、点不中时，用户只会以为「这一档不支持点击」。
  const double floor = galaxyMinTapDiameter / 2;
  for (final GalaxyDisc disc in layout.discs) {
    final double rx = math.max(disc.radius, floor);
    final double ry = math.max(disc.minorRadius, floor);
    final double nx = (point.dx - disc.centerX) / rx;
    final double ny = (point.dy - disc.centerY) / ry;
    if (nx * nx + ny * ny <= 1) {
      return disc.spaceId;
    }
  }
  return null;
}

/// 指针离**最近一个星系盘边缘**多远（px）—— `C-57` 减速停转的判据输入。
///
/// 盘内返回负值：`governorFactor` 只会拿它和两个正阈值比，负数一律读作「贴住了」
/// ⇒ 停转。这不是取巧 —— 盘本身就是可点对象，指针压在盘上时它必须停。
///
/// 用「归一化半径减一，再乘短半轴」而不是精确的椭圆点距：精确解要解四次方程，
/// 而这里只需要一个**单调、过零位置正确**的量。短半轴那一乘是为了让压扁后的盘
/// 上下方向不会被读成「比左右更近」。
double distanceToNearestGalaxy(GalaxyLayout layout, Offset point) {
  const double floor = galaxyMinTapDiameter / 2;
  double best = double.infinity;
  for (final GalaxyDisc disc in layout.discs) {
    final double rx = math.max(disc.radius, floor);
    final double ry = math.max(disc.minorRadius, floor);
    final double nx = (point.dx - disc.centerX) / rx;
    final double ny = (point.dy - disc.centerY) / ry;
    final double distance = (math.sqrt(nx * nx + ny * ny) - 1) *
        math.min(rx, ry);
    if (distance < best) {
      best = distance;
    }
  }
  return best;
}

/// 空间的显示名：`space.id` 首字母大写（`VIEW-036` 的标注口径）。
///
/// 不用 `space.name`：三个包的 `name` 是「Python 语法分层」这种长度，盘下方的
/// 两行标注放不下，而 id 就是包目录名 —— 用户核对得上的也正是它。
String spaceLabel(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// FNV-1a 32 位。**不用 `String.hashCode`**：后者不承诺跨版本稳定，而
/// 「同一输入连开两次星系中心坐标逐分量相等」这条判据要跨会话成立。
int galaxyHash(String key) {
  int hash = 0x811c9dc5;
  for (final int unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// [galaxyHash] 归一到 `[0, 1)`。
double galaxyHash01(String key) => (galaxyHash(key) & 0xffffff) / 0x1000000;

/// 盘色：优先用包下发的 `accent`（`#RRGGBB`），解析不出来才按序号取调色板。
///
/// 用 `accent` 而不是写死一张表：每个空间自己的强调色是**真实数据**，换一个
/// 包就换一套颜色；写死的表在第二个包上就会撞色。
///
/// `Z1` 的盘面（`spiral_map.dart`）共用这一个解析 —— 同一个空间在 `Z0` 与
/// `Z1` 必须是同一个颜色，否则「进门」会看起来像换了个空间。
int accentArgbOf(String accent, {int fallbackIndex = 0}) {
  final String hex = accent.startsWith('#') ? accent.substring(1) : accent;
  if (hex.length == 6) {
    final int? value = int.tryParse(hex, radix: 16);
    if (value != null) {
      return 0xFF000000 | value;
    }
  }
  return _fallbackPalette[fallbackIndex % _fallbackPalette.length];
}

/// `accent` 缺失或写坏时的兜底色 —— 只求能分辨，不求好看。
const List<int> _fallbackPalette = <int>[
  0xFF6E63D8,
  0xFF2FB3A0,
  0xFFE0913C,
  0xFF4A8FE0,
  0xFFC85894,
];
