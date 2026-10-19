/// `Z1` 盘面几何的单元测试（`SPEC-VIEW-037` · `V-1c`）。
///
/// 这一层的判据全部是**可算的数**：域点落在弧长中点、两条臂对称、旋臂转过多
/// 少度、暗斑几个、点哪儿算命中。所以它不需要 widget 测试也能锁住形态 ——
/// 而形态恰恰是这一笔最容易「看起来差不多」的部分。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/universe/spiral_map.dart';

import '../../support/pack_fixture.dart';

const Size _viewport = Size(800, 600);

/// 三个域、各 4 项：`s/a` 一条 4 项链（1 个根）· `s/b` 一条边 + 两个孤立项
/// （3 个根）· `s/c` 全孤立（4 个根）。
LoadedPack _threeDomains() => fixturePack(
  <FixtureItem>[
    for (final String domain in <String>['s/a', 's/b', 's/c'])
      for (int i = 0; i < 4; i++)
        FixtureItem('$domain-$i', '$domain 第 $i 项', domainId: domain),
  ],
  edges: <List<String>>[
    <String>['s/a-0', 's/a-1'],
    <String>['s/a-1', 's/a-2'],
    <String>['s/a-2', 's/a-3'],
    <String>['s/b-0', 's/b-1'],
  ],
);

void main() {
  final LoadedPack pack = _threeDomains();
  final SpiralLayout layout = layoutSpiral(pack: pack, viewport: _viewport);

  group('Z1 星系盘的形态（SPEC-VIEW-037）', () {
    test('一个域两个域点、两条臂：域数不变、一边一个（SPEC-VIEW-037）', () {
      expect(layout.marks.length, pack.space.domainIds.length);
      for (final DomainMark mark in layout.marks) {
        expect(mark.points.length, 2, reason: '两条臂各一个落点');
      }
      expect(
        layout.arms.length,
        spiralArmCount,
        reason: '核球 + 两条旋臂 —— 不是环，也不是单臂',
      );
    });

    test('域点落在弧段的**中点**：半径 = 核球 + (i+0.5)/n × 跨距（SPEC-VIEW-037）', () {
      final double span = layout.discRadius - layout.bulgeRadius;
      final int n = layout.marks.length;
      for (int i = 0; i < n; i++) {
        final double expected = layout.bulgeRadius + (i + 0.5) / n * span;
        final double actual =
            (layout.marks[i].primary - layout.center).distance;
        // 弧长与半径差成正比（对数螺线的闭式解）⇒ 「弧长中点」就是
        // 「半径中点」，两者不该有差。
        expect(
          actual,
          closeTo(expected, 0.01),
          reason: '域 $i 的落点离核球 $expected px，实际 $actual px',
        );
      }
    });

    test('两条臂的点关于核球中心对称（SPEC-VIEW-037）', () {
      for (final DomainMark mark in layout.marks) {
        final Offset mirrored = mark.points[1] - layout.center;
        final Offset original = mark.points[0] - layout.center;
        expect(mirrored.dx, closeTo(-original.dx, 0.01));
        expect(mirrored.dy, closeTo(-original.dy, 0.01));
      }
    });

    test('域与域在半径上等距 —— 弧长等分而不是面积等分（SPEC-VIEW-037）', () {
      final double span = layout.discRadius - layout.bulgeRadius;
      final double step = span / layout.marks.length;
      final List<double> radii = <double>[
        for (final DomainMark mark in layout.marks)
          (mark.primary - layout.center).distance,
      ];
      for (int i = 1; i < radii.length; i++) {
        expect(radii[i] - radii[i - 1], closeTo(step, 0.01));
      }
    });

    test('旋臂按 C-58 的螺距转足够多圈 —— 盘半径比 10 时约 1.37 圈（C-58）', () {
      // `b = tan(螺距)` ⇒ 转过 `ln(rMax/r₀)/b`。用**逐段累加**而不是首末两点
      // 的夹角差：差角只能得到模 2π 的值，而这里要验的恰恰是「一共转了几圈」。
      final double expected =
          math.log(layout.discRadius / layout.bulgeRadius) /
          math.tan(spiralPitchDeg * math.pi / 180);
      final double swept = _sweptAngle(layout.arms.first, layout.center);
      expect(swept, closeTo(expected, 0.05));
      expect(
        swept,
        greaterThan(math.pi),
        reason:
            '半个圆都转不到的旋臂是「径向短刺」，不是旋涡 —— '
            '`b = 1/tan(15°)` 那个写反的因子会在这里变红（约 0.68 rad）',
      );
    });

    test('同一输入两次布局，坐标逐分量相等 —— 不用随机数（SPEC-VIEW-037）', () {
      final SpiralLayout again = layoutSpiral(pack: pack, viewport: _viewport);
      expect(again.marks.length, layout.marks.length);
      for (int i = 0; i < layout.marks.length; i++) {
        expect(again.marks[i].primary.dx, layout.marks[i].primary.dx);
        expect(again.marks[i].primary.dy, layout.marks[i].primary.dy);
      }
      expect(again.items.length, layout.items.length);
      for (int i = 0; i < layout.items.length; i++) {
        expect(again.items[i], layout.items[i]);
      }
    });

    test('项在盘内作背景：数量 = 包内项数（SPEC-VIEW-037）', () {
      expect(layout.items.length, pack.items.length);
      for (final Offset point in layout.items) {
        expect(
          (point - layout.center).distance,
          lessThanOrEqualTo(layout.discRadius + 1),
          reason: '背景项也得在盘里 —— 甩到盘外会被读成「另一层」',
        );
      }
    });

    test('筛选只减背景项，其余项位置不动（SPEC-VIEW-037）', () {
      final Set<String> keep = <String>{'s/a-0', 's/b-0', 's/c-0'};
      final SpiralLayout filtered = layoutSpiral(
        pack: pack,
        viewport: _viewport,
        visibleIds: keep,
      );
      expect(filtered.items.length, keep.length);
      // 域点与暗斑不受筛选影响：筛的是项，不是把域筛掉。
      expect(filtered.marks.length, layout.marks.length);
      // 保留下来的项位置与全量布局里的**完全一致**（不重新洗牌）。
      for (final Offset point in filtered.items) {
        expect(layout.items.contains(point), isTrue);
      }
    });

    test('暗斑数 = 每域 ⪯ 子树根数，不为好看凑数（SPEC-VIEW-037）', () {
      // `s/a` 4 项一条链（1 个根）· `s/b` 一条边 + 两个孤立（3 个根）·
      // `s/c` 无边 ⇒ 4 项各自成根。
      expect(layout.markOf('s/a')!.systemCount, 1);
      expect(layout.markOf('s/b')!.systemCount, 3);
      expect(layout.markOf('s/c')!.systemCount, 4);
      expect(layout.blobs.length, 1 + 3 + 4);
    });

    test('点项不命中任何域 —— 项是背景（SPEC-VIEW-037）', () {
      for (final Offset point in layout.items) {
        expect(
          pickSpiralDomainAt(layout: layout, point: point),
          isNull,
          reason: '项与最近的域点若挨得太近，这条会红 —— 那是布局问题，不是判据问题',
        );
      }
    });

    test('点域点命中，命中半径 24 px（SPEC-VIEW-037）', () {
      final DomainMark mark = layout.marks[1];
      expect(
        pickSpiralDomainAt(layout: layout, point: mark.primary),
        mark.domainId,
      );
      // 24 px 的一半 = 12 px：11 px 处仍命中，13 px 处不命中。
      expect(
        pickSpiralDomainAt(
          layout: layout,
          point: mark.primary + const Offset(11, 0),
        ),
        mark.domainId,
      );
      expect(
        pickSpiralDomainAt(
          layout: layout,
          point: mark.primary + const Offset(13, 0),
        ),
        isNull,
      );
    });

    test('两条臂上的两个点拾取等价 —— 同一个域（SPEC-VIEW-037）', () {
      for (final DomainMark mark in layout.marks) {
        expect(
          pickSpiralDomainAt(layout: layout, point: mark.points[1]),
          mark.domainId,
        );
      }
    });

    test('域标注取 id 末段：s/a → a（SPEC-VIEW-037）', () {
      expect(layout.markOf('s/a')!.label, 'a');
      expect(domainLabel('python/data-model'), 'data-model');
      expect(domainLabel('nodash'), 'nodash');
    });

    test('没有域或没有视口 ⇒ 空盘，不画一个「有东西」的盘（SPEC-FND-014）', () {
      expect(layoutSpiral(pack: pack, viewport: Size.zero).isEmpty, isTrue);
      final LoadedPack bare = fixturePack(
        const <FixtureItem>[],
        domainIds: const <String>[],
      );
      expect(
        layoutSpiral(pack: bare, viewport: _viewport).isEmpty,
        isTrue,
        reason: '一个域都没有 ⇒ 没有盘面可画（不是画个空核球）',
      );
    });
  });

  group('盘自转（C-54 · V-1i）', () {
    test('相位为 0 时与没转逐值相等 —— 不能靠浮点误差「差不多」（C-54）', () {
      final SpiralLayout zero = layout.spun(0);
      expect(identical(zero, layout), isTrue, reason: '0 相位应原样返回');
      for (int i = 0; i < layout.marks.length; i++) {
        expect(
          zero.marks[i].points.first,
          layout.marks[i].points.first,
          reason: '第 $i 个域的落点',
        );
      }
      expect(zero.items, layout.items);
      expect(zero.blobs, layout.blobs);
      expect(zero.arms.first, layout.arms.first);
    });

    test('转满一圈回到原位（C-54）', () {
      final SpiralLayout full = layout.spun(math.pi * 2);
      for (final DomainMark mark in layout.marks) {
        final Offset before = mark.points.first;
        final Offset after = full.markOf(mark.domainId)!.points.first;
        expect((after - before).distance, lessThan(1e-9));
      }
    });

    test('刚性旋转：每点到盘心的距离一点不变（C-54）', () {
      // 差速会让内圈的项越转越靠近中心 —— 那不是自转，是收缩。
      final SpiralLayout spun = layout.spun(0.7);
      expect(spun.center, layout.center);
      expect(spun.discRadius, layout.discRadius);
      expect(spun.bulgeRadius, layout.bulgeRadius);
      for (int i = 0; i < layout.items.length; i++) {
        expect(
          (spun.items[i] - layout.center).distance,
          closeTo((layout.items[i] - layout.center).distance, 1e-9),
        );
      }
      for (final DomainMark mark in layout.marks) {
        final DomainMark moved = spun.markOf(mark.domainId)!;
        for (int k = 0; k < mark.points.length; k++) {
          expect(
            (moved.points[k] - layout.center).distance,
            closeTo((mark.points[k] - layout.center).distance, 1e-9),
          );
        }
      }
    });

    test('转过 π/2 后，向量正好转 90°（C-54）', () {
      final SpiralLayout spun = layout.spun(math.pi / 2);
      final Offset before = layout.marks.first.points.first - layout.center;
      final Offset after = spun.marks.first.points.first - layout.center;
      // 屏幕坐标里 +π/2 是 (dx, dy) → (-dy, dx)。
      expect(after.dx, closeTo(-before.dy, 1e-9));
      expect(after.dy, closeTo(before.dx, 1e-9));
    });

    test('拾取跟着画面转：点新位置命中，点旧位置不命中（C-54）', () {
      // 这一条是「画在这、点在那」的护栏。旋转之后仍按未旋转的坐标判命中，
      // 表现只是「有时候点不中」，不会有任何东西变红。
      final SpiralLayout spun = layout.spun(math.pi / 2);
      final String domainId = layout.marks.first.domainId;
      final Offset now = spun.markOf(domainId)!.points.first;
      final Offset then = layout.markOf(domainId)!.points.first;
      expect((now - then).distance, greaterThan(24), reason: '两次落点得分开才有判别力');
      expect(pickSpiralDomainAt(layout: spun, point: now), domainId);
      expect(pickSpiralDomainAt(layout: spun, point: then), isNull);
    });

    test('停转判据量的是到域点本身的距离（C-57）', () {
      final Offset now = layout.marks.first.points.first;
      expect(distanceToNearestDomainMark(layout, now), closeTo(0, 1e-9));
      // 盘外 200 px：一定在 `C-57` 的常速区。
      //
      // ⚠️ 不拿「转半圈后的原位置」当探针：每个域在两条臂上各有一个落点，
      // 两者正好关于盘心对称 —— 转 π 之后原位置**又落回**同一个域的另一个
      // 落点。拿它验「距离变大」是错的，而错法看起来很像实现有问题。
      final Offset far = layout.center + Offset(layout.discRadius + 200, 0);
      expect(
        distanceToNearestDomainMark(layout, far),
        greaterThan(governorSlowRadiusPx),
      );
      // 转 π/2 之后，同一个落点确实离开了原位（画面转了，距离读数就得跟着变）。
      expect(
        distanceToNearestDomainMark(layout.spun(math.pi / 2), now),
        greaterThan(0.5),
      );
    });

    test('没有域点时可点距离是无穷 —— 空盘不该「贴着某个不存在的东西」（C-57）', () {
      expect(
        distanceToNearestDomainMark(SpiralLayout.empty, const Offset(10, 10)),
        double.infinity,
      );
    });
  });
}

/// 折线相对 [center] 一共转过多少弧度（逐段累加，不受模 2π 影响）。
double _sweptAngle(List<Offset> arm, Offset center) {
  double total = 0;
  double? previous;
  for (final Offset point in arm) {
    final Offset v = point - center;
    final double angle = math.atan2(v.dy, v.dx);
    if (previous != null) {
      double delta = angle - previous;
      // 归一到 (-π, π]：相邻采样点之间不可能转半圈以上。
      while (delta > math.pi) {
        delta -= math.pi * 2;
      }
      while (delta <= -math.pi) {
        delta += math.pi * 2;
      }
      total += delta;
    }
    previous = angle;
  }
  return total.abs();
}
