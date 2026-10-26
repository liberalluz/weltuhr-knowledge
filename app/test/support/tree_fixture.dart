/// 三轴小树夹具：学科三级 + 专业 / 角色各一个轴根，另挂一个载荷包。
///
/// 学科轴刻意让码序与声明序相反（`02` 写在 `01` 前），并给同一父下一个**无码**
/// 兄弟 —— 排序判据（`SPEC-TREE-011`）要能同时覆盖「按码排」与「无码排后」。
///
/// 为什么不用真实骨架包：产物不入库（`SPEC-PACK-005`），CI 里没有它。真实
/// 3,375 节点的读数由装配器自己验，两件事分开。
library;

import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import 'pack_fixture.dart';

/// 三轴骨架。
PackContent skeletonFixture() => fixturePack(
  <FixtureNode>[
    FixtureNode('skeleton:d', '学科', slot: LevelSlot.supercluster, axis: Axis.discipline),
    FixtureNode(
      'skeleton:d-02',
      '经济学',
      slot: LevelSlot.group,
      axis: Axis.discipline,
      parentId: 'skeleton:d',
      officialCode: '02',
    ),
    FixtureNode(
      'skeleton:d-01',
      '哲学',
      slot: LevelSlot.group,
      axis: Axis.discipline,
      parentId: 'skeleton:d',
      officialCode: '01',
    ),
    FixtureNode(
      'skeleton:d-0101',
      '马克思主义哲学',
      slot: LevelSlot.star,
      axis: Axis.discipline,
      parentId: 'skeleton:d-01',
      officialCode: '0101',
    ),
    FixtureNode(
      'skeleton:d-x',
      '编外方向',
      slot: LevelSlot.star,
      axis: Axis.discipline,
      parentId: 'skeleton:d-01',
    ),
    FixtureNode('skeleton:m', '专业', slot: LevelSlot.supercluster, axis: Axis.major),
    FixtureNode('skeleton:o', '职业', slot: LevelSlot.supercluster, axis: Axis.occupation),
  ],
  pluginId: 'skeleton',
  packName: '骨架夹具',
  kinds: const <String>[],
);

/// 挂在 `skeleton:d-0101` 上的最小载荷：一个行星系 + 一个行星。
PackContent payloadFixture() => fixturePack(
  <FixtureNode>[
    FixtureNode(
      'python:sys',
      '装饰器',
      slot: LevelSlot.system,
      axis: Axis.discipline,
      parentId: 'skeleton:d-0101',
    ),
    FixtureNode('python:p1', '闭包', axis: Axis.discipline, parentId: 'python:sys'),
  ],
  pluginId: 'python',
  attachTo: 'skeleton:d-0101',
);

/// 骨架 + 载荷合成一棵树。
TreeIndex treeFixture() =>
    TreeIndex.build(contents: <PackContent>[skeletonFixture(), payloadFixture()]);

/// 两轴不等深：学科三级、专业四级，两条轴各有自己的 `star`。
///
/// 专为 `SPEC-TREE-008` 造的：判据是「缩进按相对当前根的**路径段数**」。学科
/// 的 `star` 是第 2 段、专业的 `star` 是第 3 段 ⇒ 两者缩进**必须不同**；而按
/// 槽位缩进会让它们相同（两个都是 `star`）—— 用例红在这一点上才算验到了。
PackContent twoAxisSkeletonFixture() => fixturePack(
  <FixtureNode>[
    FixtureNode('skeleton:d', '学科', slot: LevelSlot.supercluster, axis: Axis.discipline),
    FixtureNode(
      'skeleton:d-01',
      '哲学',
      slot: LevelSlot.group,
      axis: Axis.discipline,
      parentId: 'skeleton:d',
      officialCode: '01',
    ),
    FixtureNode(
      'skeleton:d-0101',
      '马克思主义哲学',
      slot: LevelSlot.star,
      axis: Axis.discipline,
      parentId: 'skeleton:d-01',
      officialCode: '0101',
    ),
    FixtureNode('skeleton:m', '专业', slot: LevelSlot.supercluster, axis: Axis.major),
    FixtureNode(
      'skeleton:m-01',
      '哲学类',
      slot: LevelSlot.group,
      axis: Axis.major,
      parentId: 'skeleton:m',
      officialCode: '01',
    ),
    FixtureNode(
      'skeleton:m-0101',
      '哲学',
      slot: LevelSlot.galaxy,
      axis: Axis.major,
      parentId: 'skeleton:m-01',
      officialCode: '0101',
    ),
    FixtureNode(
      'skeleton:m-010101',
      '哲学专业',
      slot: LevelSlot.star,
      axis: Axis.major,
      parentId: 'skeleton:m-0101',
      officialCode: '010101',
    ),
  ],
  pluginId: 'skeleton',
  packName: '两轴骨架夹具',
  kinds: const <String>[],
);
