/// 作用域的包覆盖（`SPEC-VIEW-031`）。
///
/// 三条判据各验一次，对上本批验收的三句：
/// 1. 选中**骨架星**时覆盖「骨架 + 挂在它下面的载荷」—— 这正是缺陷现场：
///    只取「地址所在的包」会只剩骨架，而骨架里没有可学项。
/// 2. 选中**载荷域**时只覆盖那一个包。
/// 3. 选中**轴根**时覆盖全部包。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/pack_coverage.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import '../../support/tree_fixture.dart';

void main() {
  late List<PackContent> contents;
  late TreeIndex tree;

  setUp(() {
    contents = <PackContent>[skeletonFixture(), payloadFixture()];
    tree = TreeIndex.build(contents: contents);
  });

  List<String> coveredAt(String? addressId) => <String>[
    for (final PackContent content in packsUnderRoot(
      tree: tree,
      contents: contents,
      addressId: addressId,
    ))
      content.pack.pluginId,
  ];

  test('选中骨架星：覆盖骨架与挂在它下面的载荷', () {
    // `skeleton:d-0101` 是骨架星，`python:sys` 的父边指向它。
    expect(coveredAt('skeleton:d-0101'), <String>['skeleton', 'python']);
  });

  test('选中载荷域：只覆盖那一个包', () {
    expect(coveredAt('python:sys'), <String>['python']);
  });

  test('选中轴根：覆盖全部包', () {
    expect(coveredAt('skeleton:d'), <String>['skeleton', 'python']);
  });

  test('同轴的另一支：不牵连别的包', () {
    // `skeleton:d-02`（经济学）下没有载荷，覆盖集应只剩骨架 —— 与「轴根」
    // 那一组读数不同，说明判据是子树而不是「同轴」。
    expect(coveredAt('skeleton:d-02'), <String>['skeleton']);
  });

  test('地址为空或不在树上：空表，不抛错', () {
    expect(coveredAt(null), isEmpty);
    expect(coveredAt(''), isEmpty);
    expect(coveredAt('不存在:的节点'), isEmpty);
  });
}
