/// `Z4` 的绘制层：把 [StarCloseupLayout] 画成一颗恒星的特写。
///
/// 与另外四档同一套做法 —— `Canvas` 藏在 [CloseupDrawTarget] 后面，真实路径
/// 直通画布、测试路径只记账。于是「指令里没有别的天体」「米粒都落在恒星盘内」
/// 「同一项两次画出同一张脸」都是断言过的，不是「看截图觉得对」。
///
/// ## 接口里没有 `circle`
///
/// 五个动词各对应一个有语义的图元：`orbit` · `starBody` · `granule` · `spot`
/// · `planet`。想「在恒星外面随手画一个圆」写不出来（`R-08` 的正面用法，与
/// `StarDrawTarget` 不给 `line`、`NebulaDrawTarget` 不给 `line` 同理）。
///
/// ## 绘制序
///
/// 轨道 → 恒星本体 → 米粒 → 黑子 → 行星。
///
/// ⚠️ **行星要压在恒星之后**，哪怕它在几何上离恒星更远 —— 绘制序若按「由远及
/// 近」排，内轨那颗会先画、恒星再盖上去，行星就消失一半。这一档只有 1–2 条
/// 轨道，两条都在恒星外，所以「恒星之后画行星」不会造成遮挡错误。
///
/// ## 不转
///
/// 恒星自转 `VIEW-040` 明写不做；行星公转 `C-56` 归 `V-1i`。这一档的 painter
/// 不接 `spin` —— 一张不动的画面每帧重绘会凭空多一档帧预算成本（`V-1b`…`V-1e`
/// 同一条理由）。
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../core/constants.dart' show stellarPlanetRadius;
import 'star_closeup.dart';

/// 恒星实心。与 `Z3` 同一个色 —— 同一颗星在两档之间换色会被读成「进错了一颗」。
const ui.Color _starColor = ui.Color(0xFFFFF6E8);

/// 轨道线。比 `Z3` 亮一档：这一档只有 1–2 条，不再是「九条叠成一张靶纸」。
const ui.Color _orbitColor = ui.Color(0xFF4A5668);

/// 米粒的亮部。压在白上、alpha 低 —— 米粒组织是「盘面不平」，不是「盘上撒了
/// 一把珍珠」。
const ui.Color _granuleColor = ui.Color(0xFFFFFFFF);

/// 黑子的暗部。用带蓝的深色而不是纯黑：纯黑在暖白恒星上像 Photoshop 挖的洞。
const ui.Color _spotColor = ui.Color(0xFF4A3A2A);

/// 行星。与 `Z3`（以及 `Z2` 的项）同色 —— 三种白会让人以为它们不同类。
const ui.Color _planetColor = ui.Color(0xFFDCE6F2);

/// 绘制指令目标。**五种图元各一个动词**。
abstract interface class CloseupDrawTarget {
  /// 一条椭圆轨道。收参数而不是点对（同 `StarDrawTarget.orbit`）。
  void orbit({
    required Offset center,
    required double semiMajor,
    required double semiMinor,
    required double rotation,
  });

  /// 恒星本体：光晕 + 实心。
  void starBody({
    required Offset center,
    required double radius,
    required int argb,
  });

  /// 一颗米粒（亮斑）。颜色固定为白 —— 米粒是恒星**盘面不平**，不是「盘上撒了
  /// 一把带着空间色的珠子」，所以不收 `argb`。
  void granule({required Offset center, required double radius});

  /// 一个黑子（暗斑）。
  void spot({required Offset center, required double radius});

  /// 一颗行星。**不标名**（`VIEW-040` 边界）。
  void planet({required Offset center, required double radius});
}

/// 直通 `Canvas` 的实现。
class CanvasCloseupTarget implements CloseupDrawTarget {
  CanvasCloseupTarget(this._canvas);

  final ui.Canvas _canvas;

  final ui.Paint _paint = ui.Paint()..isAntiAlias = true;

  @override
  void orbit({
    required Offset center,
    required double semiMajor,
    required double semiMinor,
    required double rotation,
  }) {
    _paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = null
      ..color = _orbitColor.withValues(alpha: 0.9);
    _canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: semiMajor * 2,
          height: semiMinor * 2,
        ),
        _paint,
      )
      ..restore();
  }

  @override
  void starBody({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    // 光晕：1.35 倍半径、模糊 24。`Z3` 的恒星只有 `0.045` 那么大，光晕写死
    // 6 px 就够；这一档恒星半径约 250 px，同一个模糊值等于没画。
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 24)
      ..color = ui.Color(argb).withValues(alpha: 0.42);
    _canvas.drawCircle(center, radius * 1.35, _paint);

    _paint
      ..maskFilter = null
      ..color = _starColor;
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void granule({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      // 模糊 2：米粒要有软边。硬边小圆点在暖白盘面上像撒了盐。
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2)
      ..color = _granuleColor.withValues(alpha: 0.26);
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void spot({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      // 黑子边缘比米粒更虚（模糊 4）：真实黑子有半影，硬边会像贴纸。
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4)
      ..color = _spotColor.withValues(alpha: 0.55);
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void planet({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = null
      ..color = _planetColor;
    _canvas.drawCircle(center, radius, _paint);
  }
}

/// 画一颗恒星特写。绘制序见文件头。
void paintStarCloseup({
  required CloseupDrawTarget target,
  required StarCloseupLayout layout,
}) {
  if (layout.isEmpty) {
    return;
  }
  for (final each in layout.orbits) {
    target.orbit(
      center: layout.starCenter,
      semiMajor: each.semiMajor,
      semiMinor: each.semiMinor,
      rotation: each.rotation,
    );
  }
  target.starBody(
    center: layout.starCenter,
    radius: layout.starRadius,
    argb: layout.accentArgb,
  );
  for (final each in layout.granules) {
    target.granule(center: each.center, radius: each.radius);
  }
  for (final each in layout.spots) {
    target.spot(center: each.center, radius: each.radius);
  }
  for (final each in layout.planets) {
    target.planet(center: each.center, radius: stellarPlanetRadius);
  }
}

/// `Z4` 的 `CustomPainter`。
class StarCloseupPainter extends CustomPainter {
  const StarCloseupPainter({required this.layout});

  final StarCloseupLayout layout;

  @override
  void paint(ui.Canvas canvas, Size size) {
    paintStarCloseup(target: CanvasCloseupTarget(canvas), layout: layout);
  }

  @override
  bool shouldRepaint(StarCloseupPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
