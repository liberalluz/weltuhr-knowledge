/// 三条标志星座的连线：北斗、猎户、仙后。
///
/// **画在屏幕层，不进天球贴图**：贴图是启动时画一次的静态图，改不了；而连线要
/// 随视场角淡出，只能每帧按相机姿态重画（`ADR-0006` 修订九）。
///
/// **星位全部来自 Hipparcos 表**，这里只写「哪颗连哪颗」。天文上没有官方的
/// 星座连线 —— 国际天文学联合会只划天区边界，勺子与 W 都是星图各自画的，
/// 所以本文件不声称对齐某个软件的版本：可核的点是「每一对都由星名指定，星名
/// 到 HIP 由星表反查确认」，那条断言在 `constellations_test.dart` 里。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'star_catalog.dart';
import 'sky_image.dart';

/// 一段连线：两端各一个 HIP 号。
class ConstellationSegment {
  const ConstellationSegment(this.from, this.to);

  final int from;
  final int to;
}

/// 一条星座：中文名 + 若干段。
class Constellation {
  const Constellation({required this.name, required this.segments});

  final String name;
  final List<ConstellationSegment> segments;
}

/// 三条星座。北斗与猎户按「勺形 / 人形」连，仙后按 W 形连。
///
/// 仙后五颗**不给中文星名**：它们属「王良」星官，α/β 与王良几的对应各资料
/// 不一致，写错不如只标星座名（卡面验收第 6 条）。
const List<Constellation> kConstellations = <Constellation>[
  Constellation(
    name: '北斗',
    segments: <ConstellationSegment>[
      // 斗勺：天枢 α - 天璇 β - 天玑 γ - 天权 δ - 天枢（闭合）。
      ConstellationSegment(54061, 53910),
      ConstellationSegment(53910, 58001),
      ConstellationSegment(58001, 59774),
      ConstellationSegment(59774, 54061),
      // 斗柄：天权 δ - 玉衡 ε - 开阳 ζ - 摇光 η。
      ConstellationSegment(59774, 62956),
      ConstellationSegment(62956, 65378),
      ConstellationSegment(65378, 67301),
    ],
  ),
  Constellation(
    name: '猎户',
    segments: <ConstellationSegment>[
      // 两肩：参宿四 α - 参宿五 γ。
      ConstellationSegment(27989, 25336),
      // 左腰：参宿四 α - 参宿一 ζ - 参宿六 κ。
      ConstellationSegment(27989, 26727),
      ConstellationSegment(26727, 27366),
      // 右腰：参宿五 γ - 参宿三 δ - 参宿七 β。
      ConstellationSegment(25336, 25930),
      ConstellationSegment(25930, 24436),
      // 腰带：参宿三 δ - 参宿二 ε - 参宿一 ζ。
      ConstellationSegment(25930, 26311),
      ConstellationSegment(26311, 26727),
    ],
  ),
  Constellation(
    name: '仙后',
    segments: <ConstellationSegment>[
      // W 形：β - α - γ - δ - ε。
      ConstellationSegment(746, 3179),
      ConstellationSegment(3179, 4427),
      ConstellationSegment(4427, 6686),
      ConstellationSegment(6686, 8886),
    ],
  ),
];

/// 渐隐的起止视场角（度）：60° 及以下满值，80° 及以上完全不画。
const double kConstellationFadeStartDeg = 60.0;
const double kConstellationFadeEndDeg = 80.0;

/// 某个视场角下连线的不透明度。
///
/// 广角下满屏是线、把星空本身盖掉，所以越拉远越淡；60° 是「一屏装得下一条
/// 星座」的门槛，80° 以外基本是在看全天，连线没有意义。
double constellationOpacity(double fovDeg) {
  if (fovDeg <= kConstellationFadeStartDeg) {
    return 1;
  }
  if (fovDeg >= kConstellationFadeEndDeg) {
    return 0;
  }
  return (kConstellationFadeEndDeg - fovDeg) /
      (kConstellationFadeEndDeg - kConstellationFadeStartDeg);
}

/// 两端赤经差超过半圈 ⇒ 这条线横跨等距柱状的左右接缝。
///
/// 已知边界：这种段**整段跳过**，不补画另一半 —— 补画要在对侧再算一次坐标，
/// 而跨缝的星座在球面上本来就被切开了，硬连会在接缝处拉出一条假线。
bool crossesSeam(double raFromDeg, double raToDeg) =>
    (raFromDeg - raToDeg).abs() > 180.0;

/// 相机姿态的只读视图。`SkyCamera` 实现它 —— 这样本文件不必反向依赖场景文件。
abstract interface class SkyView {
  double get yaw;
  double get pitch;
  double get fovDeg;
}

/// 球心针孔投影：三维方向 → 屏幕坐标。
///
/// 相机固定在原点、只转不平移（`ADR-0006` 决策二），所以投影就是「方向在视线
/// 坐标系里的分量」。三处轴口径必须与引擎一致，错一处线就不落在星上：
///
/// | 项 | 取值 | 依据 |
/// |---|---|---|
/// | 场景轴 | 星表 `(x, y, z)` → 场景 `(x, z, y)` | 与亮星 billboard 同一映射（`spike_scene.dart` 的 `_addBrightStars`） |
/// | 右轴 | `up × forward` | `flutter_scene-0.24.3/lib/src/camera.dart:472` 的 `_matrix4LookAt` |
/// | 归一化 | `x / (tan(fovY/2) · aspect)` · `y / tan(fovY/2)`，再除以深度 | 同文件 `_matrix4Perspective`（`width = height · aspectRatio`） |
class SkyProjection {
  SkyProjection({required this.view, required this.size})
    : _forward = _directionOf(view.yaw, view.pitch) {
    final Vec3 side = _cross(const Vec3(0, 1, 0), _forward);
    final double length = _length(side);
    // 正对天极时 `forward` 与 `up` 平行、叉积退化；给一个兜底的横轴，
    // 免得整片连线消失。相机本身把俯仰夹在 ±(π/2 − 0.01)，走到这里很罕见。
    _right = length < 1e-6 ? const Vec3(1, 0, 0) : _scale(side, 1 / length);
    _up = _cross(_forward, _right);
  }

  final SkyView view;
  final ui.Size size;

  final Vec3 _forward;
  late final Vec3 _right;
  late final Vec3 _up;

  /// 投影一个**星表坐标系**的方向；在镜头后方（或落在切平面上）返回 `null`。
  ui.Offset? project(Vec3 direction) {
    final Vec3 scene = Vec3(direction.x, direction.z, direction.y);
    final double depth = _dot(scene, _forward);
    if (depth <= 1e-6) {
      return null;
    }
    final double tanHalf = math.tan(view.fovDeg * math.pi / 360);
    final double aspect = size.width / size.height;
    final double ndcX = _dot(scene, _right) / depth / (tanHalf * aspect);
    final double ndcY = _dot(scene, _up) / depth / tanHalf;
    return ui.Offset(
      (ndcX * 0.5 + 0.5) * size.width,
      (0.5 - ndcY * 0.5) * size.height,
    );
  }
}

/// 屏幕层连线。每帧重画，不缓存。
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.view,
    required this.starsByHip,
    super.repaint,
  });

  final SkyView view;

  /// HIP 号 → 星表记录。缺号即整段跳过（星表里没有这颗就不画假设的线）。
  final Map<int, StarRecord> starsByHip;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final double opacity = constellationOpacity(view.fovDeg);
    if (opacity <= 0.001 || size.isEmpty) {
      return;
    }

    final SkyProjection projection = SkyProjection(view: view, size: size);
    final ui.Paint paint = ui.Paint()
      ..color = ui.Color.fromARGB((opacity * 82).round(), 198, 212, 255)
      ..strokeWidth = 1.0
      ..strokeCap = ui.StrokeCap.round;

    for (final Constellation constellation in kConstellations) {
      final List<ui.Offset> points = <ui.Offset>[];
      for (final ConstellationSegment segment in constellation.segments) {
        final StarRecord? from = starsByHip[segment.from];
        final StarRecord? to = starsByHip[segment.to];
        if (from == null || to == null || crossesSeam(from.raDeg, to.raDeg)) {
          continue;
        }
        final ui.Offset? a = projection.project(
          unitVector(from.raDeg, from.decDeg),
        );
        final ui.Offset? b = projection.project(
          unitVector(to.raDeg, to.decDeg),
        );
        if (a == null || b == null) {
          continue;
        }
        canvas.drawLine(a, b, paint);
        points
          ..add(a)
          ..add(b);
      }
      // 名字只在「一屏一条星座」的范围里显示；连线淡出时字也跟着淡。
      if (points.isEmpty || view.fovDeg > kConstellationFadeStartDeg) {
        continue;
      }
      _paintName(canvas, constellation.name, points, opacity);
    }
  }

  void _paintName(
    ui.Canvas canvas,
    String name,
    List<ui.Offset> points,
    double opacity,
  ) {
    double sumX = 0;
    double sumY = 0;
    for (final ui.Offset point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: ui.Color.fromARGB((opacity * 168).round(), 226, 232, 255),
          fontSize: 12,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset(
        sumX / points.length - painter.width / 2,
        sumY / points.length - painter.height / 2,
      ),
    );
  }

  /// 恒返回 `true`：相机是**原地改字段**的对象，比较引用永远相等；真正的
  /// 重绘信号来自 `repaint`（每帧递增的计数器），不是这里。
  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) => true;
}

Vec3 _directionOf(double yaw, double pitch) {
  final double cosPitch = math.cos(pitch);
  return Vec3(
    math.sin(yaw) * cosPitch,
    math.sin(pitch),
    math.cos(yaw) * cosPitch,
  );
}

double _dot(Vec3 a, Vec3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

Vec3 _cross(Vec3 a, Vec3 b) =>
    Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);

Vec3 _scale(Vec3 v, double k) => Vec3(v.x * k, v.y * k, v.z * k);

double _length(Vec3 v) => math.sqrt(_dot(v, v));
