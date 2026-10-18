/// `Z2` 的绘制层：把 [NebulaLayout] 画成一朵分子云。
///
/// 与 `galaxy_painter.dart` / `spiral_painter.dart` 同一套做法 —— `Canvas` 藏在
/// [NebulaDrawTarget] 后面，真实路径直通画布、测试路径只记账。于是「粒子数
/// 是不是固定」「跨域边有没有被画成断线」「亮结有没有画上」都是断言过的。
///
/// ## 接口里没有 `line`
///
/// `VIEW-038` 只允许两种边：域内边（照常画）与跨域边（**出口标记，不画断线**）。
/// 所以动词表里给的是 `thread`（域内那条线）与 `exitMark`（一个朝外的箭头），
/// **没有通用 `line`** —— 想画一条伸出去就断的线，写不出来（`R-08` 的正面用法，
/// 与 `SpiralDrawTarget` 不给 `circle` 同理）。
///
/// ## 云的画法
///
/// **无边界粒子云，不用填充渐变**：`C-32` 的成本由填充面积驱动，一团铺满的
/// 渐变大云会把帧预算吃掉（`VIEW-038` 明写这条）。粒子是硬边小圆 + 低透明度，
/// 靠数量与半径分布出层次。
///
/// ## 这一档也还不转
///
/// 云的整体自转 `C-54` 归 `V-1i`（`VIEW-038`：亮结无独立轨道，只随盘整体转）。
/// 接 `spin` 会让一张不动的画面每帧重绘，帧预算读数凭空多一档成本
/// （`V-1b` / `V-1c` 同一条理由）。
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'nebula_map.dart';

/// 云里的一颗星（可点 ⇒ `Z4`）。比 `Z1` 的背景项亮 —— 这一档它**是**可点的，
/// 而 `VIEW-037` 的「暗 = 背景」只约束 `Z1`。
const ui.Color _itemColor = ui.Color(0xFFDCE6F2);

/// 域内边。压得很暗：边是拓扑背景，抢不过星与亮结。
const ui.Color _threadColor = ui.Color(0xFF39485A);

/// 绘制指令目标。**五种图元各一个动词**，不提供通用 `line` / `circle`。
abstract interface class NebulaDrawTarget {
  /// 一颗粒子。`Z2` 里它会调 `C-62` 次。
  void wisp({
    required Offset center,
    required double radius,
    required int argb,
  });

  /// 域内边 —— **两端都在这个域里**的那条线。
  void thread({required Offset from, required Offset to});

  /// 云里的一项。
  void itemDot({required Offset center, required double radius});

  /// 亮结：亮 + 光晕。**容器**，可点 ⇒ `Z3`。
  void knot({
    required Offset center,
    required double radius,
    required int argb,
  });

  /// 出口标记：云缘上一个**朝外**的箭头。⚠️ 不是「画到一半的线」。
  void exitMark({
    required Offset center,
    required Offset direction,
    required int argb,
  });
}

/// 直通 `Canvas` 的实现。
class CanvasNebulaTarget implements NebulaDrawTarget {
  CanvasNebulaTarget(this._canvas);

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
      // 透明度压到 0.16：240 颗叠在一起才出「云」的感觉，单颗必须是淡淡的。
      ..color = ui.Color(argb).withValues(alpha: 0.16);
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void thread({required Offset from, required Offset to}) {
    _paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = null
      ..color = _threadColor.withValues(alpha: 0.55);
    _canvas.drawLine(from, to, _paint);
  }

  @override
  void itemDot({required Offset center, required double radius}) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = _itemColor;
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void knot({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    // 光晕：外圈淡、内圈亮。它是「可点」的唯一视觉信号（同 `Z1` 的域点）。
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5)
      ..color = ui.Color(argb).withValues(alpha: 0.60);
    _canvas.drawCircle(center, radius * 2.4, _paint);

    _paint
      ..maskFilter = null
      ..color = const ui.Color(0xFFF3F7FF);
    _canvas.drawCircle(center, radius, _paint);
  }

  @override
  void exitMark({
    required Offset center,
    required Offset direction,
    required int argb,
  }) {
    // 箭头 = 一个小三角 + 一条短杆。**不延长到云外**：延长就成了断线，
    // 而 `VIEW-038` 要的正是「到了这里就是出口」。
    final Offset normal = Offset(-direction.dy, direction.dx);
    final Offset tip = center + direction * 7;
    final Offset back = center + direction * 2;
    final ui.Path path = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + normal.dx * 4, back.dy + normal.dy * 4)
      ..lineTo(back.dx - normal.dx * 4, back.dy - normal.dy * 4)
      ..close();
    _paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = null
      ..color = ui.Color(argb).withValues(alpha: 0.85);
    _canvas.drawPath(path, _paint);
  }
}

/// 画一朵云。绘制序固定：粒子 → 域内边 → 项 → 出口 → 亮结。
///
/// **亮结最后画**：它压在云与星之上才读得出「这是可以点的那一个」；反过来
/// （先画亮结，再把 180 颗粒子铺上去）亮结会被糊掉。
void paintNebula({
  required NebulaDrawTarget target,
  required NebulaLayout layout,
}) {
  if (layout.isEmpty) {
    return;
  }
  for (final NebulaWisp wisp in layout.wisps) {
    target.wisp(center: wisp.center, radius: wisp.radius, argb: wisp.argb);
  }
  for (final NebulaThread thread in layout.threads) {
    target.thread(from: thread.from, to: thread.to);
  }
  for (final NebulaItem item in layout.items) {
    target.itemDot(center: item.center, radius: 1.8);
  }
  for (final NebulaExit exit in layout.exits) {
    target.exitMark(
      center: exit.center,
      direction: exit.direction,
      argb: layout.accentArgb,
    );
  }
  for (final NebulaKnot knot in layout.knots) {
    target.knot(center: knot.center, radius: 3.4, argb: layout.accentArgb);
  }
}

/// `Z2` 的 `CustomPainter`。
class NebulaPainter extends CustomPainter {
  const NebulaPainter({required this.layout});

  final NebulaLayout layout;

  @override
  void paint(ui.Canvas canvas, Size size) {
    paintNebula(target: CanvasNebulaTarget(canvas), layout: layout);
  }

  @override
  bool shouldRepaint(NebulaPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
