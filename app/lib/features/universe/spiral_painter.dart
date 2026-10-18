/// `Z1` 的绘制层：把 [SpiralLayout] 画成一张旋涡星系盘。
///
/// 与 `galaxy_painter.dart` 同一套做法 —— 把 `Canvas` 藏在 [SpiralDrawTarget]
/// 后面，真实路径直通画布、测试路径只记账。于是「画了几个暗斑」「域点有没有
/// 光晕」「有没有把项画亮」都是断言过的，不是看截图猜的。
///
/// ## 亮度就是可点性（`VIEW-037`）
///
/// | 对象 | 视觉 | 可点 |
/// |---|---|---|
/// | 域点 | **亮 + 光晕** | ✅ |
/// | 项 | 暗（`#3B4C5C` 级）、无光晕 | ❌ |
/// | 恒星系暗斑 | 更暗、无光晕 | ❌ |
///
/// 这一条**只表达可点性**，不得再承载别的语义（否则与 `r` / 大小 / 虚实重复
/// 通道，`X-02`）。所以本文件里没有「按掌握度调亮」这类钩子 —— 要加先改
/// `channel-table.md`。
///
/// ## 这一档也不转
///
/// 盘自转 `C-54` 与减速停转 `C-57` 归 `V-1i`。接 `spin` 会让一张不动的盘
/// 每帧重绘，帧预算读数凭空多一档成本（`V-1b` 同一条理由）。
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../core/constants.dart';
import 'spiral_map.dart';

/// 背景项的底色（`VIEW-037`：`#3B4C5C` 级）。**不跟着 `accent` 走** ——
/// 它是「背景」这个身份的颜色，换包不该让它变亮。
const ui.Color _itemDotColor = ui.Color(0xFF3B4C5C);

/// 恒星系暗斑 —— 比项更暗：同一个空间里，「恒星系」是比「星」更大的东西，
/// 远看时应当只是盘面上一小块深色，而不是又一个亮点。
const ui.Color _blobColor = ui.Color(0xFF26323D);

/// 绘制指令目标。**五种图元各一个动词**，不提供通用 `line` / `circle`。
///
/// 与 `GalaxyDrawTarget` 同一个理由：`VIEW-037` 说「不是同心环」，接口里
/// 没有「环」这个动词，画错就写不出来。
abstract interface class SpiralDrawTarget {
  /// 一条旋臂的折线。两条臂各调一次。
  void arm({required List<Offset> points, required int argb});

  /// 核球。
  void bulge({
    required Offset center,
    required double radius,
    required int argb,
  });

  /// 背景项。**无光晕、无高亮**（`VIEW-037`）。
  void itemDot({required Offset center, required double radius});

  /// 恒星系暗斑。比项更暗，不参与拾取。
  void blob({required Offset center, required double radius});

  /// 域点：亮 + 光晕。**唯一可点的图元**。
  void domainMark({
    required Offset center,
    required double radius,
    required int argb,
  });
}

/// 直通 `Canvas` 的实现。
class CanvasSpiralTarget implements SpiralDrawTarget {
  CanvasSpiralTarget(this._canvas);

  final ui.Canvas _canvas;

  final ui.Paint _paint = ui.Paint()..isAntiAlias = true;

  @override
  void arm({required List<Offset> points, required int argb}) {
    if (points.length < 2) {
      return;
    }
    final ui.Path path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    _paint
      ..style = ui.PaintingStyle.stroke
      // 臂是一条**带**而不是一条线：真实旋臂是密度波，有宽度、边缘发虚。
      // 这里用半透明粗线近似，比单像素线更像星云状的臂。
      //
      // 三个值都是 `C-64`–`C-66`。提号之前它们是裸字面量 —— `R2` 只查 `core/`，
      // 所以谁也没被拦下，而「看着截图说臂再亮一点」时只能翻文件找那个 `0.30`。
      ..strokeWidth = spiralArmStrokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        spiralArmBlurSigma,
      )
      ..color = ui.Color(argb).withValues(alpha: spiralArmAlpha);
    _canvas.drawPath(path, _paint);
    _paint.maskFilter = null;
  }

  @override
  void bulge({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..shader = ui.Gradient.radial(center, radius, <ui.Color>[
        ui.Color(argb).withValues(alpha: 0.95),
        ui.Color(argb).withValues(alpha: 0.10),
      ])
      ..color = const ui.Color(0xFFFFFFFF);
    _canvas.drawCircle(center, radius, _paint);
    _paint.shader = null;
  }

  @override
  void itemDot({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = _itemDotColor;
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void blob({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = _blobColor;
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void domainMark({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    // 光晕：外圈淡、内圈亮。它是「可点」的唯一视觉信号。
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4)
      ..color = ui.Color(argb).withValues(alpha: 0.55);
    _canvas.drawCircle(center, radius * 2.2, _paint);

    _paint
      ..maskFilter = null
      ..color = ui.Color(argb);
    _canvas.drawCircle(center, radius, _paint);
  }
}

/// 画一张盘。绘制序固定：臂 → 核球 → 项 → 暗斑 → 域点。
///
/// **域点最后画**：它压在背景之上才读得出「这是可以点的那一个」，而顺序
/// 反过来（先画点、再把 150 个项目点铺上去）会让域点被背景糊掉。
void paintSpiral({
  required SpiralDrawTarget target,
  required SpiralLayout layout,
}) {
  if (layout.isEmpty) {
    return;
  }
  for (final SpiralArm arm in layout.arms) {
    target.arm(points: arm, argb: layout.accentArgb);
  }
  target.bulge(
    center: layout.center,
    radius: layout.bulgeRadius,
    argb: layout.accentArgb,
  );
  for (final Offset point in layout.items) {
    target.itemDot(center: point, radius: spiralItemDotRadius);
  }
  for (final Offset point in layout.blobs) {
    target.blob(center: point, radius: spiralBlobRadius);
  }
  for (final DomainMark mark in layout.marks) {
    for (final Offset point in mark.points) {
      target.domainMark(
        center: point,
        radius: spiralDomainMarkRadius,
        argb: layout.accentArgb,
      );
    }
  }
}

/// `Z1` 的 `CustomPainter`。
class SpiralPainter extends CustomPainter {
  const SpiralPainter({required this.layout});

  final SpiralLayout layout;

  @override
  void paint(ui.Canvas canvas, Size size) {
    paintSpiral(target: CanvasSpiralTarget(canvas), layout: layout);
  }

  @override
  bool shouldRepaint(SpiralPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
