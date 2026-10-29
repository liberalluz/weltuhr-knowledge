/// 树面板的行集合（`SPEC-TREE-002` / `003` / `004` / `005` / `008` / `012`）。
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

import '../../support/pack_fixture.dart';
import '../../support/tree_fixture.dart';

/// 同级兄弟很多的树：一条学科轴 + [count] 个二级兄弟。截断判据（`SPEC-TREE-012`）
/// 要的是「超过 50 行」，小夹具造不出这个量，另建一棵而不是把公共夹具撑大。
TreeIndex wideTree(int count, {bool withGrandchild = false}) {
  final List<FixtureNode> nodes = <FixtureNode>[
    FixtureNode(
      'wide:d',
      '学科',
      slot: LevelSlot.supercluster,
      axis: Axis.discipline,
    ),
  ];
  for (int i = 1; i <= count; i++) {
    final String code = i.toString().padLeft(2, '0');
    nodes.add(
      FixtureNode(
        'wide:d-$code',
        '子 $i',
        slot: LevelSlot.group,
        axis: Axis.discipline,
        parentId: 'wide:d',
        officialCode: code,
      ),
    );
  }
  if (withGrandchild) {
    final String code = count.toString().padLeft(2, '0');
    nodes.add(
      FixtureNode(
        'wide:d-$code-1',
        '孙 $count',
        slot: LevelSlot.star,
        axis: Axis.discipline,
        parentId: 'wide:d-$code',
        officialCode: '${code}01',
      ),
    );
  }
  return TreeIndex.build(
    contents: <PackContent>[
      fixturePack(
        nodes,
        pluginId: 'wide',
        packName: '宽夹具',
        kinds: const <String>[],
      ),
    ],
  );
}

void main() {
  late TreeIndex tree;

  setUpAll(() {
    tree = treeFixture();
  });

  List<String> idsOf(List<OutlineRow> rows) =>
      rows.map((OutlineRow row) => row.nodeId).toList(growable: false);

  OutlineRow rowOf(List<OutlineRow> rows, String nodeId) =>
      rows.firstWhere((OutlineRow row) => row.nodeId == nodeId);

  test('TC-TREE-019 单轴态只出当前根那一条轴根，且带当前标记（SPEC-TREE-003）', () {
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
      <String>['skeleton:d'],
      reason: '单轴态只出当前根所在那一条轴 —— 另两条要进全树态才看得见',
    );
    expect(
      axisRows.single.indent,
      1,
      reason: '缩进基准上移到 `知识` 之后，轴根退到第 1 级（`SPEC-TREE-008`）',
    );
    expect(
      rows.where((OutlineRow row) => row.isCurrentRoot).length,
      1,
      reason: '当前轴根只有一个',
    );
    expect(axisRows.single.isCurrentRoot, isTrue);
  });

  test('TC-TREE-020 首行是虚拟根 `知识`，两态都画且不可点（SPEC-TREE-002）', () {
    for (final TreeMode mode in TreeMode.values) {
      final List<OutlineRow> rows = treeOutline(
        tree: tree,
        rootId: 'skeleton:d',
        selectedId: 'skeleton:d-0101',
        mode: mode,
      );

      expect(rows.first.label, '知识', reason: '${mode.name}：首行恒为虚拟根');
      expect(rows.first.isVirtualRoot, isTrue);
      expect(rows.first.indent, 0, reason: '缩进的零点就是这一行');
      expect(rows.first.path, isEmpty, reason: '它不在地址里');
      expect(rows.first.isClickable, isFalse, reason: '点了不产生任何地址变化 —— 它不是节点');
      expect(
        rows.where((OutlineRow row) => row.label == '知识').length,
        1,
        reason: '只有一行，不是每条轴各挂一份',
      );
    }
  });

  test('TC-TREE-021 未选中深层时只展开轴根的一层（SPEC-TREE-004 前提）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
    );

    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
      'skeleton:d-01',
      'skeleton:d-02',
    ]);
    expect(
      rowOf(rows, 'skeleton:d').hasChildren,
      isTrue,
      reason: '有子节点 —— 点它之后下一层才会出现',
    );
    expect(rowOf(rows, 'skeleton:d').indent, 1);
    expect(rowOf(rows, 'skeleton:d-01').indent, 2);
  });

  test('TC-TREE-022 选中深层 ⇒ 路径逐级展开、链上兄弟全列（SPEC-TREE-004）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
    );

    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
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
      2,
      reason: '`知识` 0 · 轴根 1 · 它的子 2',
    );
    expect(rowOf(rows, 'python:p1').isSelected, isTrue);
    expect(
      rows.where((OutlineRow row) => row.isSelected).length,
      1,
      reason: '地址只有一处',
    );
  });

  test('TC-TREE-023 缩进以 `知识` 为 0 起算（SPEC-TREE-008）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
    );

    expect(rowOf(rows, '').indent, 0);
    expect(rowOf(rows, 'skeleton:d').indent, 1);
    expect(rowOf(rows, 'skeleton:d-01').indent, 2);
    expect(rowOf(rows, 'skeleton:d-0101').indent, 3);
    expect(rowOf(rows, 'python:sys').indent, 4);
    expect(rowOf(rows, 'python:p1').indent, 5);
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
    expect(disciplineStar.indent, 3);
    expect(rowOf(majorRows, 'skeleton:m-010101').indent, 4);
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

  test('TC-TREE-025 根是中间节点时，当前轴仍按它所在的轴算（SPEC-TREE-005）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d-01',
      selectedId: 'skeleton:d-01',
    );

    expect(
      rowOf(rows, 'skeleton:d').isCurrentRoot,
      isTrue,
      reason: '当前标记挂在轴根行，不在中间节点上 —— 标记的语义是「哪条轴」',
    );
    expect(rowOf(rows, 'skeleton:d').indent, 1);
    expect(rowOf(rows, 'skeleton:d-01').indent, 2);
    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
      'skeleton:d-01',
      'skeleton:d-0101',
      'skeleton:d-x',
      'skeleton:d-02',
    ], reason: '行集合由地址定、不由根定；`d-02` 是 `d-01` 的兄弟，照样在屏上');
  });

  test('TC-TREE-026 选中项不在当前根下 ⇒ 只到轴根一层，不抛错（SPEC-TREE-005）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:m',
      selectedId: 'skeleton:d-0101',
    );

    expect(idsOf(rows), <String>['', 'skeleton:m']);
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

  test('TC-TREE-029 未知根 ⇒ 单轴态只剩 `知识` 一行，不替调用方猜一根轴（SPEC-TREE-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'nope:missing',
      selectedId: null,
    );

    expect(rows.length, 1);
    expect(rows.single.isVirtualRoot, isTrue);
    expect(rows.any((OutlineRow row) => row.isCurrentRoot), isFalse);
  });

  test('TC-TREE-043 选中中间层 ⇒ 它自己的下一层就出现，逐级可点才走得动（SPEC-TREE-004）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d-01',
    );

    // 判据是「点子节点 ⇒ 地址变长，视觉焦点下移一层」。只展开**严格**祖先的话，
    // 选中 `d-01` 之后它自己的子节点不会出现（选中项是它、不是它的后代），第二
    // 层就再也下不去了 —— 而这一层是界面里唯一能点出更深地址的地方。
    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
      'skeleton:d-01',
      'skeleton:d-0101',
      'skeleton:d-x',
      'skeleton:d-02',
    ], reason: '`d-01` 的两个子节点在它被选中后出现，`d-02` 仍是它的兄弟');
    expect(rowOf(rows, 'skeleton:d-0101').indent, 3);
    expect(rowOf(rows, 'skeleton:d-0101').isSelected, isFalse);
    expect(rowOf(rows, 'skeleton:d-01').isSelected, isTrue);
  });

  test('TC-TREE-058 全树态三条轴根连续列出，只有当前轴往下展（SPEC-TREE-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
      mode: TreeMode.fullTree,
    );

    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
      'skeleton:d-01',
      'skeleton:d-02',
    ], reason: '三条轴根连着排，当前轴的子行接在三条之后 —— 子行插在中间会把另一支推远');
    expect(rows.where((OutlineRow row) => row.isAxisRoot).length, 3);
    expect(
      rowOf(rows, 'skeleton:m').hasChildren,
      isFalse,
      reason: '另两条轴只出轴根一行，这一层没有子行可点',
    );
    expect(rowOf(rows, 'skeleton:o').indent, 1);
    expect(
      rows.where((OutlineRow row) => row.isCurrentRoot).single.nodeId,
      'skeleton:d',
    );
  });

  test('TC-TREE-059 全树态也只展开当前轴一条链（SPEC-TREE-003）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
      mode: TreeMode.fullTree,
    );

    expect(idsOf(rows), <String>[
      '',
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
      'skeleton:d-01',
      'skeleton:d-0101',
      'python:sys',
      'python:p1',
      'skeleton:d-x',
      'skeleton:d-02',
    ], reason: '`m` / `o` 后面没有任何子行；链只在学科轴上展开');
  });

  test('TC-TREE-060 同级超 50 行截断，末行「还有 M 项」（SPEC-TREE-012）', () {
    final TreeIndex wide = wideTree(60);
    final List<OutlineRow> rows = treeOutline(
      tree: wide,
      rootId: 'wide:d',
      selectedId: 'wide:d',
    );

    final List<OutlineRow> siblingRows = rows
        .where((OutlineRow row) => row.nodeId.startsWith('wide:d-'))
        .toList(growable: false);
    expect(siblingRows.length, 50, reason: '同级最多出 50 行');
    final OutlineRow overflow = rows.last;
    expect(overflow.isOverflow, isTrue);
    expect(overflow.label, '还有 10 项', reason: '60 − 50');
    expect(overflow.indent, siblingRows.first.indent, reason: '与兄弟同级');
    expect(overflow.isClickable, isFalse, reason: '它是截断提示，不是节点 —— 点了不能改地址');
  });

  test('TC-TREE-061 同级不超 50 行时不出计数行（SPEC-TREE-012）', () {
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
    );

    expect(rows.any((OutlineRow row) => row.isOverflow), isFalse);
  });

  test('TC-TREE-062 地址落在截断范围外时仍补进屏内（SPEC-TREE-012）', () {
    final TreeIndex wide = wideTree(60);
    final List<OutlineRow> rows = treeOutline(
      tree: wide,
      rootId: 'wide:d',
      selectedId: 'wide:d-58',
    );

    expect(
      rows.any((OutlineRow row) => row.nodeId == 'wide:d-58'),
      isTrue,
      reason: '否则下钻到第 58 个兄弟后，行集合里找不到「我在哪」',
    );
    expect(rowOf(rows, 'wide:d-58').isSelected, isTrue);
    expect(rows.last.label, '还有 10 项', reason: '`M` 仍按「总数 − 50」算，不因补回这一行而变');
  });

  test('TC-TREE-063 地址更深时它的父行也必显，链不在那一级断（SPEC-TREE-012）', () {
    final TreeIndex wide = wideTree(60, withGrandchild: true);
    final List<OutlineRow> rows = treeOutline(
      tree: wide,
      rootId: 'wide:d',
      selectedId: 'wide:d-60-1',
    );

    expect(
      rows.any((OutlineRow row) => row.nodeId == 'wide:d-60'),
      isTrue,
      reason: '父行不在屏上，子行就成了没有父级的孤儿，逐级可点在那一级断掉',
    );
    expect(rowOf(rows, 'wide:d-60-1').isSelected, isTrue);
    expect(
      rowOf(rows, 'wide:d-60-1').indent,
      rowOf(rows, 'wide:d-01').indent + 1,
      reason: '补回来的父行仍占它该占的缩进，链上段数不含糊',
    );
  });
}
