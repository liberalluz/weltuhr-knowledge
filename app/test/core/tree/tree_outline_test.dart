/// 树面板的行集合（`SPEC-TREE-002` / `003` / `004` / `005` / `008`）。
///
/// 这一层不建渲染树：行序、展开范围、缩进级数全在 [treeOutline] 的结果上断言。
/// 缩进**像素**由 `features/tree/tree_view.dart` 乘单级量得到，那一层另有用例
/// （`tree_view_test.dart`）—— 分成两处，是因为失败时的含义不同：这里是「树
/// 长得不对」，那里是「缩进没落在屏幕上」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/tree/tree_outline.dart';

import '../../support/tree_fixture.dart';

void main() {
  late TreeIndex tree;

  setUpAll(() {
    tree = treeFixture();
  });

  List<String> idsOf(List<OutlineRow> rows) =>
      rows.map((OutlineRow row) => row.nodeId).toList(growable: false);

  OutlineRow rowOf(List<OutlineRow> rows, String nodeId) =>
      rows.firstWhere((OutlineRow row) => row.nodeId == nodeId);

  test('TC-TREE-019 三条轴根同时在场，只有当前根带标记（SPEC-TREE-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
    );

    final List<OutlineRow> axisRows = rows
        .where((OutlineRow row) => row.isAxisRoot)
        .toList(growable: false);
    expect(
      axisRows.map((OutlineRow row) => row.nodeId).toList(growable: false),
      <String>['skeleton:d', 'skeleton:m', 'skeleton:o'],
      reason: '按 Axis 声明序，不只画当前那一条',
    );
    expect(
      axisRows.every((OutlineRow row) => row.indent == 0),
      isTrue,
      reason: '三条轴根同处第 0 级 —— 另两条不是当前根的后代，段数无从算起',
    );
    expect(
      rows.where((OutlineRow row) => row.isCurrentRoot).length,
      1,
      reason: '根只有一个',
    );
    expect(rowOf(rows, 'skeleton:m').isCurrentRoot, isFalse);
  });

  test('TC-TREE-020 树里没有虚拟根那一行（SPEC-TREE-002）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d-0101',
    );

    expect(
      rows.any((OutlineRow row) => row.label == '知识'),
      isFalse,
      reason: '「知识」只在面包屑第 1 段，树的第一行是三条轴根',
    );
  });

  test('TC-TREE-021 未选中深层时只展开根的一层（SPEC-TREE-004 前提）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
    );

    expect(idsOf(rows), <String>[
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
      'skeleton:d-01',
      'skeleton:d-02',
    ]);
    expect(
      rowOf(rows, 'skeleton:d').hasChildren,
      isTrue,
      reason: '有子节点 —— 点它之后下一层才会出现',
    );
    expect(rowOf(rows, 'skeleton:m').hasChildren, isFalse);
  });

  test('TC-TREE-022 选中深层 ⇒ 路径逐级展开、链上兄弟全列（SPEC-TREE-004）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
    );

    expect(idsOf(rows), <String>[
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
      'skeleton:d-01',
      'skeleton:d-0101',
      'python:sys',
      'python:p1',
      // `d-x` 排在 `python:p1` 之后：它是 `d-01` 的兄弟子节点，前序展开到
      // 链末才轮到它 —— 顺序本身就是「缩进由段数定」的旁证，不是另一个判据。
      'skeleton:d-x',
      'skeleton:d-02',
    ]);
    expect(
      rowOf(rows, 'skeleton:d-01').indent,
      1,
      reason: '路径 1 段',
    );
    expect(rowOf(rows, 'python:p1').isSelected, isTrue);
    expect(
      rows.where((OutlineRow row) => row.isSelected).length,
      1,
      reason: '地址只有一处',
    );
  });

  test('TC-TREE-023 缩进 = 相对当前根的路径段数（SPEC-TREE-008）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
    );

    expect(rowOf(rows, 'skeleton:d').indent, 0);
    expect(rowOf(rows, 'skeleton:d-01').indent, 1);
    expect(rowOf(rows, 'skeleton:d-0101').indent, 2);
    expect(rowOf(rows, 'python:sys').indent, 3);
    expect(rowOf(rows, 'python:p1').indent, 4);
  });

  test('TC-TREE-024 同段数同缩进、同槽位不同段数不同缩进（SPEC-TREE-008）', () {
    final TreeIndex twoAxis = TreeIndex.build(
      contents: <PackContent>[twoAxisSkeletonFixture()],
    );
    // 一次只有一条链展开（树只展开当前根），所以两条轴各取一次。
    final OutlineRow disciplineStar = rowOf(
      treeOutline(
        tree: twoAxis,
        rootId: 'skeleton:d',
        selectedId: 'skeleton:d-0101',
      ),
      'skeleton:d-0101',
    );
    final List<OutlineRow> majorRows = treeOutline(
      tree: twoAxis,
      rootId: 'skeleton:m',
      selectedId: 'skeleton:m-010101',
    );

    // 学科轴与专业轴各自的 `star`：段数 2 与 3 ⇒ 缩进不同。按槽位缩进会让
    // 两者相同（都是 `star`），于是这条断言就失去意义。
    expect(disciplineStar.indent, 2);
    expect(rowOf(majorRows, 'skeleton:m-010101').indent, 3);
    expect(
      disciplineStar.indent,
      isNot(rowOf(majorRows, 'skeleton:m-010101').indent),
      reason: '同槽位不保证同缩进 —— 缩进看段数',
    );
    // 相反的一面：学科轴的 `d-0101`（`star`，2 段）与专业轴的 `m-0101`
    // （`galaxy`，2 段）段数相同 ⇒ 缩进相同，尽管槽位不同。
    expect(
      rowOf(majorRows, 'skeleton:m-0101').indent,
      disciplineStar.indent,
      reason: '段数相同就是同一级，槽位叫什么不影响缩进',
    );
  });

  test('TC-TREE-025 换根后缩进从 0 起，行集合跟着换（SPEC-TREE-005）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d-01',
      selectedId: 'skeleton:d-01',
    );

    expect(
      rowOf(rows, 'skeleton:d-01').isCurrentRoot,
      isTrue,
      reason: '换到中间节点也成立 —— 判据只要求「留在树」，没要求新根必须是轴根',
    );
    expect(rowOf(rows, 'skeleton:d-01').indent, 0);
    expect(rowOf(rows, 'skeleton:d-0101').indent, 1);
    expect(
      idsOf(rows),
      <String>[
        'skeleton:d',
        'skeleton:m',
        'skeleton:o',
        'skeleton:d-01',
        'skeleton:d-0101',
        'skeleton:d-x',
      ],
      reason: '`skeleton:d` 退成一条轴根行（不再展开），`skeleton:d-02` 则整个消失 '
          '—— 它不在新根之下',
    );
    expect(
      rows.where((OutlineRow row) => row.isAxisRoot).length,
      3,
      reason: '换根不减少轴根 —— 树始终收全部根',
    );
  });

  test('TC-TREE-026 选中项不在当前根下 ⇒ 只到根的一层，不抛错（SPEC-TREE-005）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:m',
      selectedId: 'skeleton:d-0101',
    );

    expect(idsOf(rows), <String>['skeleton:d', 'skeleton:m', 'skeleton:o']);
    expect(
      rows.any((OutlineRow row) => row.isSelected),
      isFalse,
      reason: '不把「地址在别处」改写成「选中根」—— 那等于替点击产生地址',
    );
  });

  test('TC-TREE-027 layer 只挂在可学节点上，用作行尾标签（SPEC-FND-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
    );

    expect(rowOf(rows, 'python:p1').layer, Layer.persistent);
    expect(
      rowOf(rows, 'skeleton:d-0101').layer,
      isNull,
      reason: '结构节点没有 `layer` 字段 —— 补一个默认值会让「层级」与「保鲜期」混成一个',
    );
  });

  test('TC-TREE-028 默认根取轴序第一根，不按 id 字典序（SPEC-TREE-003）', () {
    expect(firstAxisRootId(tree), 'skeleton:d');
    final TreeIndex majorOnly = TreeIndex.build(
      contents: <PackContent>[twoAxisSkeletonFixture()],
    );
    expect(
      firstAxisRootId(majorOnly),
      'skeleton:d',
      reason: '两轴都在时仍取学科（`Axis.values` 的第一项），不是 slug 最小的那个',
    );
  });

  test('TC-TREE-029 未知根 ⇒ 只返回轴根，不返回空表（SPEC-TREE-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'nope:missing',
      selectedId: null,
    );

    expect(rows.length, 3);
    expect(rows.every((OutlineRow row) => row.isAxisRoot), isTrue);
    expect(rows.any((OutlineRow row) => row.isCurrentRoot), isFalse);
  });
}
