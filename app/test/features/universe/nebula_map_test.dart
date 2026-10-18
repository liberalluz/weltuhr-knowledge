import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/universe/nebula_map.dart';

import '../../support/pack_fixture.dart';

/// 视口固定成 `Z2` 在 800×600 下的那一块 —— 位置由几何唯一决定，
/// 断言里的距离 / 半径都按它算。
const Size _viewport = Size(800, 600);

/// 一个域一条链：`a → b → c`（`⪯` 单链 ⇒ 一棵子树）。
LoadedPack _chainPack() => fixturePack(
  const <FixtureItem>[
    FixtureItem('a', '甲', domainId: 'python/lexical'),
    FixtureItem('b', '乙', domainId: 'python/lexical'),
    FixtureItem('c', '丙', domainId: 'python/lexical'),
    FixtureItem('x', '习', domainId: 'python/vocab'),
  ],
  edges: const <List<String>>[
    <String>['a', 'b'],
    <String>['b', 'c'],
  ],
);

/// 两个域：`lexical` 一条三项链、`vocab` 两项各自成根 + 一条跨域边。
LoadedPack _twoDomainPack() => fixturePack(
  const <FixtureItem>[
    FixtureItem('a', '甲', domainId: 'python/lexical'),
    FixtureItem('b', '乙', domainId: 'python/lexical'),
    FixtureItem('c', '丙', domainId: 'python/lexical'),
    FixtureItem('x', '习', domainId: 'python/vocab'),
    FixtureItem('y', '记', domainId: 'python/vocab'),
  ],
  edges: const <List<String>>[
    <String>['a', 'b'],
    <String>['b', 'c'],
    <String>['c', 'x'],
  ],
);

void main() {
  group('Z2 分子云的几何（SPEC-VIEW-038 · V-1d）', () {
    test('一朵云 = 一个域的项，别域的项不进来（SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );

      expect(layout.domainItemCount, 3, reason: 'lexical 有三项');
      expect(
        layout.items.map((NebulaItem each) => each.id),
        <String>['a', 'b', 'c'],
        reason: '顺序按包内出现顺序 —— 两处排序不同会让「第 i 项」指到别的项',
      );
      expect(
        layout.items.where((NebulaItem each) => each.id == 'x'),
        isEmpty,
        reason: 'x 在 vocab 域，属于另一朵云',
      );
    });

    test('云粒子数固定：不跟项数走（SPEC-VIEW-038 / C-62）', () {
      final LoadedPack pack = _twoDomainPack();
      final NebulaLayout small = layoutNebula(
        pack: pack,
        domainId: 'python/lexical',
        viewport: _viewport,
      );
      final NebulaLayout other = layoutNebula(
        // `vocab` 只有两项 —— 与三项的域比，粒子数必须**一模一样**。
        pack: pack,
        domainId: 'python/vocab',
        viewport: _viewport,
      );

      expect(small.wisps, hasLength(nebulaParticleCount));
      expect(other.wisps, hasLength(nebulaParticleCount));
      expect(
        other.domainItemCount,
        2,
        reason: '前提：两个域的项数确实不同，否则这条断言什么也没验',
      );
      expect(
        small.wisps.length,
        other.wisps.length,
        reason: '粒子数跟项数走就成了第三条「项数」通道（X-02）',
      );
    });

    test('亮结 = ⪯ 子树数：单链一个（SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );

      expect(layout.knots, hasLength(1), reason: 'a→b→c 是一条链 ⇒ 一棵子树');
      expect(
        layout.knots.single.rootId,
        'a',
        reason: '根是唯一没有同域前置的那一项',
      );
      expect(layout.knots.single.itemCount, 3);
      expect(
        layout.knots.single.isSingle,
        isFalse,
        reason: '三项子树 ⇒ 进 Z3，不是直接 Z4',
      );
    });

    test('单项子树：亮结 isSingle（VIEW-038：点它跳过 Z3）（SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/vocab',
        viewport: _viewport,
      );

      expect(layout.knots, hasLength(1));
      expect(
        layout.knots.single.isSingle,
        isTrue,
        reason: 'vocab 只有一项 ⇒ 单项子树 ⇒ 界面直接落 Z4',
      );
      expect(layout.knots.single.rootId, 'x');
    });

    test('无支路时每域一个亮结，与 Z1 暗斑同源（SPEC-VIEW-037 / 038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/vocab',
        viewport: _viewport,
      );

      expect(
        layout.knots,
        hasLength(2),
        reason: 'vocab 的 x 有前置（跨域，不算同域）、y 无前置 ⇒ 两个根两棵树',
      );
      expect(
        <String>[for (final NebulaKnot knot in layout.knots) knot.rootId],
        <String>['x', 'y'],
        reason: '根按包内出现顺序',
      );
    });

    test('域内边画线、跨域边攒成出口标记（SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );

      expect(layout.threads, hasLength(2), reason: 'a→b、b→c 在域内');
      expect(layout.exits, hasLength(1), reason: 'c→x 跨到 vocab');
      final NebulaExit exit = layout.exits.single;
      expect(exit.targetDomainId, 'python/vocab');
      expect(
        exit.label,
        '→ 进入 vocab',
        reason: '规格写〈动词形态〉，但包里没有域的动词形态 ⇒ 退成末段域名（PACK 缺口）',
      );
      expect(exit.edgeCount, 1);
      expect(
        (exit.center - layout.center).distance,
        closeTo(layout.cloudRadius * 0.92, 0.001),
        reason: '出口落在云缘，不伸到云外 —— 伸出去就是断线',
      );
    });

    test('跨域边不再算「域内边」：出口两侧都只认一次（SPEC-VIEW-038）', () {
      final NebulaLayout vocal = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/vocab',
        viewport: _viewport,
      );

      expect(vocal.threads, isEmpty, reason: 'vocab 内部没有边');
      expect(
        vocal.exits,
        hasLength(1),
        reason: '同一条跨域边在两端各算一次出口 —— 两边都要能「出去」',
      );
      expect(vocal.exits.single.targetDomainId, 'python/lexical');
    });

    test('筛选只减项与域内边，粒子与亮结不跟着消失（SPEC-VIEW-038 / C-62）', () {
      final LoadedPack pack = _twoDomainPack();
      final NebulaLayout all = layoutNebula(
        pack: pack,
        domainId: 'python/lexical',
        viewport: _viewport,
      );
      final NebulaLayout filtered = layoutNebula(
        pack: pack,
        domainId: 'python/lexical',
        viewport: _viewport,
        visibleIds: const <String>{'a'},
      );

      expect(filtered.items, hasLength(1));
      expect(filtered.items.single.id, 'a');
      expect(
        filtered.threads,
        isEmpty,
        reason: 'a→b 的另一端被筛掉 ⇒ 这条边画不出来',
      );
      expect(
        filtered.wisps.length,
        all.wisps.length,
        reason: '云没变 —— 筛的是项，不是把结构抹掉',
      );
      expect(
        filtered.knots,
        hasLength(all.knots.length),
        reason: '亮结仍在：否则用户会以为这个域没有恒星系了',
      );
      expect(
        filtered.domainItemCount,
        all.domainItemCount,
        reason: '全量项数不受筛选影响',
      );
    });

    test('确定性：同一输入两次布局逐点相同（SPEC-VIEW-038）', () {
      final NebulaLayout first = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );
      final NebulaLayout second = layoutNebula(
        pack: _twoDomainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );

      expect(first.wisps.length, second.wisps.length);
      for (int i = 0; i < first.wisps.length; i++) {
        expect(first.wisps[i].center, second.wisps[i].center);
        expect(first.wisps[i].argb, second.wisps[i].argb);
      }
      expect(first.knots.single.center, second.knots.single.center);
    });

    test('云粒子落在云内，颜色内红外蓝（SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );

      for (final NebulaWisp wisp in layout.wisps) {
        expect(
          (wisp.center - layout.center).distance,
          lessThanOrEqualTo(layout.cloudRadius),
        );
      }
      // 内圈偏红（红分量 > 蓝分量），外圈偏蓝（反过来）。只验两极，
      // 中间过渡不写成断言 —— 那是插值实现细节。
      final NebulaWisp? inner = _nearest(layout);
      final NebulaWisp? outer = _farthest(layout);
      expect(inner, isNotNull);
      expect(outer, isNotNull);
      expect(
        (inner!.argb >> 16) & 0xFF,
        greaterThan((inner.argb) & 0xFF),
        reason: '近云心偏红（氢 α）',
      );
      expect(
        (outer!.argb >> 16) & 0xFF,
        lessThan(outer.argb & 0xFF),
        reason: '远云心偏蓝（尘埃反射）',
      );
    });

    test('空域不画云（SPEC-FND-014 未声明即不渲染）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/not-there',
        viewport: _viewport,
      );

      expect(layout.isEmpty, isTrue);
      expect(layout.wisps, isEmpty);
      expect(layout.knots, isEmpty);
    });

    test('点项命中 8 px 圈内，圈外不命中（C-44 / SPEC-VIEW-014）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );
      final NebulaItem item = layout.items.first;

      expect(
        pickNebulaItemAt(layout: layout, point: item.center),
        item.id,
        reason: '点在星上就必须点得中',
      );
      expect(
        pickNebulaItemAt(
          layout: layout,
          point: item.center + const Offset(0, pickMinHitRadius + 1),
        ),
        isNull,
        reason: '画得再小也要够得着，但圈外不该抢邻星的点击',
      );
    });

    test('点亮结命中 24 px 圈内（VIEW-018 口径 / SPEC-VIEW-038）', () {
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/lexical',
        viewport: _viewport,
      );
      final NebulaKnot knot = layout.knots.single;

      expect(
        pickNebulaKnotAt(
          layout: layout,
          point: knot.center + const Offset(0, 11),
        )?.rootId,
        knot.rootId,
        reason: '看得见、点不中等于不可点',
      );
      expect(
        pickNebulaKnotAt(
          layout: layout,
          point: knot.center + const Offset(0, 13),
        ),
        isNull,
      );
    });

    test('亮结压住项时算亮结 —— 容器优先（SPEC-VIEW-037 / 038）', () {
      // 单项子树：亮结就落在那一项身上，两个命中圈必然重叠。
      final NebulaLayout layout = layoutNebula(
        pack: _chainPack(),
        domainId: 'python/vocab',
        viewport: _viewport,
      );
      final NebulaKnot knot = layout.knots.single;

      expect(
        pickNebulaKnotAt(layout: layout, point: knot.center),
        isNotNull,
        reason: '重叠处先判容器 —— 与 Z1 同一条口径',
      );
      expect(
        pickNebulaItemAt(layout: layout, point: knot.center),
        isNotNull,
        reason: '项本身也命中；界面按「先亮结」的顺序分派',
      );
    });
  });
}

/// 离云心最近的那颗粒子。
NebulaWisp? _nearest(NebulaLayout layout) {
  NebulaWisp? best;
  double bestDistance = double.infinity;
  for (final NebulaWisp wisp in layout.wisps) {
    final double distance = (wisp.center - layout.center).distance;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = wisp;
    }
  }
  return best;
}

/// 离云心最远的那颗粒子。
NebulaWisp? _farthest(NebulaLayout layout) => layout.wisps.isEmpty
    ? null
    : layout.wisps.reduce(
        (NebulaWisp a, NebulaWisp b) =>
            (a.center - layout.center).distance >=
                (b.center - layout.center).distance
            ? a
            : b,
      );
