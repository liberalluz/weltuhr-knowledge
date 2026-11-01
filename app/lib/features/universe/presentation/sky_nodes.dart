/// 语义节点的光点层 —— `B17b` 笔 3。
///
/// 落位（`core/universe/placement.dart`）只给坐标，本文件把坐标画成屏幕上的
/// 光点。**画在屏幕层、不进 3D 场景**，与星座连线同一个球心投影：相机在球心，
/// 节点落在半径 8–55 的球壳上，任何一点都在镜头前方 —— 用不着 3D 变换，也就
/// 不增加几何实例。`ADR-0006` 实测几何实例数是当前唯一的渲染负载，这一笔不为
/// 一百来个点去动它。
///
/// **不在这层算坐标**：三组点的 (半径, 方位角, 仰角) 全由 `layoutUniverse`
/// 给出，这里只做「方向向量 → 屏幕像素」。两处各算一套的话，同一个节点在
/// 树里和宇宙里落到不同位置，而两者本该读同一份地址（`SPEC-TREE-007`）。
library;

import 'dart:ui' as ui;

// `Axis` 两边都有（Flutter 的绘制轴 / `core/enums.dart` 的知识轴），要后者。
import 'package:flutter/widgets.dart' hide Axis;

import '../../../core/constants.dart';
import '../../../core/enums.dart';
import '../../../core/universe/placement.dart';
import '../../palette.dart';
import 'constellations.dart';
import 'sky_image.dart';

/// 轴 → 光点颜色。
///
/// 一条路径只走一条轴，所以整幅视图是一种颜色。逐点上色不会画出更丰富的信息，
/// 只会让同一屏看起来像三种东西混在一起。
ui.Color axisNodeColor(Axis axis) => switch (axis) {
  Axis.discipline => paletteAxisDiscipline,
  Axis.major => paletteAxisMajor,
  Axis.occupation => paletteAxisOccupation,
};

/// 落位坐标 → 投影层要的方向向量。
///
/// [SkyProjection.project] 吃的是**星表坐标系**（`x = cos(dec)cos(ra)`、
/// `y = cos(dec)sin(ra)`、`z = sin(dec)`），内部再换成场景轴 `(x, z, y)`；
/// 而落位用的是「方位角 0 = 正前、仰角 0 = 水平」。两者的差就是一个直角
/// （见 `universeSkyAzimuthToRightAscensionDeg`），仰角直接当赤纬用。
///
/// 归一化在这里是白送的：`unitVector` 只认方向、不认半径 —— 球心视角下半径
/// 不改变屏幕位置，只改变遮挡，而屏幕层没有遮挡可言。
Vec3 directionOfSkyPoint(SkyPoint point) => unitVector(
  universeSkyAzimuthToRightAscensionDeg - point.azimuthDeg,
  point.elevationDeg,
);

/// 一层里的点投影成屏幕坐标；落在镜头后方的**剔除**。
///
/// 单独抽出来是为了让「哪些点该出现」可以脱离画布断言：`CustomPainter` 画了
/// 什么没有回读接口，只能在像素上做文章，而像素数会被重叠点骗过去。
List<ui.Offset> screenPointsOf(
  SkyProjection projection,
  Iterable<SkyPoint> points,
) {
  final List<ui.Offset> offsets = <ui.Offset>[];
  for (final SkyPoint point in points) {
    final ui.Offset? offset = projection.project(directionOfSkyPoint(point));
    if (offset != null) {
      offsets.add(offset);
    }
  }
  return offsets;
}

/// 节点光点。每帧重画，不缓存。
class SkyNodesPainter extends CustomPainter {
  SkyNodesPainter({required this.view, required this.universe, super.repaint});

  final SkyView view;

  /// `null` = 这一片天画不出来（树没装载、地址已过期）。空天不等于错误：
  /// 只画星空，不画点。
  final UniverseView? universe;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final UniverseView? universe = this.universe;
    if (universe == null || size.isEmpty) {
      return;
    }
    final SkyProjection projection = SkyProjection(view: view, size: size);
    final ui.Color color = axisNodeColor(universe.axis);

    // 三档分开画，各用一套 paint：光晕的模糊半径与点径同量级，共用一套就
    // 会把小点糊成大点。每档只建两个 paint，不是每个点建一个。
    _paintLayer(
      canvas,
      projection,
      <SkyPoint>[universe.layout.current],
      universeCurrentDotSize,
      color,
    );
    _paintLayer(
      canvas,
      projection,
      universe.layout.ancestors,
      universeAncestorDotSize,
      color,
    );
    _paintLayer(
      canvas,
      projection,
      universe.layout.children.values,
      universeChildDotSize,
      color,
    );
  }

  void _paintLayer(
    ui.Canvas canvas,
    SkyProjection projection,
    Iterable<SkyPoint> points,
    double radius,
    ui.Color color,
  ) {
    final ui.Paint glow = ui.Paint()
      ..color = color.withValues(alpha: universeDotGlowAlpha)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius);
    final ui.Paint core = ui.Paint()
      ..color = color.withValues(alpha: universeDotCoreAlpha);

    for (final ui.Offset center in screenPointsOf(projection, points)) {
      canvas.drawCircle(center, radius * universeDotGlowScale, glow);
      canvas.drawCircle(center, radius * universeDotCoreScale, core);
    }
  }

  /// 恒返回 `true`：相机是**原地改字段**的对象，比较引用永远相等；真正的
  /// 重绘信号来自 `repaint`（每帧递增的计数器），与 [ConstellationPainter] 同理。
  @override
  bool shouldRepaint(covariant SkyNodesPainter oldDelegate) => true;
}
