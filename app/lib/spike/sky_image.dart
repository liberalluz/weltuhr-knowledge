/// 运行期画一张等距柱状投影（equirect）星空图 —— **数据来自真实星表**。
///
/// 段 2 这里是 `V/50` 的 9,096 颗；段 3 换成 Hipparcos 全量 **117,017 颗**
/// （可渲染 118,217 减去最亮 1,200 颗走 billboard 的那批）。四件事都是真的：
///
/// | 项 | 来源 |
/// |---|---|
/// | 星位 | Hipparcos 的 J2000 赤经赤纬（度） |
/// | 亮度 | 视星等（−1.44 天狼星 ~ 9.5 等） |
/// | 颜色 | `B−V` 色指数；这一层颜色近似单色，真实色温留给 billboard |
/// | 银河 | 银道面大圆，走向由同源坐标旋转给出，边缘按银纬羽化 |
///
/// **两极畸变在绘制期补偿**：等距柱状把球面摊成矩形，赤纬 φ 处一个角半径固定
/// 的圆斑，在图上横向只占 `cos φ` 倍的宽度，投影回球面就成了竖长的椭圆；纬度
/// 越高越扁，极点处退化成一根竖线。补偿办法是把横向画宽 `1/cos φ` 倍 —— 投影
/// 回去正好是正圆。φ 超过 [kPolarCompensationMaxDecDeg] 不再补偿：那里需要的
/// 倍数发散，横向像素也不够，那片天区的星都是单像素暗星，退回正圆点后球面上
/// 只是缩得更小更暗，不会是横条。
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

/// 银河带沿银纬切成多少层。层数决定羽化的平滑度：层越多阶跃越小，
/// 每层都要画一条闭合带，24 层是「看不出台阶」与「启动别太慢」的折中。
const int kMilkyWayBands = 24;

/// 银河带中心的最高不透明度。压得很低 —— 真实银河是底色上的一层灰白，
/// 压高了整片天会变成一块蓝布。
const double kMilkyWayPeakAlpha = 0.55;

/// 星等 → 光斑半径的映射端点：最亮 2.6 像素，最暗 0.5。
const double kBrightestMagRadius = 2.6;
const double kFaintestMagRadius = 0.5;
const double kBrightestMag = -1.5;
const double kFaintestMag = 9.5;

/// 横向补偿的纬度上限（度）。超过它退回不补偿，见文件头。
const double kPolarCompensationMaxDecDeg = 80.0;

/// 纬度带宽度（度）。带内用带中心的补偿倍数近似 —— 带越窄越准，
/// 代价是 `drawPoints` 的调用次数翻倍；2.5° 时最大偏差出现在 80° 附近，
/// 用 77.5° 的倍数（4.54）近似 79.9° 的（5.76），欠补偿约 20%，肉眼不可辨。
const double kSkyBandDegrees = 2.5;

/// 纬度带数，0..80 度。
const int kSkyBandCount = 32;

/// 「不补偿」档的下标（|赤纬| > 80°）。
const int kPolarBand = kSkyBandCount;

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

/// 银河在某个银纬上的不透明度：中心满值，边缘**平滑降到 0**。
///
/// 段 2 画的是一条等亮的带子，边界像刀切 —— 真实银河没有边，是逐渐稀下去的。
/// 用 `(1 − t)²` 而不是 `1 − t`：后者在边缘处斜率不为零，仍能看出折角。
double milkyWayAlphaAt(double galacticLatDeg) {
  final double t = (galacticLatDeg.abs() / kMilkyWayHalfWidthDeg).clamp(
    0.0,
    1.0,
  );
  return (1 - t) * (1 - t);
}

/// 银河带：沿**银道面**分层画，每层按银纬给不透明度，边缘自然消失。
///
/// 走向由坐标旋转算出（ICRS→Galactic 矩阵的转置），与星位同源 —— 所以银河
/// 不会和星星打架。
void _paintMilkyWay(ui.Canvas canvas, double w, double h) {
  const double bandWidth = 2 * kMilkyWayHalfWidthDeg / kMilkyWayBands;
  for (int i = 0; i < kMilkyWayBands; i++) {
    final double b0 = -kMilkyWayHalfWidthDeg + bandWidth * i;
    final double b1 = b0 + bandWidth;
    final double alpha = milkyWayAlphaAt((b0 + b1) / 2) * kMilkyWayPeakAlpha;
    if (alpha <= 0.001) {
      continue;
    }
    canvas.drawPath(
      _bandPath(b0, b1, w, h),
      ui.Paint()..color = ui.Color.fromARGB((alpha * 255).round(), 46, 54, 80),
    );
  }
  // 一层很宽的模糊只压中央亮部：银河核心比两翼亮，这一点 blur 比再切十层便宜。
  canvas.drawPath(
    _bandPath(-3.0, 3.0, w, h),
    ui.Paint()
      ..color = const ui.Color.fromARGB(38, 72, 80, 118)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 30),
  );
}

/// 银纬 `b0…b1` 之间那条带子在 equirect 图上的闭合路径。
///
/// 银经每跨 1° 取一点；两点在图上的横向跳变超过半张图就断开 —— 那是等距柱状
/// 投影在赤经 0h/24h 接缝处的绕回，连起来会横穿整张图。
ui.Path _bandPath(double b0, double b1, double w, double h) {
  final double lower = b0 * math.pi / 180;
  final double upper = b1 * math.pi / 180;
  final ui.Path path = ui.Path();
  bool open = false;
  ui.Offset? previous;

  void feed(ui.Offset point) {
    if (!open) {
      path.moveTo(point.dx, point.dy);
      open = true;
    } else if (previous != null && (point.dx - previous!.dx).abs() > w / 2) {
      path.close();
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
    previous = point;
  }

  for (int i = 0; i <= kMilkyWaySamples; i++) {
    final double l = 2 * math.pi * i / kMilkyWaySamples;
    feed(equirectOf(galacticToEquatorial(l, lower), w, h));
  }
  for (int i = kMilkyWaySamples; i >= 0; i--) {
    final double l = 2 * math.pi * i / kMilkyWaySamples;
    feed(equirectOf(galacticToEquatorial(l, upper), w, h));
  }
  path.close();
  return path;
}

/// 星点：位置、亮度取星表；横向按赤纬预补偿，投影回球面才是圆。
///
/// 贴图层里的星都在 4.76 等以下（更亮的走 billboard），半径 0.5–1.4 像素，
/// 所以按**纬度带**批量画，不逐颗画圆：带内共用一个补偿倍数，`canvas.scale`
/// 把 `drawPoints` 画出的圆点横向拉成椭圆，一次调用画一整带。
void _paintStars(ui.Canvas canvas, List<StarRecord> stars, double w, double h) {
  const int bands = kPolarBand + 1;
  final List<List<ui.Offset>> thin = List<List<ui.Offset>>.generate(
    bands,
    (_) => <ui.Offset>[],
  );
  final List<List<ui.Offset>> thick = List<List<ui.Offset>>.generate(
    bands,
    (_) => <ui.Offset>[],
  );

  for (final StarRecord star in stars) {
    final int band = skyBandOf(star.decDeg);
    // 先按补偿倍数把横坐标除回去：`canvas.scale(s, 1)` 会再乘一遍，
    // 于是落点回到原位，而点本身被横向拉长 s 倍。
    final ui.Offset at = equirectOf(unitVector(star.raDeg, star.decDeg), w, h);
    final ui.Offset stored = ui.Offset(at.dx / skyBandScale(band), at.dy);
    (radiusForMag(star.vMag) >= 1.0 ? thick : thin)[band].add(stored);
  }

  final ui.Paint paint = ui.Paint()
    ..color = const ui.Color.fromARGB(255, 196, 206, 232)
    ..strokeCap = ui.StrokeCap.round;

  for (int band = 0; band < bands; band++) {
    if (thin[band].isEmpty && thick[band].isEmpty) {
      continue;
    }
    canvas.save();
    canvas.scale(skyBandScale(band), 1);
    if (thin[band].isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        thin[band],
        paint..strokeWidth = 1.1,
      );
    }
    if (thick[band].isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        thick[band],
        paint..strokeWidth = 2.0,
      );
    }
    canvas.restore();
  }
}

/// 赤纬落在哪一条纬度带。
int skyBandOf(double decDeg) {
  final double a = decDeg.abs();
  if (a > kPolarCompensationMaxDecDeg) {
    return kPolarBand;
  }
  return (a / kSkyBandDegrees).floor().clamp(0, kSkyBandCount - 1);
}

/// 某条纬度带用的横向补偿倍数。
double skyBandScale(int band) {
  if (band >= kPolarBand) {
    return 1;
  }
  return horizontalScaleForDec((band + 0.5) * kSkyBandDegrees);
}

/// 赤纬处的横向补偿倍数：图上要画宽 `1 / cos φ` 倍，投影回球面才是正圆。
///
/// 为什么是「除以」而不是「乘以」：贴图上横向每像素对应的天球角距是
/// `cos φ` 倍（等距柱状把经度均匀摊开，高纬的一圈被拉长了），所以一个固定
/// 角半径的圆斑在图上横向只占 `cos φ` 那么多像素。要它反过来是圆的，就得
/// 在图上横向放大 `1 / cos φ`。
///
/// 超过 [kPolarCompensationMaxDecDeg] 退回 1：那里倍数发散（85° 时 11.5 倍、
/// 89° 时 57 倍），贴图横向像素也不够，硬补只会把星点抹成横条。
double horizontalScaleForDec(double decDeg) {
  final double a = decDeg.abs();
  if (a > kPolarCompensationMaxDecDeg) {
    return 1;
  }
  return 1 / math.cos(a * math.pi / 180);
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

/// 赤经（**度**）+ 赤纬（度）→ 单位向量。
Vec3 unitVector(double raDeg, double decDeg) {
  final double ra = raDeg * math.pi / 180;
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
/// 横向：赤经 0–360° 铺满整张图；纵向：北天极在顶边、南天极在底边。
/// 赤经接缝（0°/360°）落在图的左右两边，取模回绕。
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
