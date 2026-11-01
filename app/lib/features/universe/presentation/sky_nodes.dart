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

/// 亮度 → 分档序号（0..`universeBrightnessSteps` − 1）。
///
/// 分档而不是逐点用原值，是为了让 paint 能复用；档数本身是常量
/// （`C-145`），改档数不会改变「谁比谁亮」这个顺序。
int brightnessStepOf(double brightness) {
  final double clamped = brightness.clamp(0, 1);
  return (clamped * (universeBrightnessSteps - 1)).round();
}

/// 某一档对应的不透明度系数（`C-143` 下限之上线性铺开）。
double alphaFactorOfStep(int step) {
  final double ratio = step / (universeBrightnessSteps - 1);
  return universeBrightnessFloor + (1 - universeBrightnessFloor) * ratio;
}

/// 聚合点的不透明度系数（0..1）：取被合并子级亮度的**均值**。
///
/// 与「骨架点取子树均值」同一个口径（`B17b` 笔 4）：聚合点代表那一片，
/// 不是其中某一颗。成员里查不到亮度的按 0 计，与单点口径一致（`table[id] ?? 0`）
/// —— **不能跳过**，跳过会让「少数几个没数据」把整片拉亮，而那正是
/// `C-145`「不知道不等于没学过」要防的情形。
double aggregateAlphaFactorOf(
  SkyAggregate aggregate,
  Map<String, double>? brightness,
) {
  if (brightness == null) {
    return alphaFactorOfStep(brightnessStepOf(universeBrightnessUnknown));
  }
  if (aggregate.memberIds.isEmpty) {
    return alphaFactorOfStep(brightnessStepOf(0));
  }
  double sum = 0;
  for (final String id in aggregate.memberIds) {
    sum += brightness[id] ?? 0;
  }
  return alphaFactorOfStep(brightnessStepOf(sum / aggregate.memberIds.length));
}

/// 聚合点上那行字。
String aggregateLabelOf(SkyAggregate aggregate) => '+${aggregate.count}';

/// 节点光点。每帧重画，不缓存。
class SkyNodesPainter extends CustomPainter {
  SkyNodesPainter({
    required this.view,
    required this.universe,
    this.brightness,
    super.repaint,
  });

  final SkyView view;

  /// `null` = 这一片天画不出来（树没装载、地址已过期）。空天不等于错误：
  /// 只画星空，不画点。
  final UniverseView? universe;

  /// 骨架点 id → 亮度（0..1）。**整张表为 `null` = 取不到学习数据** ⇒ 全体共用
  /// `universeBrightnessUnknown`。空表与非空表的分工是「不知道」与「确实没学」，
  /// 两者都写成空集合的话，界面就无法把「日志读不出来」和「你什么都没学」
  /// 分开（`B17b` 笔 4 的降级口径）。
  final Map<String, double>? brightness;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final UniverseView? universe = this.universe;
    if (universe == null || size.isEmpty) {
      return;
    }
    final SkyProjection projection = SkyProjection(view: view, size: size);
    final ui.Color color = axisNodeColor(universe.axis);
    final UniverseLayout layout = universe.layout;

    // 三档分开画，各用一套 paint：光晕的模糊半径与点径同量级，共用一套就
    // 会把小点糊成大点。每档内再按亮度分档 —— 亮度的差别不该把点径也拖下水。
    _paintLayer(
      canvas,
      projection,
      <String, SkyPoint>{universe.anchorId: layout.current},
      universeCurrentDotSize,
      color,
    );
    _paintLayer(
      canvas,
      projection,
      <String, SkyPoint>{
        for (int i = 0; i < layout.ancestors.length; i++)
          layout.ancestorIds[i]: layout.ancestors[i],
      },
      universeAncestorDotSize,
      color,
    );
    _paintLayer(
      canvas,
      projection,
      layout.children,
      universeChildDotSize,
      color,
    );

    // 聚合点画在最后：它占的是网格最后一格，不参与上面那三层的分档，
    // 亮度按被合并的成员求均值。
    final SkyAggregate? aggregate = layout.aggregate;
    if (aggregate != null) {
      _paintAggregate(canvas, projection, aggregate, color);
    }
  }

  /// 该骨架点的不透明度系数（0..1）。
  double _alphaOf(String id) {
    final Map<String, double>? table = brightness;
    if (table == null) {
      return alphaFactorOfStep(brightnessStepOf(universeBrightnessUnknown));
    }
    return alphaFactorOfStep(brightnessStepOf(table[id] ?? 0));
  }

  void _paintLayer(
    ui.Canvas canvas,
    SkyProjection projection,
    Map<String, SkyPoint> points,
    double radius,
    ui.Color color,
  ) {
    // 先按不透明度系数聚组，再逐组画：同一个系数下所有点共用两个 paint，
    // 与点数无关。逐点建 paint 会让一屏一百来个点每帧建两百个对象。
    final Map<double, List<ui.Offset>> byAlpha = <double, List<ui.Offset>>{};
    for (final MapEntry<String, SkyPoint> entry in points.entries) {
      final ui.Offset? center = projection.project(
        directionOfSkyPoint(entry.value),
      );
      // `null` = 落在镜头后方。广角时正对方向两侧 180° 外的点会是这种，
      // 跳过即可 —— 不是丢数据，是它本来就不该出现在这一帧里。
      if (center == null) {
        continue;
      }
      byAlpha.putIfAbsent(_alphaOf(entry.key), () => <ui.Offset>[]).add(center);
    }

    byAlpha.forEach((double alpha, List<ui.Offset> centers) {
      final ui.Paint glow = ui.Paint()
        ..color = color.withValues(alpha: universeDotGlowAlpha * alpha)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius);
      final ui.Paint core = ui.Paint()
        ..color = color.withValues(alpha: universeDotCoreAlpha * alpha);
      for (final ui.Offset center in centers) {
        canvas.drawCircle(center, radius * universeDotGlowScale, glow);
        canvas.drawCircle(center, radius * universeDotCoreScale, core);
      }
    });
  }

  /// 画聚合点：一个点 + 一行「+N」。
  ///
  /// 文字每帧现建一个 `Paragraph`、画完即 `dispose`，**不进** `SkyLabelCache`
  /// （笔 5 那份缓存按文字做键、上限 200）：一屏至多一个聚合点，建一次的开销
  /// 在噪声里；塞进缓存只会让那张表多一类永远只有一两条的内容。
  void _paintAggregate(
    ui.Canvas canvas,
    SkyProjection projection,
    SkyAggregate aggregate,
    ui.Color color,
  ) {
    final ui.Offset? center = projection.project(
      directionOfSkyPoint(aggregate.point),
    );
    // 与子级同一处置：落在镜头后方就不画。
    if (center == null) {
      return;
    }
    final double alpha = aggregateAlphaFactorOf(aggregate, brightness);
    final ui.Paint glow = ui.Paint()
      ..color = color.withValues(alpha: universeDotGlowAlpha * alpha)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        universeAggregateDotSize,
      );
    final ui.Paint core = ui.Paint()
      ..color = color.withValues(alpha: universeDotCoreAlpha * alpha);
    canvas.drawCircle(
      center,
      universeAggregateDotSize * universeDotGlowScale,
      glow,
    );
    canvas.drawCircle(
      center,
      universeAggregateDotSize * universeDotCoreScale,
      core,
    );

    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontSize: universeLabelFontSize,
            textDirection: ui.TextDirection.ltr,
          ),
        )..pushStyle(
          ui.TextStyle(
            color: color.withValues(alpha: universeLabelAlpha),
            fontSize: universeLabelFontSize,
          ),
        );
    builder.addText(aggregateLabelOf(aggregate));
    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    canvas.drawParagraph(
      paragraph,
      center.translate(
        universeAggregateDotSize + universeAggregateLabelGapPx,
        -paragraph.height / 2,
      ),
    );
    paragraph.dispose();
  }

  /// 恒返回 `true`：相机是**原地改字段**的对象，比较引用永远相等；真正的
  /// 重绘信号来自 `repaint`（每帧递增的计数器），与 [ConstellationPainter] 同理。
  @override
  bool shouldRepaint(covariant SkyNodesPainter oldDelegate) => true;
}
