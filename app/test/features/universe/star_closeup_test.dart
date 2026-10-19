import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/universe/star_closeup.dart';
import 'package:project_knowledge/features/universe/star_closeup_painter.dart';
import 'package:project_knowledge/features/universe/star_map.dart';

import '../../support/pack_fixture.dart';

/// 视口固定 800×600 ⇒ 短边一半 `300`，所有位置与半径都由它唯一决定。
const Size _viewport = Size(800, 600);
const double _half = 300;

/// 三项链 `a → b → c`：两条轨道、两颗行星 —— `Z4` 该露满 `C-81` 条。
LoadedPack _chainPack() => fixturePack(
  const <FixtureItem>[
    FixtureItem('a', '甲', domainId: 'python/lexical'),
    FixtureItem('b', '乙', domainId: 'python/lexical'),
    FixtureItem('c', '丙', domainId: 'python/lexical'),
  ],
  edges: const <List<String>>[
    <String>['a', 'b'],
    <String>['b', 'c'],
  ],
);

/// 五项链 `a → … → e`：四条轨道 —— 验「只露前两条，不是有几层画几层」。
LoadedPack _fiveChainPack() => fixturePack(
  const <FixtureItem>[
    FixtureItem('a', '甲', domainId: 'python/lexical'),
    FixtureItem('b', '乙', domainId: 'python/lexical'),
    FixtureItem('c', '丙', domainId: 'python/lexical'),
    FixtureItem('d', '丁', domainId: 'python/lexical'),
    FixtureItem('e', '戊', domainId: 'python/lexical'),
  ],
  edges: const <List<String>>[
    <String>['a', 'b'],
    <String>['b', 'c'],
    <String>['c', 'd'],
    <String>['d', 'e'],
  ],
);

/// 反旋转到轨道自己的坐标系，再验椭圆方程 `(u/a)² + (v/b)² == 1`。
double _ellipseResidual(StarOrbit orbit, Offset center, Offset point) {
  final double dx = point.dx - center.dx;
  final double dy = point.dy - center.dy;
  final double cosR = math.cos(orbit.rotation);
  final double sinR = math.sin(orbit.rotation);
  final double u = dx * cosR + dy * sinR;
  final double v = -dx * sinR + dy * cosR;
  final double x = u / orbit.semiMajor;
  final double y = v / orbit.semiMinor;
  return x * x + y * y;
}

void main() {
  group('Z4 恒星特写的几何（SPEC-VIEW-040 · V-1f 后半）', () {
    test('恒星 = 选中项，占短边的 C-78 比例、居中（SPEC-VIEW-040）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'a',
        viewport: _viewport,
      );

      expect(layout.itemId, 'a');
      expect(layout.itemLabel, '甲');
      expect(layout.domainId, 'python/lexical');
      expect(layout.starCenter, const Offset(400, 300));
      expect(
        layout.starRadius,
        closeTo(_half * closeupStarRadiusRatio, 1e-9),
        reason: 'Z4 是特写：恒星半径占短边一半的 C-78（0.46），与 Z3 的 C-72 差十倍',
      );
      expect(
        layout.starRadius,
        greaterThan(_half * stellarRadiusRatio * 5),
        reason: '与 Z3 的恒星不是同一个尺度 —— 两档同比例的话必有一档是错的',
      );
    });

    test('只露最内 C-81 条轨道：五条链也只画两条（SPEC-VIEW-040）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _fiveChainPack(),
        itemId: 'a',
        viewport: _viewport,
      );

      expect(
        layout.orbits.length,
        closeupMaxOrbits,
        reason: 'VIEW-040 的边界：「只露能放进画面边缘的 1–2 条，不做成太阳系示意图」',
      );
      expect(layout.orbits.map((StarOrbit each) => each.level), <int>[
        1,
        2,
      ], reason: '取最内两条，不是随便两条');
      expect(layout.planets.map((StarPlanet each) => each.level).toSet(), <int>{
        1,
        2,
      }, reason: '第三层及以后的行星不进这一档 —— 露出来就是「完整轨道族」了');
    });

    test('三条轨道以内就照实露：两项链只有一条（SPEC-VIEW-040）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: fixturePack(
          const <FixtureItem>[
            FixtureItem('a', '甲', domainId: 'python/lexical'),
            FixtureItem('b', '乙', domainId: 'python/lexical'),
          ],
          edges: const <List<String>>[
            <String>['a', 'b'],
          ],
        ),
        itemId: 'a',
        viewport: _viewport,
      );

      expect(layout.orbits.length, 1);
      expect(
        layout.orbits.single.semiMajor,
        closeTo(layout.starRadius * closeupOrbitInnerRatio, 1e-9),
        reason: '只有一条时用**内**比例 —— 那才是「最内那条」，用中点会让「有几层」看不出来',
      );
    });

    test('孤星也画：这一项没有后继，特写照出（SPEC-VIEW-040）', () {
      // 与 Z3 的关键差别：Z3 在这里退回项投影（孤星配空轨道等于说有行星），
      // 而 Z4 是**单星特写**，没有后继正是常态。
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: fixturePack(const <FixtureItem>[
          FixtureItem('solo', '孤', domainId: 'python/lexical'),
        ]),
        itemId: 'solo',
        viewport: _viewport,
      );

      expect(layout.isEmpty, isFalse);
      expect(layout.starRadius, greaterThan(0));
      expect(layout.orbits, isEmpty);
      expect(layout.planets, isEmpty);
      expect(
        layout.granules.length,
        closeupGranuleCount,
        reason: '恒星本体该有的表面纹理不因「没有行星」而缺席',
      );
    });

    test('项不在包里 ⇒ 空；视口为零 ⇒ 空（无 SPEC：与四档同一条入口守卫）', () {
      expect(
        layoutStarCloseup(
          pack: _chainPack(),
          itemId: '不存在',
          viewport: _viewport,
        ),
        isA<StarCloseupLayout>().having(
          (StarCloseupLayout each) => each.isEmpty,
          'isEmpty',
          isTrue,
        ),
      );
      expect(
        layoutStarCloseup(
          pack: _chainPack(),
          itemId: 'a',
          viewport: Size.zero,
        ).isEmpty,
        isTrue,
      );
    });

    test('行星落在这一档自己的椭圆上 —— 推近不是「另一张图」（SPEC-VIEW-040）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'a',
        viewport: _viewport,
      );
      final Map<int, StarOrbit> byLevel = <int, StarOrbit>{
        for (final StarOrbit each in layout.orbits) each.level: each,
      };

      expect(layout.planets, isNotEmpty);
      for (final StarPlanet planet in layout.planets) {
        final StarOrbit orbit = byLevel[planet.level]!;
        expect(
          _ellipseResidual(orbit, layout.starCenter, planet.center),
          closeTo(1, 1e-9),
          reason: '行星 ${planet.id} 必须落在 L${planet.level} 那条椭圆上',
        );
      }
    });

    test('相位沿用 Z3：推近之后行星还在同一个方向上（无 SPEC：两档同源是 R-08 的判据）', () {
      final LoadedPack pack = _chainPack();
      final StarSystemLayout z3 = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout z4 = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );

      for (final StarPlanet each in z3.planets) {
        final StarPlanet? same = z4.planets
            .where((StarPlanet p) => p.id == each.id)
            .firstOrNull;
        if (same == null) {
          continue;
        }
        expect(
          same.phase,
          closeTo(each.phase, 1e-12),
          reason:
              '参数角必须一模一样 —— 两档各算一遍「均分 + 抖动」，'
              '推近就变成换了一张图',
        );
      }
    });

    test('米粒与黑子全落在恒星盘内（SPEC-VIEW-040 第 2 条）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'a',
        viewport: _viewport,
      );

      expect(layout.granules.length, closeupGranuleCount);
      expect(layout.spots.length, closeupSpotCount);
      for (final StarSpeck each in <StarSpeck>[
        ...layout.granules,
        ...layout.spots,
      ]) {
        expect(
          (each.center - layout.starCenter).distance + each.radius,
          lessThanOrEqualTo(layout.starRadius),
          reason: '斑点是**有半径的圆**，圆心在盘内不等于它整体在盘内',
        );
      }
    });

    test('同一项两次布局完全相同 —— 斑点位置由哈希定，禁随机（SPEC-VIEW-040 第 2 条）', () {
      final LoadedPack pack = _chainPack();
      final StarCloseupLayout first = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout second = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );

      for (int i = 0; i < first.granules.length; i++) {
        expect(first.granules[i].center, second.granules[i].center);
        expect(first.granules[i].radius, second.granules[i].radius);
      }
      for (int i = 0; i < first.spots.length; i++) {
        expect(first.spots[i].center, second.spots[i].center);
      }
    });

    test('换一项就换一张脸 —— 哈希真的按 item.id 走（SPEC-VIEW-040 第 2 条）', () {
      final LoadedPack pack = _chainPack();
      final StarCloseupLayout a = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout b = layoutStarCloseup(
        pack: pack,
        itemId: 'b',
        viewport: _viewport,
      );

      expect(
        a.granules.first.center,
        isNot(b.granules.first.center),
        reason: '若两处都取常量或都按序号算，两个项会长得一模一样',
      );
    });

    test('外观不看 Item.type —— 同一项换 type 画出来一样（SPEC-VIEW-040 第 1 条）', () {
      // `type` 是**知识属性**，不是天文类型。按它分「红巨星 / 白矮星」会私开
      // 一条通道，且与 `C-34` 那批（`type = tacit` ≡ 不可外化 ≥ 3 格）同集重合，
      // 等于把同一个事实表达两次。
      final LoadedPack declarative = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
          FixtureItem('b', '乙', domainId: 'python/lexical'),
        ],
        edges: const <List<String>>[
          <String>['a', 'b'],
        ],
        itemType: 'declarative',
      );
      final LoadedPack tacit = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
          FixtureItem('b', '乙', domainId: 'python/lexical'),
        ],
        edges: const <List<String>>[
          <String>['a', 'b'],
        ],
        itemType: 'tacit',
      );

      final StarCloseupLayout one = layoutStarCloseup(
        pack: declarative,
        itemId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout two = layoutStarCloseup(
        pack: tacit,
        itemId: 'a',
        viewport: _viewport,
      );

      expect(one.starRadius, two.starRadius);
      expect(one.accentArgb, two.accentArgb);
      for (int i = 0; i < one.granules.length; i++) {
        expect(one.granules[i].center, two.granules[i].center);
        expect(one.granules[i].radius, two.granules[i].radius);
      }
      for (int i = 0; i < one.spots.length; i++) {
        expect(one.spots[i].center, two.spots[i].center);
      }
    });

    test('筛选只减行星，不减轨道（无 SPEC：与 Z3 / Z2 同口径）', () {
      final LoadedPack pack = _chainPack();
      final StarCloseupLayout all = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout filtered = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
        visibleIds: const <String>{'a', 'b'},
      );

      expect(filtered.orbits.length, all.orbits.length);
      expect(filtered.planets.map((StarPlanet each) => each.id), <String>[
        'b',
      ], reason: 'c 被筛掉 ⇒ 只剩 b；轨道仍是两条');
      for (int i = 0; i < all.orbits.length; i++) {
        expect(filtered.orbits[i].semiMajor, all.orbits[i].semiMajor);
      }
    });
  });

  group('Z4 行星公转（C-56 · V-1i 后半）', () {
    /// 点 [point] 在 [orbit] 上的参数角（rad，`atan2` 口径）。
    double phaseOf(StarOrbit orbit, Offset center, Offset point) {
      final double dx = point.dx - center.dx;
      final double dy = point.dy - center.dy;
      final double cosR = math.cos(orbit.rotation);
      final double sinR = math.sin(orbit.rotation);
      final double u = dx * cosR + dy * sinR;
      final double v = -dx * sinR + dy * cosR;
      return math.atan2(v / orbit.semiMinor, u / orbit.semiMajor);
    }

    test('推近不改变角速度：同一颗行星在 Z3 与 Z4 转过同样的参数角（C-56）', () {
      final LoadedPack pack = _fiveChainPack();
      final StarSystemLayout system = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout closeup = layoutStarCloseup(
        pack: pack,
        itemId: 'a',
        viewport: _viewport,
      );
      expect(
        closeup.levelCount,
        system.orbits.length,
        reason: '`Z4` 只露 `C-81` 条，但算周期要用真实层数',
      );

      const double clock = 3.7;
      final StarSystemLayout later3 = system.advanced(clock);
      final StarCloseupLayout later4 = closeup.advanced(clock);

      for (final StarOrbit orbit in closeup.orbits) {
        final StarPlanet zoomed = closeup.planets.firstWhere(
          (StarPlanet planet) => planet.level == orbit.level,
        );
        final StarOrbit wide = system.orbits[orbit.level - 1];
        final StarPlanet source = system.planetOf(zoomed.id)!;

        final double turned3 =
            phaseOf(wide, system.starCenter, later3.planetOf(zoomed.id)!.center) -
            phaseOf(wide, system.starCenter, source.center);
        final double turned4 =
            phaseOf(orbit, closeup.starCenter, later4.planetOf(zoomed.id)!.center) -
            phaseOf(orbit, closeup.starCenter, zoomed.center);

        expect(
          turned4,
          closeTo(turned3, 1e-9),
          reason: '各按自己档的 `a` 算周期就会在这里分叉 —— 推近瞬间行星会变速',
        );
      }
    });

    test('推进后行星仍在本档的椭圆上（C-79 / C-80 的尺度没被带走）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _fiveChainPack(),
        itemId: 'a',
        viewport: _viewport,
      );
      final StarCloseupLayout later = layout.advanced(2.3);
      for (final StarOrbit orbit in layout.orbits) {
        final StarPlanet planet = later.planets.firstWhere(
          (StarPlanet each) => each.level == orbit.level,
        );
        expect(
          _ellipseResidual(orbit, layout.starCenter, planet.center),
          closeTo(1, 1e-9),
        );
      }
    });

    test('相位为 0 时原样返回；孤星特写不炸（C-56）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'a',
        viewport: _viewport,
      );
      expect(identical(layout.advanced(0), layout), isTrue);

      final StarCloseupLayout lone = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'c',
        viewport: _viewport,
      );
      expect(lone.isEmpty, isFalse, reason: '孤星也是特写（VIEW-040）');
      expect(
        identical(lone.advanced(5), lone),
        isTrue,
        reason: '没有行星可走 ⇒ 原样返回，界面也不该为它启 ticker',
      );
    });
  });

  group('Z4 的绘制指令（SPEC-VIEW-040）', () {
    test('绘制序：轨道 → 恒星 → 米粒 → 黑子 → 行星（无 SPEC：遮挡关系是判据）', () {
      final StarCloseupLayout layout = layoutStarCloseup(
        pack: _chainPack(),
        itemId: 'a',
        viewport: _viewport,
      );
      final _RecordingTarget target = _RecordingTarget();

      paintStarCloseup(target: target, layout: layout);

      final List<String> verbs = target.verbs;
      expect(
        verbs.indexOf('starBody'),
        lessThan(verbs.indexOf('granule')),
        reason: '米粒画在恒星**之上** —— 反过来会被恒星实心盖掉，一颗也看不见',
      );
      expect(
        verbs.indexOf('starBody'),
        lessThan(verbs.indexOf('planet')),
        reason: '行星压在恒星之后：按「由远及近」排会让内轨那颗消失一半',
      );
      expect(
        verbs.where((String each) => each == 'orbit').length,
        layout.orbits.length,
      );
      expect(
        verbs.where((String each) => each == 'granule').length,
        closeupGranuleCount,
      );
      expect(
        verbs.where((String each) => each == 'spot').length,
        closeupSpotCount,
      );
    });

    test('空布局一条指令都不发（无 SPEC：空包不该画半个恒星）', () {
      final _RecordingTarget target = _RecordingTarget();
      paintStarCloseup(target: target, layout: StarCloseupLayout.empty);
      expect(target.verbs, isEmpty);
    });
  });
}

/// 只记账的绘制目标 —— 真实路径直通画布、这条路径只记动词。
class _RecordingTarget implements CloseupDrawTarget {
  final List<String> verbs = <String>[];

  @override
  void granule({required Offset center, required double radius}) {
    verbs.add('granule');
  }

  @override
  void orbit({
    required Offset center,
    required double semiMajor,
    required double semiMinor,
    required double rotation,
  }) {
    verbs.add('orbit');
  }

  @override
  void planet({required Offset center, required double radius}) {
    verbs.add('planet');
  }

  @override
  void spot({required Offset center, required double radius}) {
    verbs.add('spot');
  }

  @override
  void starBody({
    required Offset center,
    required double radius,
    required int argb,
  }) {
    verbs.add('starBody');
  }
}
