import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/universe/star_map.dart';

import '../../support/pack_fixture.dart';

/// 视口固定成 800×600 —— 位置与半径都由几何唯一决定，断言里的距离按它算。
const Size _viewport = Size(800, 600);

/// 800×600 下视口**短边的一半**。三个尺寸判据（恒星、内轨、外轨）都按它算。
const double _half = 300;

/// 一条三项链：`a → b → c`，同域。
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

/// `a` 有两个直接后继 ⇒ 同层两颗（`b` / `c`），`d` 在第二层。
LoadedPack _forkPack() => fixturePack(
  const <FixtureItem>[
    FixtureItem('a', '甲', domainId: 'python/lexical'),
    FixtureItem('b', '乙', domainId: 'python/lexical'),
    FixtureItem('c', '丙', domainId: 'python/lexical'),
    FixtureItem('d', '丁', domainId: 'python/lexical'),
  ],
  edges: const <List<String>>[
    <String>['a', 'b'],
    <String>['a', 'c'],
    <String>['b', 'd'],
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
  group('Z3 恒星系的几何（SPEC-VIEW-039 · V-1e）', () {
    test('恒星 = 选中项，行星 = 它在同域的后继（SPEC-VIEW-039）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      expect(layout.rootId, 'a');
      expect(layout.rootLabel, '甲');
      expect(layout.domainId, 'python/lexical');
      expect(
        layout.planets.map((StarPlanet each) => each.id),
        <String>['b', 'c'],
        reason: '顺序按包内出现顺序 —— 换一次顺序不该换一次恒星系',
      );
      expect(layout.memberCount, 3, reason: '含恒星：a 可达 a / b / c');
    });

    test('只画这一棵子树：同一域的另一个根不进这个恒星系（SPEC-VIEW-039）', () {
      // `x` 与链同域但没有任何前置 ⇒ 它是另一个恒星系的根。
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
          FixtureItem('b', '乙', domainId: 'python/lexical'),
          FixtureItem('x', '习', domainId: 'python/lexical'),
        ],
        edges: const <List<String>>[
          <String>['a', 'b'],
        ],
      );
      final StarSystemLayout layout = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
      );

      expect(
        layout.planets.map((StarPlanet each) => each.id),
        <String>['b'],
        reason: '`VIEW-039` 写的是「一条 `⪯` 链」—— `x` 是另一个根，属另一个恒星系',
      );
    });

    test('跨域后继不算行星（SPEC-VIEW-039）', () {
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
          FixtureItem('x', '习', domainId: 'python/vocab'),
        ],
        edges: const <List<String>>[
          <String>['a', 'x'],
        ],
      );

      expect(
        layoutStarSystem(pack: pack, rootId: 'a', viewport: _viewport).isEmpty,
        isTrue,
        reason: '跨域边不是这个域里的「先学」关系，`subtreesInDomain()` 口径 1 同理',
      );
    });

    test('轨道数 = 最大层号（SPEC-VIEW-039 / φ）', () {
      final StarSystemLayout chain = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      expect(chain.orbits.length, 2, reason: 'a→b→c：b 在第一层、c 在第二层');

      final StarSystemLayout fork = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      expect(
        fork.orbits.length,
        2,
        reason: 'a 有 b / c 两个直接后继（同层）+ b→d（第二层）⇒ 仍是两层',
      );
      expect(
        fork.planets.where((StarPlanet each) => each.level == 1).length,
        2,
        reason: 'b 与 c 都在第一层',
      );
    });

    test('层号 → 轨道半径单调递增，最内 / 最外对得上 C-73 / C-74（SPEC-VIEW-039 / C-73 / C-74）', () {
      // 造一条四层链，才看得出「最内」与「最外」是两端。
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
          FixtureItem('b', '乙', domainId: 'python/lexical'),
          FixtureItem('c', '丙', domainId: 'python/lexical'),
          FixtureItem('d', '丁', domainId: 'python/lexical'),
        ],
        edges: const <List<String>>[
          <String>['a', 'b'],
          <String>['b', 'c'],
          <String>['c', 'd'],
        ],
      );
      final StarSystemLayout layout = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
      );

      expect(layout.orbits.length, 3);
      expect(
        layout.orbits.first.semiMajor,
        closeTo(_half * stellarOrbitInnerRatio, 0.001),
        reason: '最内轨 = C-73 × 短边一半',
      );
      expect(
        layout.orbits.last.semiMajor,
        closeTo(_half * stellarOrbitOuterRatio, 0.001),
        reason: '最外轨 = C-74 × 短边一半',
      );
      for (int i = 1; i < layout.orbits.length; i++) {
        expect(
          layout.orbits[i].semiMajor,
          greaterThan(layout.orbits[i - 1].semiMajor),
          reason: 'φ 越大越外 —— 反了就读成「先学后面的在天上」',
        );
      }
    });

    test('共面：每颗行星都落在自己那条椭圆上（SPEC-VIEW-039 第 2 条）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      for (final StarPlanet planet in layout.planets) {
        final StarOrbit orbit = layout.orbits[planet.level - 1];
        expect(
          _ellipseResidual(orbit, layout.starCenter, planet.center),
          closeTo(1, 0.001),
          reason: '${planet.id} 不在第 ${planet.level} 条轨道上',
        );
      }
    });

    test('同心：九个同心椭圆共享一个圆心，倾角差为 0（SPEC-VIEW-039 第 2 条）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      // 「倾角差 0」在正对黄道面的视野里等价于「长短轴都是屏幕上的实数、
      // 不经投影」。可观测的形式是 `b / a == sqrt(1 - e²)` 且 `e` 不超过
      // `C-75` —— 若哪条轨道偷偷按倾角压扁了，比值就对不上自己的 `e`。
      for (final StarOrbit orbit in layout.orbits) {
        expect(
          orbit.eccentricity,
          lessThanOrEqualTo(stellarOrbitEccentricityMax),
          reason: '偏心率超上限就是在用扁度编码「第几层」',
        );
        expect(
          orbit.semiMinor / orbit.semiMajor,
          closeTo(math.sqrt(1 - orbit.eccentricity * orbit.eccentricity), 1e-9),
        );
      }
    });

    test('同层多颗共轨：它们落在同一条轨道上，方位不重合（SPEC-VIEW-039 退化段）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      final List<StarPlanet> level1 = <StarPlanet>[
        for (final StarPlanet each in layout.planets)
          if (each.level == 1) each,
      ];

      expect(level1.length, 2);
      for (final StarPlanet planet in level1) {
        expect(
          _ellipseResidual(layout.orbits[0], layout.starCenter, planet.center),
          closeTo(1, 0.001),
          reason: '都该在第一层那一条轨道上',
        );
      }
      expect(
        (level1[0].center - level1[1].center).distance,
        greaterThan(stellarPlanetRadius * 4),
        reason: '同层均分方位 —— 重合就成了一颗',
      );
    });

    test('确定性：同一个恒星系算两次逐项相等（无 SPEC：VIEW-039 未写，但禁随机是 X-02 的下限）', () {
      final StarSystemLayout first = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      final StarSystemLayout second = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      expect(first.orbits.length, second.orbits.length);
      for (int i = 0; i < first.orbits.length; i++) {
        expect(first.orbits[i].rotation, second.orbits[i].rotation);
        expect(first.orbits[i].eccentricity, second.orbits[i].eccentricity);
      }
      expect(
        first.planets.map((StarPlanet each) => each.center),
        second.planets.map((StarPlanet each) => each.center),
        reason: '两次打开像换了一个恒星系，是这一类实现最常见的错',
      );
      expect(first.wisps.map((StarWisp each) => each.center),
          second.wisps.map((StarWisp each) => each.center));
    });

    test('筛选只减行星：轨道数不变，其余行星位置不动（SPEC-VIEW-039）', () {
      final LoadedPack pack = _chainPack();
      final StarSystemLayout full = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
      );
      final StarSystemLayout filtered = layoutStarSystem(
        pack: pack,
        rootId: 'a',
        viewport: _viewport,
        visibleIds: <String>{'a', 'b'},
      );

      expect(filtered.planets.map((StarPlanet each) => each.id), <String>['b']);
      expect(
        filtered.orbits.length,
        full.orbits.length,
        reason: '筛掉一项不该让轨道消失 —— 结构不因筛选改变',
      );
      expect(
        filtered.planetOf('b')!.center,
        full.planetOf('b')!.center,
        reason: '筛掉 c 让 b 换个位置，等于「同一份数据两个恒星系」',
      );
    });

    test('行星被筛空时恒星系仍然在 —— 只是没有行星（SPEC-VIEW-039 / 与 Z2 同口径）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
        visibleIds: <String>{'a'},
      );

      expect(layout.planets, isEmpty);
      expect(
        layout.isEmpty,
        isFalse,
        reason: '退回项场景会让用户以为「这个域没有恒星系了」，而它只是被筛过',
      );
    });

    test('没有后继 ⇒ 空（一颗孤星没有轨道可画）（SPEC-VIEW-039）', () {
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('a', '甲', domainId: 'python/lexical'),
        ],
      );

      expect(
        layoutStarSystem(pack: pack, rootId: 'a', viewport: _viewport).isEmpty,
        isTrue,
      );
    });

    test('选中的项不在包里 ⇒ 空（SPEC-VIEW-039）', () {
      expect(
        layoutStarSystem(
          pack: _chainPack(),
          rootId: 'nope',
          viewport: _viewport,
        ).isEmpty,
        isTrue,
      );
    });

    test('残余云气数固定，且不越出内轨（SPEC-VIEW-039 / C-77）', () {
      // 两项的链与四项的链，云气数必须**一模一样** —— 跟项数走就多一条
      // 「项数」通道（`X-02`）。
      final StarSystemLayout small = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      final StarSystemLayout big = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      expect(small.wisps.length, stellarWispCount);
      expect(big.wisps.length, stellarWispCount);
      const double innerA = _half * stellarOrbitInnerRatio;
      for (final StarWisp wisp in small.wisps) {
        final double r = (wisp.center - small.starCenter).distance;
        expect(
          r,
          lessThan(innerA),
          reason: '云气越过内轨就会盖住最里面那颗行星',
        );
        expect(r, greaterThanOrEqualTo(small.starRadius * 1.2 - 0.001));
      }
    });

    test('恒星半径 = C-72 × 短边一半（SPEC-VIEW-039 / C-72）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );

      expect(layout.starRadius, closeTo(_half * stellarRadiusRatio, 0.001));
      expect(
        layout.starCenter,
        const Offset(400, 300),
        reason: '恒星在视口正中',
      );
    });

    test('行星命中 12 px，画多大不影响点得中（SPEC-VIEW-039 / C-76）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      final StarPlanet planet = layout.planets.first;
      // `domainMarkMinTapDiameter` 是**直径** 24 ⇒ 半径 12。与 `Z1` 域点、
      // `Z2` 亮结同一套（`VIEW-037`）。
      const double hit = domainMarkMinTapDiameter / 2;

      expect(
        pickStarPlanetAt(layout: layout, point: planet.center)?.id,
        planet.id,
      );
      expect(
        pickStarPlanetAt(
          layout: layout,
          point: planet.center + Offset(0, -(hit - 2)),
        )?.id,
        planet.id,
        reason: '行星只画 2.6 px，按绘制半径判就永远点不中',
      );
      expect(
        pickStarPlanetAt(
          layout: layout,
          point: planet.center + Offset(0, -(hit + 2)),
        ),
        isNull,
        reason: '超出命中圈不该再命中 —— 否则相邻轨道的行星会互相抢',
      );
    });

    test('恒星按 max(半径, 12 px) 判命中：大窗口按半径、小窗口按 12（SPEC-VIEW-039）', () {
      final StarSystemLayout big = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      // 800×600 下恒星半径 13.5 > 12 ⇒ 命中圈就是恒星自己那个圆。
      expect(big.starRadius, greaterThan(domainMarkMinTapDiameter / 2));
      expect(hitsStarAt(layout: big, point: big.starCenter), isTrue);
      expect(
        hitsStarAt(
          layout: big,
          point: big.starCenter + Offset(0, big.starRadius - 2),
        ),
        isTrue,
      );
      expect(
        hitsStarAt(
          layout: big,
          point: big.starCenter + Offset(0, big.starRadius + 2),
        ),
        isFalse,
        reason: '大窗口下命中圈不该无端放大到 24 px',
      );

      // 400×300 下恒星半径 6.75 < 12 ⇒ 命中圈由 12 兜底，否则点不中。
      final StarSystemLayout small = layoutStarSystem(
        pack: _chainPack(),
        rootId: 'a',
        viewport: const Size(400, 300),
      );
      expect(small.starRadius, lessThan(domainMarkMinTapDiameter / 2));
      expect(
        hitsStarAt(layout: small, point: small.starCenter + const Offset(0, 10)),
        isTrue,
        reason: '画 6.75 px 却只判 6.75 px ⇒ 看得见点不中',
      );
      expect(
        hitsStarAt(layout: small, point: small.starCenter + const Offset(0, 14)),
        isFalse,
      );
    });

    test('空视口不炸（SPEC-VIEW-039）', () {
      expect(
        layoutStarSystem(
          pack: _chainPack(),
          rootId: 'a',
          viewport: Size.zero,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('行星公转（C-56 · V-1i 后半）', () {
    /// 点 [point] 在轨道上的**参数角**（rad，`atan2` 口径，落在 `-π…π`）。
    ///
    /// 与 [_ellipseResidual] 同一段反旋转，只是把「在不在椭圆上」换成「在椭圆上
    /// 的哪一点」。用它而不是直接比坐标：坐标里混着长轴朝向与半轴长度，两处各差
    /// 一点会让「转了多少」算不准。
    double phaseOf(StarOrbit orbit, Offset center, Offset point) {
      final double dx = point.dx - center.dx;
      final double dy = point.dy - center.dy;
      final double cosR = math.cos(orbit.rotation);
      final double sinR = math.sin(orbit.rotation);
      final double u = dx * cosR + dy * sinR;
      final double v = -dx * sinR + dy * cosR;
      return math.atan2(v / orbit.semiMinor, u / orbit.semiMajor);
    }

    /// 两个角的差，折进 `0…2π` —— `atan2` 在 ±π 处翻号，直接相减会得到 `-2π`。
    double turnedBy(double from, double to) {
      final double d = (to - from) % (2 * math.pi);
      return d < 0 ? d + 2 * math.pi : d;
    }

    test('最内层用 C-56，外层按开普勒 a^1.5 变慢（C-56）', () {
      expect(
        starOrbitPeriodSeconds(1, 1),
        innerOrbitPeriodSeconds.toDouble(),
        reason: '只有一层时它就是最内层',
      );
      expect(starOrbitPeriodSeconds(1, 3), innerOrbitPeriodSeconds.toDouble());

      // `Z3` 的轨道半径按层号等分，所以 n 层时 a_2 / a_1 = C-74 / C-73。
      const double ratio = stellarOrbitOuterRatio / stellarOrbitInnerRatio;
      expect(
        starOrbitPeriodSeconds(2, 2),
        closeTo(
          (innerOrbitPeriodSeconds * math.pow(ratio, 1.5)).toDouble(),
          1e-9,
        ),
      );
      expect(
        starOrbitPeriodSeconds(2, 2),
        greaterThan(innerOrbitPeriodSeconds.toDouble()),
        reason: '「越外越慢」是真实特征，同周期一眼看得出是假的',
      );
    });

    test('周期只由层号定 —— 层数变了周期跟着变，与当前档的轨道半径无关（C-56）', () {
      // 四层时第二层的 a 比值是 `1 + (C74/C73 - 1)/3`，与两层时的 `C74/C73`
      // 不同。这条守的是「`Z4` 的 `C-79` / `C-80` 不参与算周期」：若某处偷用了
      // 当前布局的 `semiMajor`，两层与四层就会得到同一批周期。
      expect(
        starOrbitPeriodSeconds(2, 4),
        lessThan(starOrbitPeriodSeconds(2, 2)),
        reason: '层数多 ⇒ 第二层相对更靠内 ⇒ 走得更快',
      );
    });

    test('相位推进：四分之一周期转 90° 参数角，一个周期回到原位（C-56）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      final StarOrbit inner = layout.orbits.first;
      final StarPlanet before = layout.planets.firstWhere(
        (StarPlanet planet) => planet.level == 1,
      );
      final double t1 = starOrbitPeriodSeconds(1, layout.orbits.length);

      final StarPlanet quarter = layout
          .advanced(t1 / 4)
          .planetOf(before.id)!;
      expect(
        turnedBy(
          phaseOf(inner, layout.starCenter, before.center),
          phaseOf(inner, layout.starCenter, quarter.center),
        ),
        closeTo(math.pi / 2, 1e-6),
        reason: 'T/4 ⇒ 参数角 +π/2',
      );
      expect(
        quarter.phase,
        before.phase,
        reason: '`phase` 是静态参数角，时间不进这一格 —— 否则同一份布局自相矛盾',
      );

      final StarPlanet full = layout.advanced(t1).planetOf(before.id)!;
      expect(
        (full.center - before.center).distance,
        lessThan(1e-6),
        reason: '走满一个周期回到同一点',
      );
    });

    test('两层各按自己的周期走：外轨走 1/4 圈时内轨已走大半圈（C-56）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      expect(layout.orbits.length, 2, reason: '前置条件：这个包正好两层');

      final StarOrbit outer = layout.orbits[1];
      final StarPlanet d0 = layout.planetOf('d')!;
      final double t2 = starOrbitPeriodSeconds(2, layout.orbits.length);
      final StarPlanet d1 = layout.advanced(t2 / 4).planetOf('d')!;

      expect(
        turnedBy(
          phaseOf(outer, layout.starCenter, d0.center),
          phaseOf(outer, layout.starCenter, d1.center),
        ),
        closeTo(math.pi / 2, 1e-6),
      );
      // 同一段时间里内层走了 `t2 / t1` 个周期 —— 比 1/4 圈多。
      expect(
        t2 / starOrbitPeriodSeconds(1, 2),
        greaterThan(1),
        reason: '外轨一个周期比内轨长，所以同一段时间内轨走得更远',
      );
    });

    test('时钟为 0 时原样返回；筛选不影响相位（C-56）', () {
      final StarSystemLayout layout = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
      );
      expect(identical(layout.advanced(0), layout), isTrue);
      expect(identical(layout.advanced(double.nan), layout), isTrue);

      // 筛掉一颗行星，其余几颗的位置不能动（`layoutStarSystem` 的口径：
      // 轨道数与相位按全量算）。
      final StarSystemLayout screened = layoutStarSystem(
        pack: _forkPack(),
        rootId: 'a',
        viewport: _viewport,
        visibleIds: <String>{'a', 'b'},
      );
      expect(
        screened.planetOf('b')!.center,
        layout.planetOf('b')!.center,
        reason: '筛掉一颗不该让另一颗换个位置',
      );
    });
  });
}
