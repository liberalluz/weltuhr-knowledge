import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/spike/sky_image.dart';

/// 天球贴图里那些**纯算术**的用例：坐标映射、银道面旋转、星等与颜色。
///
/// 这几条不碰 GPU，也不画图 —— 但它们是「星星位置为什么对」的全部依据。
/// 画出来的东西对不对，肉眼只能验个大概（看着像夜空 ≠ 位置正确）；
/// 而映射算错了，画面照样漂亮。
void main() {
  const double w = 4096;
  const double h = 2048;

  test('TC-SPIKE-012 赤经赤纬铺满整张等距柱状图（ADR-0006 决策表·背景）', () {
    // 赤经 0h 在左边缘，12h 在正中。
    expect(equirectOf(unitVector(0, 0), w, h).dx, closeTo(0, 1e-6));
    expect(equirectOf(unitVector(12, 0), w, h).dx, closeTo(w / 2, 1e-6));
    // 赤纬 +90° 在顶边，−90° 在底边，0° 在中线。
    expect(equirectOf(unitVector(0, 90), w, h).dy, closeTo(0, 1e-6));
    expect(equirectOf(unitVector(0, -90), w, h).dy, closeTo(h, 1e-6));
    expect(equirectOf(unitVector(0, 0), w, h).dy, closeTo(h / 2, 1e-6));
    // 赤经 24h 与 0h 是同一条接缝：落在右边缘与左边缘，横向差正好一整张图。
    expect(
      equirectOf(unitVector(24, 0), w, h).dx -
          equirectOf(unitVector(0, 0), w, h).dx,
      closeTo(w, 1),
    );
  });

  test('TC-SPIKE-013 银道面旋转给出正确的银极坐标（ADR-0006 决策表·背景）', () {
    // 银纬 +90° 就是银极：J2000 赤经 192.86°、赤纬 +27.13°。
    final Vec3 pole = galacticToEquatorial(0, math.pi / 2);
    final ui.Offset at = equirectOf(pole, w, h);
    final double raDeg = at.dx / w * 360;
    final double decDeg = 90 - at.dy / h * 180;

    expect(raDeg, closeTo(192.86, 0.05));
    expect(decDeg, closeTo(27.13, 0.05));
  });

  test('TC-SPIKE-014 星等越亮光斑越大，且不越界（ADR-0006 决策二·bloom）', () {
    expect(radiusForMag(kBrightestMag), closeTo(kBrightestMagRadius, 1e-9));
    expect(radiusForMag(kFaintestMag), closeTo(kFaintestMagRadius, 1e-9));
    // 越界值夹住，不产生负数或负数半径。
    expect(radiusForMag(-30), closeTo(kBrightestMagRadius, 1e-9));
    expect(radiusForMag(30), closeTo(kFaintestMagRadius, 1e-9));
    // 单调：亮星（星等小）必须比暗星大。
    expect(radiusForMag(-1.46), greaterThan(radiusForMag(4.0)));
    expect(radiusForMag(4.0), greaterThan(radiusForMag(7.9)));
  });

  test('TC-SPIKE-015 色指数从蓝到红单调过渡，端点夹住（ADR-0006 决策表·色彩）', () {
    // B−V 越负越蓝：蓝通道递减、红通道递增。
    final ui.Color blue = colorForBv(-0.4);
    final ui.Color white = colorForBv(0.4);
    final ui.Color red = colorForBv(2.0);

    expect(blue.b, greaterThan(blue.r));
    expect(red.r, greaterThan(red.b));
    // 中间档是接近白的三通道均衡，不该偏到任一端。
    expect((white.r - white.b).abs(), lessThan(20), reason: 'B−V 0.4 接近太阳色，偏白');
    // 单调：三次取值里红通道不降、蓝通道不升。
    expect(blue.r, lessThanOrEqualTo(white.r));
    expect(white.r, lessThanOrEqualTo(red.r));
    expect(blue.b, greaterThanOrEqualTo(white.b));
    expect(white.b, greaterThanOrEqualTo(red.b));
    // 越界夹住。
    expect(colorForBv(-5).r, blue.r);
    expect(colorForBv(5).r, red.r);
  });

  test('TC-SPIKE-016 色指数缺失时按光谱型兜底（ADR-0006 决策表·色彩）', () {
    // 参宿四是 M 型，橙红；织女星是 A 型，蓝白。
    final ui.Color m = colorForSpectralClass('M2Iab');
    final ui.Color a = colorForSpectralClass('A0Va');
    expect(m.r, greaterThan(m.b), reason: 'M 型偏红');
    expect(a.b, greaterThanOrEqualTo(a.r), reason: 'A 型偏蓝');
    // 小写与空串都要能兜住，不能抛。
    expect(() => colorForSpectralClass('k1iii'), returnsNormally);
    expect(() => colorForSpectralClass(''), returnsNormally);
  });
}
