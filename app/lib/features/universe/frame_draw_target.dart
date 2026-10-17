/// 绘制指令的接收端 —— 帧率 spike 的**度量缝**。
///
/// 这一笔要回答的问题只有一个：**一帧到底发出多少次 Canvas 调用**。
/// 把 `Canvas` 藏在接口后面，真实路径直通 `Canvas`、测试路径只记账，
/// 于是「150 项 = 150 次 `drawCircle`」这句话是被断言过的，不是估出来的。
///
/// 为什么不用 `flutter_test` 的记录画布：它记的是 `Canvas` 的调用，
/// 而我们真正想守的是**本层发出的指令数**（虚线分几段、哪些边被跳过）。
/// 数 `Canvas` 调用只能事后反推，数指令是直接判据。
library;

import 'dart:ui' show Canvas, Color, Offset, PaintingStyle, Paint;

/// 一帧里发出的指令条数。
///
/// 分类而不是只给一个总数：圆与线在 GPU 侧的成本不同，
/// 而虚线边一条会变成多条线段 —— 混成一个数就看不出是谁涨的。
class FrameDrawReport {
  const FrameDrawReport({
    required this.dots,
    required this.strokes,
    required this.dashedEdges,
    required this.dashedSegments,
    required this.skippedEdges,
    required this.offscreenDots,
  });

  /// 节点圆（`drawCircle`）次数。
  final int dots;

  /// 线段（`drawLine`）次数，含虚线拆出来的每一段。
  final int strokes;

  /// 虚线边条数。
  final int dashedEdges;

  /// 虚线拆出来的线段数。
  final int dashedSegments;

  /// 两端重合、无法分段而被跳过的虚线边数（投影后可能发生）。
  final int skippedEdges;

  /// 圆心落在视口外、**仍然发出绘制调用**的节点数。
  ///
  /// 不省掉这些调用是刻意的：朴素实现不会逐个判屏，而「有多少东西被画到
  /// 画面之外」正是 `φ` 层号不归一时的直接症状（α 包 `φ` 到 63）。
  final int offscreenDots;

  /// GPU 侧要处理的绘制调用总数。
  int get total => dots + strokes;

  @override
  String toString() =>
      'FrameDrawReport(dots: $dots, strokes: $strokes, '
      'dashedEdges: $dashedEdges, dashedSegments: $dashedSegments, '
      'skippedEdges: $skippedEdges, offscreenDots: $offscreenDots)';
}

/// 绘制指令目标。[dot] 画一个节点，[stroke] 画一段线。
///
/// 坐标一律用**屏幕像素**（变换在上层做完），所以实现方不需要知道相机。
abstract interface class FrameDrawTarget {
  /// 一个节点。`filled == false` 表示「不可外化比例高」的虚化表达（空心）。
  void dot({
    required double x,
    required double y,
    required double radius,
    required int argb,
    required bool filled,
  });

  /// 一段直线。虚线由调用方拆成多段，本方法不解释线型。
  void stroke({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required int argb,
    required double width,
  });
}

/// 直通 `Canvas` 的实现 —— 这就是 `B3` 若走朴素路线会做的事。
class CanvasDrawTarget implements FrameDrawTarget {
  CanvasDrawTarget(this._canvas);

  final Canvas _canvas;

  /// 复用两个 `Paint`：每次 `drawX` 前只改 color / strokeWidth / style，
  /// 不新建对象。**不要优化掉这一步** —— 新建 `Paint` 的开销会混进帧率，
  /// 而它不在被考察的那条路上。
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void dot({
    required double x,
    required double y,
    required double radius,
    required int argb,
    required bool filled,
  }) {
    _paint
      ..color = Color(argb)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _canvas.drawCircle(Offset(x, y), radius, _paint);
  }

  @override
  void stroke({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required int argb,
    required double width,
  }) {
    _paint
      ..color = Color(argb)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    _canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _paint);
  }
}
