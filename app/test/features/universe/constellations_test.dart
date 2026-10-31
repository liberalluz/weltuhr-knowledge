/// 星座连线的用例。
///
/// 连线本身没有「官方正确答案」—— 国际天文学联合会只划天区边界，勺子与 W 是
/// 各家星图自己连的。所以这里能断言的是两件可核的事：**每颗星都真实存在于
/// Hipparcos 表**、**每颗星都落在自己那组星的天区里**；再加上投影与渐隐这两处
/// 纯算术。画出来像不像北斗，只能靠实机看。
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/features/universe/presentation/constellations.dart';
import 'package:project_knowledge/features/universe/presentation/sky_image.dart';
import 'package:project_knowledge/features/universe/presentation/star_catalog.dart';

/// 只带姿态的假相机：投影只需要 yaw / pitch / fov 三个数。
class _View implements SkyView {
  _View({required this.yaw, required this.pitch, required this.fovDeg});

  @override
  final double yaw;

  @override
  final double pitch;

  @override
  final double fovDeg;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StarCatalog catalog;
  late Map<int, StarRecord> byHip;

  setUpAll(() async {
    catalog = await loadHipparcosCatalog(cwd: Directory.current.path);
    byHip = <int, StarRecord>{
      for (final StarRecord star in catalog.stars) star.hip: star,
    };
  });

  test('TC-SPIKE-037 三条星座的段表：北斗 7 段、猎户 7 段、仙后 4 段（ADR-0006 修订九）', () {
    expect(kConstellations.map((Constellation c) => c.name).toList(), <String>[
      '北斗',
      '猎户',
      '仙后',
    ]);
    expect(
      kConstellations.map((Constellation c) => c.segments.length).toList(),
      <int>[7, 7, 4],
    );

    // 北斗：斗勺闭合（摇光回天枢）+ 斗柄。闭合这一段是「勺子」与「一把折线」
    // 的唯一区别，漏了画面上就是个问号。
    expect(_pairs(kConstellations[0]), <String>[
      '54061-53910',
      '53910-58001',
      '58001-59774',
      '59774-54061',
      '59774-62956',
      '62956-65378',
      '65378-67301',
    ]);

    // 仙后：W 形，4 段 5 点。
    expect(_pairs(kConstellations[2]), <String>[
      '746-3179',
      '3179-4427',
      '4427-6686',
      '6686-8886',
    ]);
  });

  test('TC-SPIKE-038 每颗星都在星表里，且落在本组质心 20° 内（ADR-0006 修订九）', () {
    for (final Constellation constellation in kConstellations) {
      final Set<int> hips = <int>{
        for (final ConstellationSegment s in constellation.segments) ...<int>[
          s.from,
          s.to,
        ],
      };

      final List<Vec3> vectors = <Vec3>[];
      for (final int hip in hips) {
        final StarRecord? star = byHip[hip];
        expect(star, isNotNull, reason: '${constellation.name}：HIP $hip 不在星表里');
        vectors.add(unitVector(star!.raDeg, star.decDeg));
      }

      // 质心 = 单位向量求和后再归一化（直接平均赤经赤纬会在 0h/24h 附近翻车）。
      double sx = 0;
      double sy = 0;
      double sz = 0;
      for (final Vec3 v in vectors) {
        sx += v.x;
        sy += v.y;
        sz += v.z;
      }
      final double norm = math.sqrt(sx * sx + sy * sy + sz * sz);
      final Vec3 center = Vec3(sx / norm, sy / norm, sz / norm);

      double worst = 0;
      for (final Vec3 v in vectors) {
        final double dot = (v.x * center.x + v.y * center.y + v.z * center.z)
            .clamp(-1.0, 1.0);
        worst = math.max(worst, math.acos(dot) * 180 / math.pi);
      }
      expect(
        worst,
        lessThanOrEqualTo(20.0),
        reason:
            '${constellation.name} 最远一颗距质心 ${worst.toStringAsFixed(1)}°，'
            '不是同一个天区的星',
      );

      // 段表里不该出现跨等距柱状接缝的线（三条星座都离 0h 足够远）。
      for (final ConstellationSegment s in constellation.segments) {
        expect(
          crossesSeam(byHip[s.from]!.raDeg, byHip[s.to]!.raDeg),
          isFalse,
          reason: '${constellation.name} 的 ${s.from}-${s.to} 跨了接缝',
        );
      }
    }
  });

  test('TC-SPIKE-039 连线在 60°–80° 之间线性淡出，之外为满值或零（ADR-0006 修订九）', () {
    expect(constellationOpacity(20), 1.0);
    expect(constellationOpacity(60), 1.0);
    expect(constellationOpacity(70), closeTo(0.5, 1e-12));
    expect(constellationOpacity(80), 0.0);
    expect(constellationOpacity(100), 0.0);

    double previous = 1.1;
    for (double fov = 60; fov <= 80; fov += 2) {
      final double opacity = constellationOpacity(fov);
      expect(opacity, lessThanOrEqualTo(previous), reason: 'fov $fov 处不单调');
      expect(opacity, greaterThanOrEqualTo(0.0));
      previous = opacity;
    }
  });

  test('TC-SPIKE-040 视线正对的星投到画面中心，背后的星返回 null（ADR-0006 修订九）', () {
    // 相机 yaw=0 / pitch=0 时，场景里看向 +Z，即星表的赤经 6h、赤纬 0°。
    final SkyProjection projection = SkyProjection(
      view: _View(yaw: 0, pitch: 0, fovDeg: 70),
      size: const ui.Size(800, 600),
    );

    final ui.Offset? center = projection.project(unitVector(90, 0));
    expect(center, isNotNull);
    expect(center!.dx, closeTo(400, 1e-9));
    expect(center.dy, closeTo(300, 1e-9));

    // 赤经差 180° ⇒ 正后方。
    expect(projection.project(unitVector(270, 0)), isNull);

    // 赤经增大 30°：落到中心的某一侧；赤纬 +10°：落到中心上方。
    final ui.Offset? east = projection.project(unitVector(120, 0));
    expect(east, isNotNull);
    expect((east!.dx - 400).abs(), greaterThan(1));
    final ui.Offset? north = projection.project(unitVector(90, 10));
    expect(north, isNotNull);
    expect(north!.dy, lessThan(300));
  });

  test('TC-SPIKE-041 赤经差超过半圈即判跨接缝，等于半圈不算（ADR-0006 修订九）', () {
    expect(crossesSeam(359, 1), isTrue);
    expect(crossesSeam(1, 359), isTrue);
    expect(crossesSeam(10, 20), isFalse);
    expect(crossesSeam(0, 180), isFalse);
  });
}

List<String> _pairs(Constellation constellation) => <String>[
  for (final ConstellationSegment s in constellation.segments)
    '${s.from}-${s.to}',
];
