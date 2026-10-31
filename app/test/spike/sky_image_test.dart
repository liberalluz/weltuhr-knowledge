import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/spike/sky_image.dart';

/// 天球贴图里那些**纯算术**的用例：坐标映射、银道面旋转、极区补偿、
/// 银河羽化、星等与颜色。
///
/// 除 `TC-SPIKE-028` 外都不碰画布：那一条要读像素，因为「银河边缘有没有缝」
/// 是抗锯齿的产物，纯算术测不到。其余几条是「星星位置为什么对」「极区为什么
/// 不再拉成椭圆」的全部依据 —— 画出来的东西对不对，肉眼只能验个大概（看着像
/// 夜空 ≠ 位置正确）；而映射算错了，画面照样漂亮。
void main() {
  const double w = 4096;
  const double h = 2048;

  test('TC-SPIKE-012 赤经赤纬铺满整张等距柱状图（ADR-0006 决策表·背景）', () {
    // 赤经 0° 在左边缘，180° 在正中。
    expect(equirectOf(unitVector(0, 0), w, h).dx, closeTo(0, 1e-6));
    expect(equirectOf(unitVector(180, 0), w, h).dx, closeTo(w / 2, 1e-6));
    // 赤纬 +90° 在顶边，−90° 在底边，0° 在中线。
    expect(equirectOf(unitVector(0, 90), w, h).dy, closeTo(0, 1e-6));
    expect(equirectOf(unitVector(0, -90), w, h).dy, closeTo(h, 1e-6));
    expect(equirectOf(unitVector(0, 0), w, h).dy, closeTo(h / 2, 1e-6));
    // 赤经 360° 与 0° 是同一条接缝：落在右边缘与左边缘，横向差正好一整张图。
    expect(
      equirectOf(unitVector(360, 0), w, h).dx -
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
    expect(radiusForMag(-1.44), greaterThan(radiusForMag(4.0)));
    expect(radiusForMag(4.0), greaterThan(radiusForMag(9.0)));
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

  test('TC-SPIKE-026 极区补偿倍数在赤道为 1、按 1/cos 增大、超 80° 退回 1（ADR-0006 决策表·背景）', () {
    // 赤道不需要补偿。
    expect(horizontalScaleForDec(0), closeTo(1.0, 1e-12));
    // 60°：图上横向要画宽一倍，投影回去才是圆。
    expect(horizontalScaleForDec(60), closeTo(2.0, 1e-9));
    expect(horizontalScaleForDec(-60), closeTo(2.0, 1e-9), reason: '南北对称');
    // 80°：1/cos80° ≈ 5.759。
    expect(
      horizontalScaleForDec(80),
      closeTo(1 / math.cos(80 * math.pi / 180), 1e-9),
    );
    expect(horizontalScaleForDec(80), closeTo(5.7588, 1e-3));
    // 单调：纬度越高倍率越大（区间内）。
    double previous = 0;
    for (double dec = 0; dec <= 80; dec += 5) {
      final double scale = horizontalScaleForDec(dec);
      expect(scale, greaterThanOrEqualTo(previous), reason: '赤纬 $dec 处');
      previous = scale;
    }
    // 超过 80° 退回 1：倍数在那里发散（85° 是 11.5 倍、89° 是 57 倍），
    // 贴图横向像素也不够，硬补只会把星点抹成横条。
    expect(horizontalScaleForDec(81), closeTo(1.0, 1e-12));
    expect(horizontalScaleForDec(90), closeTo(1.0, 1e-12));
  });

  test('TC-SPIKE-027 纬度带把星分到带内，带倍率取带中心（ADR-0006 决策表·背景）', () {
    // 带宽度 2.5°，第 0 带中心 1.25°。
    expect(skyBandOf(0), 0);
    expect(skyBandOf(2.4), 0);
    expect(skyBandOf(2.6), 1);
    expect(skyBandOf(-40), skyBandOf(40), reason: '南北同带');
    // 超过 80° 全部进「不补偿」档。
    expect(skyBandOf(80.1), kPolarBand);
    expect(skyBandOf(-89.9), kPolarBand);
    expect(skyBandOf(kPolarCompensationMaxDecDeg), lessThan(kPolarBand));

    // 带倍率 = 带中心的 1/cos；不补偿档恒为 1。
    expect(skyBandScale(0), closeTo(horizontalScaleForDec(1.25), 1e-12));
    expect(
      skyBandScale(kSkyBandCount - 1),
      closeTo(horizontalScaleForDec(78.75), 1e-12),
      reason: '最后一带中心 = (31 + 0.5) × 2.5°',
    );
    expect(skyBandScale(kPolarBand), 1.0);
    // 带号越大倍率越大（0 到最后一档）。
    for (int band = 1; band < kSkyBandCount; band++) {
      expect(
        skyBandScale(band),
        greaterThan(skyBandScale(band - 1)),
        reason: '第 $band 带',
      );
    }
  });

  test('TC-SPIKE-028 银河边缘无阶跃：渲图后沿银道面法向采样（ADR-0006 决策表·布局）', () async {
    // 这条要读**画出来的像素**，不是算公式 —— 段 3 的分层实现在公式上是连续
    // 的（(1−t)² 单调），缝只出现在填充的抗锯齿里，纯算术测不到。
    const int tw = 2048;
    const int th = 1024;
    final ui.Image image = await paintSkyImage(
      stars: const [],
      width: tw,
      height: th,
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    final ByteData data = bytes!;

    int blueAt(double lDeg, double bDeg) {
      final ui.Offset at = equirectOf(
        galacticToEquatorial(lDeg * math.pi / 180, bDeg * math.pi / 180),
        tw.toDouble(),
        th.toDouble(),
      );
      final int x = at.dx.floor().clamp(0, tw - 1);
      final int y = at.dy.floor().clamp(0, th - 1);
      return data.getUint8((y * tw + x) * 4 + 2);
    }

    // 沿银经 0° 的法向，从银道面走到带外 3°（半宽 9° 之外）。
    final List<int> profile = <int>[];
    for (double b = 0; b <= 12.0001; b += 0.25) {
      profile.add(blueAt(0, b));
    }

    // 1) 中心明显亮于带外 —— 羽化还在，没有被抹成一片灰。
    expect(
      profile.first,
      greaterThan(profile.last + 8),
      reason: '银道面中心 $profile.first 应明显亮于带外 ${profile.last}',
    );

    // 2) 没有阶跃：相邻采样点（0.25° ≈ 1.4 像素）的亮度差不超过 3/255。
    //    分层实现每 0.75° 跳 4–8/255，这一条会红 —— 见 PR 正文的反证。
    for (int i = 1; i < profile.length; i++) {
      expect(
        (profile[i] - profile[i - 1]).abs(),
        lessThanOrEqualTo(3),
        reason:
            '银纬 ${(i * 0.25).toStringAsFixed(2)}° 处跳变 ${profile[i] - profile[i - 1]}',
      );
    }

    // 3) 单调不增：从银道面往外不会又亮回去。留 1/255 给量化。
    for (int i = 1; i < profile.length; i++) {
      expect(
        profile[i],
        lessThanOrEqualTo(profile[i - 1] + 1),
        reason: '银纬 ${(i * 0.25).toStringAsFixed(2)}°',
      );
    }

    // 4) 到半宽之后已经贴平背景 —— 「边界收敛到 0」的渲图版判据。
    expect(
      (profile[36] - profile.last).abs(),
      lessThanOrEqualTo(1),
      reason: '半宽 9° 处 $profile[36] 与带外 ${profile.last} 应有区别',
    );
  });
}
