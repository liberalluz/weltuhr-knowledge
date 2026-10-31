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

/// 一次视角内的完整落位：当前节点、它的来路、它的直接子级。
class UniverseLayout {
  const UniverseLayout({
    required this.current,
    required this.ancestors,
    required this.children,
  });

  /// 当前节点，恒在正前方、仰角 0。
  final SkyPoint current;

  /// 来路，**由近到远**（父在前、根在后）。空表表示当前就是轴根。
  final List<SkyPoint> ancestors;

  /// 直接子级，键为 `Node.id`。同一父的子不撞格（除非超出格数叠放）。
  final Map<String, SkyPoint> children;

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
/// 该值必须 ≥ 骨架里最大的同父子数（实测 105）。小于它时多出来的子会与
/// 同格位的节点叠放在一起 —— 不报错，因为数据侧写多少子不受这里控制，
/// 而「算不出坐标」比「两个点重叠」严重得多。
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
  // 超出格数时取模回卷，与前面的节点叠放（判据要求不报错）。
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
  }

  final List<Node> sorted = List<Node>.of(children)
    ..sort(_byOfficialCodeThenSlug);

  final int childShell = sorted.isEmpty
      ? currentShell
      : shellIndexOf(axis: sorted.first.axis, slot: sorted.first.levelSlot)!;
  final double childRadius = shellRadiusOf(childShell);

  final Map<String, SkyPoint> childPoints = <String, SkyPoint>{};
  for (int i = 0; i < sorted.length; i++) {
    childPoints[sorted[i].id] = childPointOf(index: i, radius: childRadius);
  }

  return UniverseLayout(
    current: SkyPoint(radius: currentRadius, azimuthDeg: 0, elevationDeg: 0),
    ancestors: ancestors,
    children: childPoints,
  );
}

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
