import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/bench/bench_address.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/tree/tree_outline.dart';

import '../../support/tree_fixture.dart';

/// 装置该把地址钉在哪一层（`R-22` 的场景选择）。
///
/// 这一组守的是「**量的是不是一屏装不下的那棵树**」，不是「装置会不会算错 fps」
/// （后者在 `frame_stats_test.dart`）。选错地址的错法不报错：装置照样跑满二十秒、
/// 照样出一行读数，只是那行会被判成「可滚动范围是 0」—— 而那时距离「能出读数」
/// 看起来只差一步，人会去怀疑渲染性能，不会怀疑地址。
void main() {
  /// 装置的上限（`benchMaxDrillDepth`）。这里写死而不是引 `tool/` 的常量：
  /// 用例要判的是**选择规则**，不是那个上限值本身；上限改动不该让本组红。
  const int maxDepth = 8;

  List<OutlineRow> rowsAt(TreeIndex tree, String nodeId) => treeOutline(
        tree: tree,
        rootId: 'skeleton:d',
        selectedId: nodeId,
      );

  test('TC-INF-060 地址取行集合最大的那一层，不取第一条子链（无 SPEC：口径 `R-22`）', () {
    final TreeIndex tree =
        TreeIndex.build(contents: <PackContent>[wideBranchFixture()]);

    final String address = heaviestOutlineAddress(
      tree,
      rootId: 'skeleton:d',
      maxDepth: maxDepth,
    );

    // 第一条子链 `01` 只有一个 `star` ⇒ 沿它下钻到底只有 6 行。
    expect(rowsAt(tree, 'skeleton:d-0101').length, 6);

    // `02` 有五个 ⇒ 10 行。取「行集合最大」应当选它。
    expect(address, 'skeleton:d-02');
    expect(rowsAt(tree, address).length, 10);

    // 判据的落点：选出来的比第一条链多。若实现退回「取第一个子节点」，上一行
    // 会变成 `6` 且地址变成 `skeleton:d-0101` —— 两条断言同时红。
    expect(
      rowsAt(tree, address).length,
      greaterThan(rowsAt(tree, 'skeleton:d-0101').length),
    );
  });

  test('TC-INF-061 行数不再增长就停，不为了「更深」硬走一级（无 SPEC：口径 `R-22`）', () {
    final TreeIndex tree =
        TreeIndex.build(contents: <PackContent>[wideBranchFixture()]);

    // `02` 的五个 `star` 都没有子节点 ⇒ 以其中任意一个为地址，行数仍是 10。
    // 贪心在第二步就该停：再往下走只会把地址挪到叶子上，行集合一模一样。
    expect(
      heaviestOutlineAddress(tree, rootId: 'skeleton:d', maxDepth: maxDepth),
      'skeleton:d-02',
    );
    for (final TreeRow star in tree.childrenOf('skeleton:d-02')) {
      expect(rowsAt(tree, star.nodeId).length, 10);
    }
  });

  test('TC-INF-062 根下没有一个子节点能展开更多行时，返回根本身（无 SPEC：口径 `R-22`）', () {
    final TreeIndex tree =
        TreeIndex.build(contents: <PackContent>[wideBranchFixture()]);

    // 拿一个叶子当根：它的子节点集为空 ⇒ 没有候选胜过自己。装置据此报
    // 「可滚动范围是 0」，而不是返回一个不存在的地址让 `treeOutline` 走空表。
    expect(
      heaviestOutlineAddress(tree, rootId: 'skeleton:d-0201', maxDepth: maxDepth),
      'skeleton:d-0201',
    );
  });
}
