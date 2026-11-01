/// 语义节点在天球上的落位 —— `B17b` 笔 1。
///
/// 本文件只做**算坐标**，不做渲染：一个节点该落在哪一层球壳、朝哪个方向，
/// 全在这里；怎么画成光点、怎么上色归 `features/universe/`。因此不引 Flutter。
///
/// 三条口径逐条对应裁定：
/// - **半径定层**：槽位在该轴上的序位决定半径，轴根在最内（`kInnermostShellRadius`），
///   越往下越往外。角色轴有五个槽位，正好用满五层；
/// - **方位由父内索引定**：同父的子按官方码排序后落格，位置可由 `path` 复算
///   （`SPEC-TREE-007`：宇宙读树的同一份路径来源，不各算一套）；
/// - **祖先走走廊**：当前路径各级排在球面顶部的一条带里，不占子级的格 ——
///   否则祖先与某个子会投影到同一点，球心视角下半径不影响屏幕位置，只影响遮挡。
library;

import 'dart:math' as math;

import '../constants.dart';
import '../entities/node.dart';
import '../enums.dart';
import '../tree/tree_index.dart';

/// 一个节点在球心视角下的位置。
///
/// 方位角与仰角用**度**，与星表、连线的既有口径一致；半径用世界单位，
/// 星空在 100，五层球壳最外层约 55，仍在天球之内。
class SkyPoint {
  const SkyPoint({
    required this.radius,
    required this.azimuthDeg,
    required this.elevationDeg,
  });

  /// 距球心的距离。同一槽位恒等 —— 层是结构的属性，不是视角的属性。
  final double radius;

  /// 方位角，`−180 .. +180`，0 = 正前。
  final double azimuthDeg;

  /// 仰角，`−90 .. +90`，0 = 水平，+ = 上。
  final double elevationDeg;

  @override
  bool operator ==(Object other) =>
      other is SkyPoint &&
      other.radius == radius &&
      other.azimuthDeg == azimuthDeg &&
      other.elevationDeg == elevationDeg;

  @override
  int get hashCode => Object.hash(radius, azimuthDeg, elevationDeg);

  @override
  String toString() =>
      'SkyPoint(r=${radius.toStringAsFixed(skyPointDecimalPlaces)}, '
      'az=${azimuthDeg.toStringAsFixed(skyPointDecimalPlaces)}°, '
      'el=${elevationDeg.toStringAsFixed(skyPointDecimalPlaces)}°)';
}

/// 子级超出格位后合并成的一个聚合点 —— `B17b` 笔 6。
///
/// 格位只有 [universeChildCellCount] 个（12 × 10），超出部分原先由
/// [childPointOf] 取模回卷、与前面的节点**静默叠放**：两个点画在同一位置，
/// 看起来像渲染错误。改成合并之后，那个位置有了语义 —— 「还有 N 项没画」。
class SkyAggregate {
  const SkyAggregate({required this.point, required this.memberIds});

  /// 聚合点自己的位置，固定占网格最后一格。
  final SkyPoint point;

  /// 被合并进来的子级 id，按官方码排序后的末尾一段，顺序即落格顺序。
  ///
  /// 留这张表而不是只留个数：亮度要按成员求均值（笔 6 的口径），
  /// 只给个数就得让绘制层反查排序，等于把落位规则复制一份。
  final List<String> memberIds;

  int get count => memberIds.length;

  @override
  bool operator ==(Object other) {
    if (other is! SkyAggregate || other.point != point) {
      return false;
    }
    if (other.memberIds.length != memberIds.length) {
      return false;
    }
    // 逐位比：成员顺序有意义（官方码排序），不按集合比。
    for (int i = 0; i < memberIds.length; i++) {
      if (other.memberIds[i] != memberIds[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[point, ...memberIds]);
}

/// 一次视角内的完整落位：当前节点、它的来路、它的直接子级。
class UniverseLayout {
  const UniverseLayout({
    required this.current,
    required this.ancestors,
    required this.ancestorIds,
    required this.children,
    // 有默认值：名字只对标注层有意义，而落位用例与光点用例构造布局时并不
    // 关心文字。给默认值让它们不必逐个补一个空表 —— 但那不等于「名字可选」，
    // `layoutUniverse` 产出的布局里这张表总是齐的。
    this.names = const <String, String>{},
    // 有默认值：绝大多数视角的子级数远小于格位数（实测中位 4、最大 105），
    // 聚合只在极端父节点上出现。给默认值让它们不必逐个补 `null`。
    this.aggregate,
  });

  /// 当前节点，恒在正前方、仰角 0。
  final SkyPoint current;

  /// 来路，**由近到远**（父在前、根在后）。空表表示当前就是轴根。
  final List<SkyPoint> ancestors;

  /// 与 [ancestors] **逐位对齐**的节点 id。
  ///
  /// 坐标只回答「画在哪」，答不了「这是谁」；而亮度、标注这些都要按 id 查
  /// （`B17b` 笔 4 起）。单列一张对齐表而不是把 id 塞进 `SkyPoint`：那个类
  /// 是纯几何值、会被落位用例直接比较，掺进身份字段之后连「两个点重不重合」
  /// 这种判据都得先决定要不要比 id。
  final List<String> ancestorIds;

  /// 直接子级，键为 `Node.id`。同一父的子不撞格（除非超出格数叠放）。
  final Map<String, SkyPoint> children;

  /// 本视角内全部点的 id → 名字，当前、来路、子级三组都在这一张表里。
  ///
  /// 与 [ancestorIds] 同一类东西 —— 坐标答「画在哪」，名字答「这是谁」。
  /// 合成一张表而不是三张（`currentName` / `ancestorNames` / `childNames`）：
  /// 标注层要的是「给我这个 id 的字」，按 id 查一次比按组判断三次省事，
  /// 也不会出现同一个 id 在两张表里名字不一致。
  final Map<String, String> names;

  /// 子级超出格位时合并出的那一个点；未超出时为 `null`。
  ///
  /// **它不在 [children] 里**，也不是任何节点的坐标 —— 它是「剩下这些没画」
  /// 这一件事的表示。因此标注层遍历 `children` 时天然看不到它，不需要额外
  /// 判断「这不是真节点」。
  final SkyAggregate? aggregate;

  /// 本视角内的全部点（当前 + 来路 + 子级），供渲染层直接遍历。
  List<SkyPoint> get all => <SkyPoint>[
    current,
    ...ancestors,
    ...children.values,
  ];
}

/// 某条轴上槽位自上而下的顺序 —— **层序即序号**。
///
/// 不读 `kAxisDepth`：那张表记的是「用得上几层」，与此处「第几个槽位」不是
/// 同一个量，`discipline` 有 3 个槽位而表里写 4，两者对不上。这里的顺序直接
/// 来自 `legalSkeletonSlots` 的合法组合，按树的深度排列，是唯一的。
const Map<Axis, List<LevelSlot>> _slotOrderByAxis = <Axis, List<LevelSlot>>{
  Axis.discipline: <LevelSlot>[
    LevelSlot.supercluster,
    LevelSlot.group,
    LevelSlot.star,
  ],
  Axis.major: <LevelSlot>[
    LevelSlot.supercluster,
    LevelSlot.group,
    LevelSlot.galaxy,
    LevelSlot.star,
  ],
  Axis.occupation: <LevelSlot>[
    LevelSlot.supercluster,
    LevelSlot.group,
    LevelSlot.galaxy,
    LevelSlot.cluster,
    LevelSlot.star,
  ],
};

/// 槽位在该轴上的层序（0 = 轴根在最内）。
///
/// 返回 `null` 表示这个组合在该轴上不存在 —— 调用方按「该节点不该出现在
/// 宇宙视图里」处置，不静默给个位置。给了位置就等于承认 `galaxy` 能挂在
/// 学科轴上，而那与 `legalSkeletonSlots` 直接冲突。
int? shellIndexOf({required Axis axis, required LevelSlot slot}) {
  final List<LevelSlot> order = _slotOrderByAxis[axis]!;
  final int index = order.indexOf(slot);
  return index < 0 ? null : index;
}

/// 层序对应的球壳半径，内到外。
double shellRadiusOf(int shellIndex) =>
    universeShellInnermostRadius *
    math.pow(universeShellRadiusRatio, shellIndex).toDouble();

/// 子级的格子总数 = 列 × 行。
///
/// 该值必须 ≥ 骨架里最大的同父子数（实测 105）。**超出时不再叠放**：
/// 自 `B17b` 笔 6 起，`layoutUniverse` 留最后一格画聚合点，其余子级并进
/// 那一个点（见 [SkyAggregate]）—— 原先取模回卷会静默画出两个重合的点。
int get universeChildCellCount => universeSkyGridColumns * universeSkyGridRows;

/// 子级第 [index] 个（0 起，按官方码排序后）落在格心。
///
/// 行的顺序是**自下而上**：第 0 行在视野最低处，往上排。这样官方码靠前的
/// 在下方 —— 与树里「同级的上一行在前」一致，两处读起来不会互相打架。
SkyPoint childPointOf({required int index, required double radius}) {
  const int columns = universeSkyGridColumns;
  const int rows = universeSkyGridRows;
  final int column = index % columns;
  final int row = index ~/ columns;
  // 超出格数时取模回卷。`layoutUniverse` 自笔 6 起**不会**再让索引进到这个
  // 区间（超出的子级并成聚合点），但本函数是可以被单独调用的纯函数 ——
  // 给一个确定的位置，好过抛错。
  final int wrappedRow = row % rows;
  // 相对位置各归一化到 −0.5..+0.5，再乘各自的跨度 —— 这样既不用写
  // 360 / 180 / 2 这几个字面量，也不会把「半格」的含义散成几处。
  final double columnFraction =
      (column + universeCellCenterOffset) / columns - universeCellCenterOffset;
  final double rowFraction =
      (wrappedRow + universeCellCenterOffset) / rows - universeCellCenterOffset;
  return SkyPoint(
    radius: radius,
    azimuthDeg: columnFraction * universeFullTurnDeg,
    elevationDeg: rowFraction * universeChildElevationSpanDeg,
  );
}

/// 来路第 [depth] 级（0 = 当前节点的父）在走廊里的仰角。
///
/// 走廊占球面顶部 `universeAncestorCorridorDeg`，按 `universeShellCount + 1`
/// 等分 —— 分母取「最多能有几级祖先」+1，让最远那级不会顶到 90° 的天顶
/// （顶到之后方位角失去意义，所有祖先会挤成一个点）。
double ancestorElevationOf(int depth) =>
    universeChildElevationSpanDeg * universeCellCenterOffset +
    (depth + 1) / (universeShellCount + 1) * universeAncestorCorridorDeg;

/// 算一次视角内的落位。
///
/// [path] 是从轴根到当前节点的路径（含当前节点，末位即当前）。[children]
/// 是当前节点的直接子级，顺序不限 —— 这里按官方码重排。
///
/// 三个前置不满足时抛 [ArgumentError] 而不是给个近似值：
/// - `path` 为空；
/// - `path` 首节点不是轴根（`supercluster`）—— 那说明调用方给了半条路径；
/// - `children` 里有节点的 `path` 父不是 `path` 末位 —— 那是别的节点的子，
///   放进来会让两组子抢同一批格子。
UniverseLayout layoutUniverse({
  required List<Node> path,
  required List<Node> children,
}) {
  if (path.isEmpty) {
    throw ArgumentError.value(path, 'path', '当前路径不能为空');
  }
  final Node current = path.last;
  if (current.levelSlot != LevelSlot.supercluster && path.length == 1) {
    throw ArgumentError.value(
      current.id,
      'path',
      '路径只有一级时该级必须是轴根（supercluster），实为 ${current.levelSlot.name}',
    );
  }

  final int currentShell = shellIndexOf(
    axis: current.axis,
    slot: current.levelSlot,
  )!;
  final double currentRadius = shellRadiusOf(currentShell);

  // 来路由近到远：path 去掉末位后倒序。
  final List<SkyPoint> ancestors = <SkyPoint>[];
  final List<String> ancestorIds = <String>[];
  final List<Node> ancestorsPath = path
      .sublist(0, path.length - 1)
      .reversed
      .toList();
  for (final Node node in ancestorsPath) {
    final int shell = shellIndexOf(axis: node.axis, slot: node.levelSlot)!;
    ancestors.add(
      SkyPoint(
        radius: shellRadiusOf(shell),
        azimuthDeg: 0,
        elevationDeg: ancestorElevationOf(ancestors.length),
      ),
    );
    ancestorIds.add(node.id);
  }

  final List<Node> sorted = List<Node>.of(children)
    ..sort(_byOfficialCodeThenSlug);

  final int childShell = sorted.isEmpty
      ? currentShell
      : shellIndexOf(axis: sorted.first.axis, slot: sorted.first.levelSlot)!;
  final double childRadius = shellRadiusOf(childShell);

  // 格位不够时留最后一格给聚合点：前（格数 − 1）个正常落格，其余并成一个。
  // 判据是**严格超过**格位数 —— 正好用满 120 个时不聚合、不出「+0」，
  // 因为那 120 个本来就都画得下。
  final int capacity = universeChildCellCount;
  final bool overflow = sorted.length > capacity;
  final int cellPlaced = overflow ? capacity - 1 : sorted.length;

  final Map<String, SkyPoint> childPoints = <String, SkyPoint>{};
  for (int i = 0; i < cellPlaced; i++) {
    childPoints[sorted[i].id] = childPointOf(index: i, radius: childRadius);
  }

  SkyAggregate? aggregate;
  if (overflow) {
    aggregate = SkyAggregate(
      point: childPointOf(index: capacity - 1, radius: childRadius),
      memberIds: <String>[
        for (int i = cellPlaced; i < sorted.length; i++) sorted[i].id,
      ],
    );
  }

  return UniverseLayout(
    current: SkyPoint(radius: currentRadius, azimuthDeg: 0, elevationDeg: 0),
    ancestors: ancestors,
    ancestorIds: ancestorIds,
    children: childPoints,
    // 名字只从传进来的节点取，不去查树 —— 落位模块不认识 `TreeIndex`，
    // 一旦在这里反查，它就同时依赖树与坐标两份事实源。
    //
    // 只收落位了的子级：被并进聚合点的那些没有自己的点，也就不该有自己的
    // 名字 —— 否则标注层拿着一张更宽的名字表，迟早会给一个不存在的点标字。
    names: <String, String>{
      for (final Node node in path) node.id: node.name,
      for (final Node node in sorted.take(cellPlaced)) node.id: node.name,
    },
    aggregate: aggregate,
  );
}

/// 一次宇宙视角的完整结果：落位 + 轴 + **实际落位的是哪个节点**。
class UniverseView {
  const UniverseView({
    required this.layout,
    required this.axis,
    required this.anchorId,
  });

  /// 当前节点、来路、直接子级的坐标。
  final UniverseLayout layout;

  /// 整幅视图取这一条轴的颜色。
  ///
  /// 一条路径只走一条轴（`SPEC-TREE-007`），所以「按节点取色」与「按视图取色」
  /// 是同一件事 —— 不必逐点上色，也就不会出现同一屏三种颜色的情形。
  final Axis axis;

  /// 实际落位的节点 id。
  ///
  /// **不保证等于调用方给的地址**：载荷节点（`system` / `planet`）没有球壳可上
  /// （`legalSkeletonSlots` 里不存在这两个槽位），此时取最近的、能上球的祖先。
  /// 把这件事写在一个字段里而不是让调用方去反推：界面上要说「你在哪一片天」，
  /// 说的就是这个 id。
  final String anchorId;
}

/// 从树与当前地址算出宇宙视角；算不出时返回 `null`。
///
/// 三个 `null` 出口，都是「这一片天画不出来」，不是错误：
/// - 树里没有这个 id（骨架未装载、地址过期）；
/// - 整条来路里没有一个能上球的节点（连轴根都不在）；
/// - 来路成环（坏数据，`TreeIndex.build` 已挡过，这里兜底不递归）。
///
/// ⚠️ **只画骨架**：载荷节点（`system` / `planet`）既不做当前节点、也不进
/// 子级列表。宇宙是骨架的全景（3,375 个节点），载荷属于某个包、不属于骨架，
/// 混进来会让同一屏出现「有球壳的」和「没球壳的」两类点。
UniverseView? layoutOfNode(TreeIndex tree, String nodeId) {
  // 走上来时是「当前 → 根」，翻成「根 → 当前」：落位要的是自顶向下的路径。
  final List<Node> chain = <Node>[];
  final Set<String> seen = <String>{};
  String? cursor = nodeId;
  while (cursor != null) {
    if (!seen.add(cursor)) {
      return null;
    }
    final Node? node = tree.nodeOf(cursor);
    if (node == null) {
      return null;
    }
    chain.add(node);
    cursor = tree.parents.mainParentOf(cursor);
  }
  final List<Node> topDown = chain.reversed.toList(growable: false);

  // 从当前节点往上找第一个能上球的 —— 载荷叶子先落到它挂靠的骨架星上。
  int anchorIndex = -1;
  for (int i = topDown.length - 1; i >= 0; i--) {
    if (_canOccupyShell(topDown[i])) {
      anchorIndex = i;
      break;
    }
  }
  if (anchorIndex < 0) {
    return null;
  }
  final List<Node> path = topDown.sublist(0, anchorIndex + 1);
  final Node anchor = path.last;
  if (path.first.levelSlot != LevelSlot.supercluster) {
    return null;
  }

  final List<Node> children = <Node>[];
  for (final TreeRow row in tree.childrenOf(anchor.id)) {
    final Node? child = tree.nodeOf(row.nodeId);
    if (child != null && _canOccupyShell(child)) {
      children.add(child);
    }
  }

  return UniverseView(
    layout: layoutUniverse(path: path, children: children),
    axis: anchor.axis,
    anchorId: anchor.id,
  );
}

/// 该节点在这条轴上有没有球壳可上。
///
/// 判据就是 [`shellIndexOf`] 能不能给出层序 —— 与 [`layoutUniverse`] 内部
/// `!` 所依赖的是同一个事实，所以过滤过的节点再交给它必不抛。
bool _canOccupyShell(Node node) =>
    shellIndexOf(axis: node.axis, slot: node.levelSlot) != null;

/// 排序键：官方码优先、`slug` 兜底。
///
/// 官方码可空（`S4` 自建、载荷行星系与行星都没有码）。空码排在同层的末尾，
/// 而不是排在最前 —— 排最前会让「无码的项」占住球面最低处那一片，
/// 而那片正是视线最容易落到的地方。
int _byOfficialCodeThenSlug(Node a, Node b) {
  final String codeA = a.officialCode ?? '\u{10FFFF}';
  final String codeB = b.officialCode ?? '\u{10FFFF}';
  final int byCode = codeA.compareTo(codeB);
  return byCode != 0 ? byCode : a.slug.compareTo(b.slug);
}
