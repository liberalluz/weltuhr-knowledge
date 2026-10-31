/// 运行期画一张等距柱状投影（equirect）星空图 —— **数据来自真实星表**。
///
/// 笔 1 这里是 `Random(20261030)` 撒点：位置随机、亮度随机、银河是随手画的一条
/// 斜带。看着像夜空，但抬头找不到北斗 —— 因为每颗星的位置都是伪随机数。这一版
/// 把四件事都换成真的：
///
/// | 项 | 来源 |
/// |---|---|
/// | 星位 | `V/50` 的 J2000 赤经赤纬，9,096 颗 |
/// | 亮度 | 视星等（−1.46 天狼星 ~ 7.96） |
/// | 颜色 | `B−V` 色指数，缺时按光谱型首字母判 |
/// | 银河 | 银道面大圆，走向由同源坐标旋转给出 |
///
/// **不落盘、不入库** —— `ADR-0006` 决策 4 要求天球贴图是构建产物；这里连
/// 构建期产物都不需要，图在内存里画完直接交给 `EnvironmentMap.fromUIImages`。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'star_catalog.dart';

/// 天球贴图默认尺寸。等距柱状 2:1，4096×2048 在 fov 70° 下约合每度 11 像素。
///
/// 敢开到 4096 有实测支撑：笔 1 采到「像素翻 1.6 倍、P50 只涨 0.1 ms」，
/// 说明这条栈不是填充率瓶颈（`ADR-0006` 第五节）。真正的成本在几何实例数，
/// 而贴图不增加几何。
const int kSkyImageWidth = 4096;
const int kSkyImageHeight = 2048;

/// 银河带的半宽（银纬度数）。真实亮带约 ±10°，取 9 让边缘更利落。
const double kMilkyWayHalfWidthDeg = 9.0;

/// 银河带采样点数，整个大圆 360 点 = 每度一个。
const int kMilkyWaySamples = 360;

/// 星等 → 光斑半径的映射端点：最亮 2.6 像素，最暗 0.5。
const double kBrightestMagRadius = 2.6;
const double kFaintestMagRadius = 0.5;
const double kBrightestMag = -1.5;
const double kFaintestMag = 8.0;

/// 暗于该星等的只画一个像素点，不画光晕 —— 绝大多数星都在这一档，
/// 逐颗画圆会让启动多花几百毫秒，而画面上看不出差别。
const double kDimStarMag = 4.5;

/// 画一张星空全景图。
Future<ui.Image> paintSkyImage({
  required List<StarRecord> stars,
  int width = kSkyImageWidth,
  int height = kSkyImageHeight,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final double w = width.toDouble();
  final double h = height.toDouble();

  _paintBackground(canvas, w, h);
  _paintMilkyWay(canvas, w, h);
  _paintStars(canvas, stars, w, h);

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// 底色：极暗的蓝黑，天顶略亮、天底更暗。真实夜空不是纯黑 —— 气辉与散射撑起
/// 那一层底光，压到 #000 反而假。
void _paintBackground(ui.Canvas canvas, double w, double h) {
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(0, h),
        const <ui.Color>[
          ui.Color.fromARGB(255, 4, 6, 14),
          ui.Color.fromARGB(255, 9, 11, 20),
          ui.Color.fromARGB(255, 2, 3, 8),
        ],
        const <double>[0.0, 0.58, 1.0],
      ),
  );
}

/// 银河带：沿**银道面**画一条带，走向由坐标旋转算出，不是随手斜的。
///
/// 把银纬 ±[kMilkyWayHalfWidthDeg] 的两条小圆各自采样成折线，中间填成一条带子。
/// 银经每跨 1° 取一点；两点在图上的横向跳变超过半张图就断开 —— 那是等距柱状
/// 投影在赤经 0h/24h 接缝处的绕回，连起来会横穿整张图。
void _paintMilkyWay(ui.Canvas canvas, double w, double h) {
  final List<ui.Offset> upper = <ui.Offset>[];
  final List<ui.Offset> lower = <ui.Offset>[];
  const double halfWidthRad = kMilkyWayHalfWidthDeg * math.pi / 180;

  for (int i = 0; i <= kMilkyWaySamples; i++) {
    final double l = 2 * math.pi * i / kMilkyWaySamples;
    upper.add(equirectOf(galacticToEquatorial(l, halfWidthRad), w, h));
    lower.add(equirectOf(galacticToEquatorial(l, -halfWidthRad), w, h));
  }

  final ui.Path band = ui.Path();
  ui.Path path = band;
  for (int i = 0; i < upper.length; i++) {
    if (i == 0 || (upper[i].dx - upper[i - 1].dx).abs() > w / 2) {
      path.moveTo(upper[i].dx, upper[i].dy);
    } else {
      path.lineTo(upper[i].dx, upper[i].dy);
    }
  }
  for (int i = lower.length - 1; i >= 0; i--) {
    if (i < lower.length - 1 && (lower[i].dx - lower[i + 1].dx).abs() > w / 2) {
      path = band..moveTo(lower[i].dx, lower[i].dy);
    } else {
      path.lineTo(lower[i].dx, lower[i].dy);
    }
  }
  band.close();

  canvas.drawPath(
    band,
    ui.Paint()..color = const ui.Color.fromARGB(255, 22, 27, 44),
  );
  // 叠一层模糊的亮芯，让带子中心亮、边缘淡。
  canvas.drawPath(
    band,
    ui.Paint()
      ..color = const ui.Color.fromARGB(120, 58, 66, 96)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 26),
  );
}

/// 星点：位置、亮度、颜色三样都取星表。
void _paintStars(ui.Canvas canvas, List<StarRecord> stars, double w, double h) {
  final List<ui.Offset> dim = <ui.Offset>[];

  for (final StarRecord star in stars) {
    final double mag = star.vMag ?? kFaintestMag;
    final ui.Offset at = equirectOf(
      unitVector(star.raHours, star.decDeg),
      w,
      h,
    );

    if (mag > kDimStarMag) {
      dim.add(at);
      continue;
    }

    final ui.Color color = starColor(star);
    final double radius = radiusForMag(mag);
    // 光晕：同色低透明度的大圆，让亮星在贴图里就自带一圈，bloom 再放大一轮。
    canvas.drawCircle(
      at,
      radius * 2.6,
      ui.Paint()
        ..color = color.withValues(alpha: 0.16)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.2),
    );
    canvas.drawCircle(at, radius, ui.Paint()..color = color);
  }

  // 暗星：一次 `drawPoints` 批量画完。逐颗 `drawCircle` 在这张尺寸上要慢一个
  // 数量级，而一两个像素的星本来也看不出圆度。
  if (dim.isNotEmpty) {
    canvas.drawPoints(
      ui.PointMode.points,
      dim,
      ui.Paint()
        ..color = const ui.Color.fromARGB(255, 196, 206, 232)
        ..strokeWidth = 1.6
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

/// 星等越小越亮 ⇒ 半径越大。
double radiusForMag(double mag) {
  final double t = ((kFaintestMag - mag) / (kFaintestMag - kBrightestMag))
      .clamp(0.0, 1.0);
  return kFaintestMagRadius + t * (kBrightestMagRadius - kFaintestMagRadius);
}

/// 三维方向。右手系：`x` 指赤经 0h、`y` 指赤经 6h、`z` 指北天极。
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// 赤经（小时）+ 赤纬（度）→ 单位向量。
Vec3 unitVector(double raHours, double decDeg) {
  final double ra = raHours * 15 * math.pi / 180;
  final double dec = decDeg * math.pi / 180;
  final double cosDec = math.cos(dec);
  return Vec3(cosDec * math.cos(ra), cosDec * math.sin(ra), math.sin(dec));
}

/// 银道坐标（弧度）→ 赤道坐标单位向量（J2000）。
///
/// 用 ICRS→Galactic 旋转矩阵的**转置**（正交矩阵的逆即转置）。矩阵取自
/// 该坐标系的标准定义，与星表同源 —— 所以银河的走向和星的位置不会互相打架。
Vec3 galacticToEquatorial(double lRad, double bRad) {
  final double cosB = math.cos(bRad);
  final double xg = cosB * math.cos(lRad);
  final double yg = cosB * math.sin(lRad);
  final double zg = math.sin(bRad);
  return Vec3(
    -0.0548755604 * xg + 0.4941094279 * yg - 0.8676661490 * zg,
    -0.8734370902 * xg - 0.4448296300 * yg - 0.1980763734 * zg,
    -0.4838350155 * xg + 0.7469822445 * yg + 0.4559837762 * zg,
  );
}

/// 方向向量 → 等距柱状图上的像素坐标。
///
/// 横向：赤经 0h–24h 铺满整张图；纵向：北天极在顶边、南天极在底边。
/// 赤经接缝（0h/24h）落在图的左右两边，取模回绕。
ui.Offset equirectOf(Vec3 direction, double w, double h) {
  double ra = math.atan2(direction.y, direction.x);
  if (ra < 0) {
    ra += 2 * math.pi;
  }
  final double dec = math.asin(direction.z.clamp(-1.0, 1.0));
  return ui.Offset(ra / (2 * math.pi) * w, (0.5 - dec / math.pi) * h);
}

/// 色指数 → 颜色。
ui.Color starColor(StarRecord star) {
  final double? bv = star.bvColorIndex;
  return bv == null ? colorForSpectralClass(star.spectralType) : colorForBv(bv);
}

/// `B−V` 色表：在几个已知色指数之间线性插值。区间覆盖 −0.4（蓝）到 2.0（橙红）。
const List<double> kBvStops = <double>[-0.4, 0.0, 0.4, 0.8, 1.2, 1.6, 2.0];
const List<int> _kBvRed = <int>[155, 202, 248, 255, 255, 255, 255];
const List<int> _kBvGreen = <int>[176, 215, 247, 244, 210, 180, 150];
const List<int> _kBvBlue = <int>[255, 255, 255, 234, 161, 130, 110];

ui.Color colorForBv(double bv) {
  if (bv <= kBvStops.first) {
    return ui.Color.fromARGB(255, _kBvRed[0], _kBvGreen[0], _kBvBlue[0]);
  }
  for (int i = 1; i < kBvStops.length; i++) {
    if (bv <= kBvStops[i]) {
      final double t = (bv - kBvStops[i - 1]) / (kBvStops[i] - kBvStops[i - 1]);
      int lerp(List<int> channel) =>
          (channel[i - 1] + (channel[i] - channel[i - 1]) * t).round();
      return ui.Color.fromARGB(
        255,
        lerp(_kBvRed),
        lerp(_kBvGreen),
        lerp(_kBvBlue),
      );
    }
  }
  final int last = kBvStops.length - 1;
  return ui.Color.fromARGB(255, _kBvRed[last], _kBvGreen[last], _kBvBlue[last]);
}

/// 色指数缺失时按光谱型首字母给一个档。
///
/// 这是近似，但比统一白色更接近真实 —— 参宿四（M 型）是橙红的，织女星
/// （A 型）是蓝白的，压成一个颜色就假了。
ui.Color colorForSpectralClass(String spectralType) {
  final String cls = spectralType.isEmpty
      ? ''
      : spectralType.substring(0, 1).toUpperCase();
  switch (cls) {
    case 'O':
    case 'B':
      return const ui.Color.fromARGB(255, 170, 191, 255);
    case 'A':
      return const ui.Color.fromARGB(255, 213, 224, 255);
    case 'F':
      return const ui.Color.fromARGB(255, 249, 247, 255);
    case 'G':
      return const ui.Color.fromARGB(255, 255, 244, 234);
    case 'K':
      return const ui.Color.fromARGB(255, 255, 214, 170);
    case 'M':
      return const ui.Color.fromARGB(255, 255, 178, 140);
    default:
      return const ui.Color.fromARGB(255, 230, 235, 255);
  }
}
