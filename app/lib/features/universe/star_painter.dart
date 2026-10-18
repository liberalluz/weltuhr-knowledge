/// `Z3` 的绘制层：把 [StarSystemLayout] 画成一颗恒星 + 共面轨道。
///
/// 与另外三档同一套做法 —— `Canvas` 藏在 [StarDrawTarget] 后面，真实路径直通
/// 画布、测试路径只记账。于是「轨道条数 = 层数」「每颗行星都在自己那条轨道上」
/// 「恒星画了几次」都是断言过的。
///
/// ## 接口里没有 `circle` / `line`
///
/// 四个动词各对应一个**有语义的**图元：`wisp`（残余云气）· `orbit`（椭圆轨道）
/// · `star`（恒星）· `planet`（行星）。想「画一条伸到画面外的线」写不出来，
/// 因为 `orbit` 收的是半长轴 / 半短轴 / 朝向，不是一个点对（`R-08` 的正面用法，
/// 与 `NebulaDrawTarget` 不给 `line`、`SpiralDrawTarget` 不给 `circle` 同理）。
///
/// ## 这一档也还不转
///
/// 行星公转 `C-56` 归 `V-1i` —— 本笔只有静态相位。接 `spin` 会让一张不动的
/// 画面每帧重绘，帧预算读数凭空多一档成本（`V-1b` / `V-1c` / `V-1d` 同一条理由）。
/// 相位方向已经全部按同一方向排好，接运动时不需要重排。
///
/// ## 恒星是唯一发光的东西
///
/// 恒星画两遍（光晕 + 实心），行星只画实心 —— 行星不该看起来像小太阳，
/// 否则「谁是中心」读不出来。
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../core/constants.dart' show stellarPlanetRadius;
import 'star_map.dart';

/// 行星。与 `Z2` 的项同色 —— 两处都是「这一档里的一颗星」，两种白会让人以为
/// 它们不同类。
const ui.Color _planetColor = ui.Color(0xFFDCE6F2);

/// 轨道线。压得比 `Z2` 的域内边更暗：九条同心椭圆叠起来是画面里面积最大的
/// 一层，稍亮一点整张图就变成一张靶纸。
const ui.Color _orbitColor = ui.Color(0xFF2E3A4A);

/// 绘制指令目标。**四种图元各一个动词**。
abstract interface class StarDrawTarget {
  /// 一团残余云气。`Z3` 里它会调 `C-77` 次。
  void wisp({required Offset center, required double radius, required int argb});

  /// 一条**共面椭圆轨道**。收参数而不是点对 —— 见文件头。
  void orbit({
    required Offset center,
    required double semiMajor,
    required double semiMinor,
    required double rotation,
  });

  /// 恒星：光晕 + 实心。
  void star({
    required Offset center,
    required double radius,
    required int argb,
  });

  /// 一颗粒行。可点 ⇒ `Z4`。
  void planet({required Offset center, required double radius});
}

/// 直通 `Canvas` 的实现。
class CanvasStarTarget implements StarDrawTarget {
  CanvasStarTarget(this._canvas);

  final ui.Canvas _canvas;

  final ui.Paint _paint = ui.Paint()..isAntiAlias = true;

  @override
  void wisp({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = null
      // 0.09：28 颗叠起来像一层薄雾，单颗几乎看不见。压得比 `Z2` 的 0.16
      // 更低，是因为这一档的云气**只是背景**，主角是轨道与星。
      ..color = ui.Color(argb).withValues(alpha: 0.09);
    _canvas.drawCircle(center, radius, _paint);
  }

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
      ..color = _orbitColor.withValues(alpha: 0.85);
    // 共面 ⇒ 不需要投影，椭圆的长短轴就是屏幕上那两个数。倾角为 0 是
    // `VIEW-039` 第 2 条，不是这里省掉了什么。
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
  void star({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    // 光晕：3.2 倍半径、模糊 6 —— 恒星要比行星明显「亮一团」，而不只是
    // 「大一点」。这是本档唯一的发光体。
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6)
      ..color = ui.Color(argb).withValues(alpha: 0.55);
    _canvas.drawCircle(center, radius * 3.2, _paint);

    // 实心：偏白而不是纯 accent —— 真实里恒星看起来是白的（色温高），
    // accent 只留给光晕。
    _paint
      ..maskFilter = null
      ..color = const ui.Color(0xFFFFF6E8);
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

/// 画一个恒星系。绘制序固定：云气 → 轨道 → 恒星 → 行星。
///
/// **恒星压着轨道、行星压着恒星**：内轨在最里侧，行星正压在轨道线上，如果
/// 先画行星再画轨道，轨道线会从行星身上穿过去，行星看起来像被划掉了。
void paintStarSystem({
  required StarDrawTarget target,
  required StarSystemLayout layout,
}) {
  if (layout.isEmpty) {
    return;
  }
  for (final StarWisp wisp in layout.wisps) {
    target.wisp(
      center: wisp.center,
      radius: wisp.radius,
      argb: layout.accentArgb,
    );
  }
  for (final StarOrbit orbit in layout.orbits) {
    target.orbit(
      center: layout.starCenter,
      semiMajor: orbit.semiMajor,
      semiMinor: orbit.semiMinor,
      rotation: orbit.rotation,
    );
  }
  target.star(
    center: layout.starCenter,
    radius: layout.starRadius,
    argb: layout.accentArgb,
  );
  for (final StarPlanet planet in layout.planets) {
    target.planet(center: planet.center, radius: stellarPlanetRadius);
  }
}

/// `Z3` 的 `CustomPainter`。
class StarPainter extends CustomPainter {
  const StarPainter({required this.layout});

  final StarSystemLayout layout;

  @override
  void paint(ui.Canvas canvas, Size size) {
    paintStarSystem(target: CanvasStarTarget(canvas), layout: layout);
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
