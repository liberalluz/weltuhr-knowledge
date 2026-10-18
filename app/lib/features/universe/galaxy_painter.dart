/// `Z0` 的绘制层：把 [GalaxyLayout] 画成一片星系群。
///
/// 与 `frame_painter.dart` 同一套思路 —— 把 `Canvas` 藏在 [GalaxyDrawTarget]
/// 后面，真实路径直通画布、测试路径只记账。于是「画了几个盘」「有没有画那个
/// 均分圆」是被断言过的，不是看截图猜的。
///
/// ## 这一档不转
///
/// `Z0` 的盘自转 `C-54` 与构型公转 `C-55` 归 `V-1i`（运动那一笔）。这一笔只把
/// 形态画对，所以 painter **不接 `spin`** ——接了就每帧重绘一片不动的画面，
/// 而帧预算的读数会凭空多出一档成本。
///
/// ## 描边只在被遮时
///
/// `VIEW-036`：被遮星系须描边露出轮廓 —— 完全挡住等于「以为没有这个空间」。
/// 每个盘都描边会让轮廓失去信息量（到处是线，就看不出哪条在说「我还在」）。
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'galaxy_map.dart';

/// 绘制指令目标。**只有一种图元**：椭圆盘。
///
/// 不提供 `circle` / `line`：`VIEW-036` 明写「不画均分圆」—— 画出来会被读成
/// 「公转轨道」。接口里不给这个动词，比写一句注释更管用（`R-08` 同族：
/// 靠约定保证的约束，违反它不会有任何东西变红）。
abstract interface class GalaxyDrawTarget {
  /// 一个盘。[rim] = 被遮，须描边。
  void disc({
    required double x,
    required double y,
    required double rx,
    required double ry,
    required int argb,
    required bool rim,
  });
}

/// 直通 `Canvas` 的实现。
class CanvasGalaxyTarget implements GalaxyDrawTarget {
  CanvasGalaxyTarget(this._canvas);

  final ui.Canvas _canvas;

  /// 复用两个 `Paint`：`Z0` 的盘最多几个，新建开销本来可忽略；但保持与
  /// `CanvasDrawTarget` 一致的做法，免得日后有人以为这里需要优化。
  final ui.Paint _fill = ui.Paint()..isAntiAlias = true;
  final ui.Paint _stroke = ui.Paint()..isAntiAlias = true;

  @override
  void disc({
    required double x,
    required double y,
    required double rx,
    required double ry,
    required int argb,
    required bool rim,
  }) {
    final ui.Rect rect = ui.Rect.fromCenter(
      center: ui.Offset(x, y),
      width: rx * 2,
      height: ry * 2,
    );
    // 盘面半透明：星系不是实心圆饼，边缘本来就淡。
    _fill.color = ui.Color(argb).withValues(alpha: 0.22);
    _canvas.drawOval(rect, _fill);

    if (rim) {
      _stroke
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ui.Color(argb).withValues(alpha: 0.95);
      _canvas.drawOval(rect, _stroke);
    }
  }
}

/// 画一片星系群。绘制序由 [GalaxyLayout.discs] 给出（近 → 远）。
void paintGalaxies({
  required GalaxyDrawTarget target,
  required GalaxyLayout layout,
}) {
  for (final GalaxyDisc disc in layout.discs) {
    target.disc(
      x: disc.centerX,
      y: disc.centerY,
      rx: disc.radius,
      ry: disc.minorRadius,
      argb: disc.argb,
      rim: disc.occluded,
    );
  }
}

/// `Z0` 的 `CustomPainter`。
class GalaxyPainter extends CustomPainter {
  const GalaxyPainter({required this.layout});

  final GalaxyLayout layout;

  @override
  void paint(ui.Canvas canvas, Size size) {
    paintGalaxies(target: CanvasGalaxyTarget(canvas), layout: layout);
  }

  @override
  bool shouldRepaint(GalaxyPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
