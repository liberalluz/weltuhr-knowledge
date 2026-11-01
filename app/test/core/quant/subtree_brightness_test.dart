/// 骨架点亮度（`B17b` 笔 4 · `ADR-0006` 修订十五）。
///
/// 这一笔最容易写成「看起来对」：截图上一个点亮一点暗一点，谁也说不清对不对。
/// 所以断言全落在纯函数与数值上 —— 不比较像素、不比较颜色。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/parent_index.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/quant/subtree_brightness.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import '../../support/pack_fixture.dart';

/// 一个 `star` 下挂两条行星：`p1` 与 `p2`。另有一条**没有载荷**的分支 `other`。
///
/// 「没载荷的分支」是必须有的对照：它测的是「子树里一个可学项都没有」这条
/// 边界，而这条边界在真实骨架里很常见（许多 `star` 下暂时没有包）。
({TreeIndex tree, List<LearnableNode> learnables}) _fixture() {
  final PackContent skeleton = fixturePack(
    <FixtureNode>[
      FixtureNode(
        'sk:d',
        '学科',
        slot: LevelSlot.supercluster,
        axis: Axis.discipline,
      ),
      FixtureNode(
        'sk:g',
        '哲学',
        slot: LevelSlot.group,
        axis: Axis.discipline,
        parentId: 'sk:d',
        officialCode: '01',
      ),
      FixtureNode(
        'sk:s',
        '马克思主义哲学',
        slot: LevelSlot.star,
        axis: Axis.discipline,
        parentId: 'sk:g',
        officialCode: '0101',
      ),
      FixtureNode(
        'sk:g2',
        '经济学',
        slot: LevelSlot.group,
        axis: Axis.discipline,
        parentId: 'sk:d',
        officialCode: '02',
      ),
      FixtureNode(
        'sk:s2',
        '政治经济学',
        slot: LevelSlot.star,
        axis: Axis.discipline,
        parentId: 'sk:g2',
        officialCode: '0201',
      ),
    ],
    pluginId: 'skeleton',
    packName: '亮度夹具骨架',
    kinds: const <String>[],
  );
  final PackContent payload = fixturePack(
    <FixtureNode>[
      FixtureNode(
        'py:sys',
        '装饰器',
        slot: LevelSlot.system,
        axis: Axis.discipline,
        parentId: 'sk:s',
      ),
      FixtureNode('py:p1', '闭包', axis: Axis.discipline, parentId: 'py:sys'),
      FixtureNode('py:p2', '柯里化', axis: Axis.discipline, parentId: 'py:sys'),
    ],
    pluginId: 'python',
    attachTo: 'sk:s',
  );
  final TreeIndex tree = TreeIndex.build(
    contents: <PackContent>[skeleton, payload],
  );
  return (
    tree: tree,
    learnables: <LearnableNode>[...payload.learnableNodes]
        .map((LearnableNode n) => n)
        .toList(),
  );
}

Map<String, double> _brightnessOf(
  TreeIndex tree,
  List<LearnableNode> learnables, {
  Set<String> passed = const <String>{},
  Map<String, double?> stability = const <String, double?>{},
}) {
  final ParentIndex parents = tree.parents;
  return subtreeBrightnessOf(
    skeletonIds: <String>['sk:d', 'sk:g', 'sk:s', 'sk:g2', 'sk:s2'],
    learnables: learnables,
    parents: parents,
    isPassed: passed.contains,
    isCheckin: (String id) => false,
    stabilityOf: (String id) => stability[id],
  );
}

void main() {
  test('TC-UNIVERSE-014 未学恒 0，已学从底光起跳且随掌握度单调（ADR-0006 修订十五）', () {
    // 形状就是这个函数：`0` 与「已学」之间必须断开，因为已学但从未判分的项
    // 掌握度也是 0 —— 不断开的话，「学过」与「没碰过」会一样暗。
    expect(brightnessOfItem(passed: false, mastery: 0), 0);
    expect(brightnessOfItem(passed: false, mastery: 1), 0);
    expect(
      brightnessOfItem(passed: true, mastery: 0),
      closeTo(universeLearnedBaseBrightness, 1e-9),
    );
    expect(brightnessOfItem(passed: true, mastery: 1), closeTo(1, 1e-9));
    double previous = -1;
    for (double m = 0; m <= 1.0001; m += 0.05) {
      final double value = brightnessOfItem(passed: true, mastery: m);
      expect(value, greaterThanOrEqualTo(previous), reason: '掌握度 $m 时反而变暗');
      previous = value;
    }
    // 越界不炸也不越界：`s` 是饱和归一的连续值，浮点累加会出 1.0000000000000002。
    expect(brightnessOfItem(passed: true, mastery: 1.4), lessThanOrEqualTo(1));
  });

  test('TC-UNIVERSE-015 已学但从未判分 = 底光，且比未学亮（ADR-0006 修订十五）', () {
    // 这是整笔的核心判据（`ADR-0006:97`「已学项比未学项亮」）。`stability` 全
    // 空 = 判过分但还没有 `SrsState`，`masteryOf` 对它返回 0。
    final ({TreeIndex tree, List<LearnableNode> learnables}) f = _fixture();
    final Map<String, double> before = _brightnessOf(f.tree, f.learnables);
    expect(before['sk:s'], 0, reason: '没学过应该恒 0');

    final Map<String, double> after = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1'},
    );
    // `sk:s` 子树里两项可学项，只学了一项、掌握度 0 ⇒ 均值 = 底光 / 2。
    expect(after['sk:s'], closeTo(universeLearnedBaseBrightness / 2, 1e-9));
    expect(after['sk:s'], greaterThan(before['sk:s']!));
    // 祖先跟着亮：「这片天」问的是整棵子树，不是单个星。
    expect(after['sk:g'], greaterThan(0));
    expect(after['sk:d'], greaterThan(0));
  });

  test('TC-UNIVERSE-016 子树里没有可学项的点给 0，不是缺席（ADR-0006 修订十五）', () {
    // 缺席会让调用方去猜「是没学还是没算」。空分支（`sk:g2` 下没有载荷）
    // 必须出现在结果里，值为 0。
    final ({TreeIndex tree, List<LearnableNode> learnables}) f = _fixture();
    final Map<String, double> table = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1'},
    );
    expect(
      table.keys,
      containsAll(<String>['sk:d', 'sk:g', 'sk:s', 'sk:g2', 'sk:s2']),
    );
    expect(table['sk:g2'], 0);
    expect(table['sk:s2'], 0);
    // 反向对照：有载荷的那一支不是 0 —— 否则上面的 0 是「全都没算」而不是
    // 「确实没有可学项」。
    expect(table['sk:s'], greaterThan(0));
  });

  test('TC-UNIVERSE-017 亮度是子树内可学项的均值，不是求和（ADR-0006 修订十五）', () {
    // 求和会让「下面有 105 项」的分支永远比「下面有 1 项」的亮，亮度就不再
    // 表示「学会了几成」，而表示「分支有多大」。
    final ({TreeIndex tree, List<LearnableNode> learnables}) f = _fixture();
    final Map<String, double> one = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1'},
    );
    final Map<String, double> two = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1', 'py:p2'},
    );
    expect(one['sk:s'], closeTo(universeLearnedBaseBrightness / 2, 1e-9));
    expect(two['sk:s'], closeTo(universeLearnedBaseBrightness, 1e-9));
    // 学满两项也只到「全部已学、掌握度 0」这一档，不会超过 1。
    expect(two['sk:s'], lessThanOrEqualTo(1));
  });

  test('TC-UNIVERSE-018 掌握度把亮度从底光推到 1（ADR-0006 修订十五）', () {
    final ({TreeIndex tree, List<LearnableNode> learnables}) f = _fixture();
    final Map<String, double> shallow = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1', 'py:p2'},
    );
    final Map<String, double> deep = _brightnessOf(
      f.tree,
      f.learnables,
      passed: <String>{'py:p1', 'py:p2'},
      // `s = S / (S + S₀)` 饱和归一到 1 但不达到 —— 给一个远超 `S₀` 的值
      // 就够了，不必真的算到「永远不达」。
      stability: <String, double?>{'py:p1': 1e6, 'py:p2': 1e6},
    );
    expect(shallow['sk:s'], closeTo(universeLearnedBaseBrightness, 1e-9));
    expect(deep['sk:s'], greaterThan(shallow['sk:s']!));
    expect(deep['sk:s'], closeTo(1, 1e-3));
  });

  test('TC-UNIVERSE-019 骨架 id 不在树里时不抛，也不污染其他点（ADR-0006 修订十五）', () {
    // 调用方传进来的是「当前 + 来路 + 子级」，其中任何一个都可能已被卸载
    // （地址过期）。那一个应当是 0，其余照算。
    final ({TreeIndex tree, List<LearnableNode> learnables}) f = _fixture();
    final Map<String, double> table = subtreeBrightnessOf(
      skeletonIds: <String>['sk:s', 'sk:missing'],
      learnables: f.learnables,
      parents: f.tree.parents,
      isPassed: (String id) => id == 'py:p1',
      isCheckin: (String id) => false,
      stabilityOf: (String id) => null,
    );
    expect(table['sk:missing'], 0);
    expect(table['sk:s'], greaterThan(0));
  });
}
