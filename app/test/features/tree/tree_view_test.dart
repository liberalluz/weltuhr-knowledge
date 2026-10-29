/// 容器树的界面（`SPEC-TREE-003` / `004` / `005` / `008`）。
///
/// 这里验的是**手势与像素**：点哪一行交出去什么、缩进落在屏幕上是多少。
/// 「哪一行该在表里」由 `core/tree/tree_outline.dart` 保证，另一份用例
/// （`tree_outline_test.dart`）已经在纯函数层验过 —— 同一件事不在两层各写一遍。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/tree/tree_outline.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';

import '../../support/pack_fixture.dart';
import '../../support/tree_fixture.dart';

void main() {
  late TreeIndex tree;
  late List<PackContent> contents;

  setUpAll(() {
    contents = <PackContent>[skeletonFixture(), payloadFixture()];
    tree = TreeIndex.build(contents: contents);
  });

  /// 行首实际留白。
  double leftOf(WidgetTester tester, String nodeId) {
    final Container box = tester.widget<Container>(
      find.descendant(
        of: find.byKey(treeRowKey(nodeId)),
        matching: find.byType(Container),
      ),
    );
    return (box.padding! as EdgeInsets).left;
  }

  Future<void> pump(
    WidgetTester tester, {
    required String rootId,
    String? selectedId,
    ValueChanged<String>? onDrill,
    ValueChanged<String>? onChangeRoot,
    TreeMode mode = TreeMode.singleAxis,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: TreeView(
              tree: tree,
              rootId: rootId,
              selectedId: selectedId,
              mode: mode,
              onDrill: onDrill ?? (String _) {},
              onChangeRoot: onChangeRoot ?? (String _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('TC-TREE-030 单轴态只画当前轴根，另两条不出现（SPEC-TREE-003）', (
    WidgetTester tester,
  ) async {
    await pump(tester, rootId: 'skeleton:d', selectedId: 'skeleton:d');

    expect(find.byKey(treeRowKey('skeleton:d')), findsOneWidget);
    expect(
      find.byKey(treeRowKey('skeleton:m')),
      findsNothing,
      reason: '单轴态画面里没有另两条轴根 —— 要看得先切全树态',
    );
    expect(find.byKey(treeRowKey('skeleton:o')), findsNothing);
    expect(
      find.byKey(treeCurrentRootMarkKey),
      findsOneWidget,
      reason: '当前轴根只有一个',
    );
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TC-TREE-064 全树态三条轴根都画，仍只有一个「当前」（SPEC-TREE-003）', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
      mode: TreeMode.fullTree,
    );

    for (final String id in <String>[
      'skeleton:d',
      'skeleton:m',
      'skeleton:o',
    ]) {
      expect(find.byKey(treeRowKey(id)), findsOneWidget);
    }
    expect(find.byKey(treeCurrentRootMarkKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:m')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsNothing,
      reason: '「当前」只挂在当前轴根上，另两条轴根没有标记',
    );
  });

  testWidgets('TC-TREE-065 虚拟根 `知识` 行画出来但点不动（SPEC-TREE-002）', (
    WidgetTester tester,
  ) async {
    String? drilled;
    int rootChanges = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d-01',
      onDrill: (String id) => drilled = id,
      onChangeRoot: (String _) => rootChanges += 1,
    );

    expect(find.byKey(treeVirtualRootRowKey), findsOneWidget);
    await tester.tap(find.byKey(treeVirtualRootRowKey));
    await tester.pump();

    expect(drilled, isNull, reason: '它不在地址里，点了不产生任何地址变化');
    expect(rootChanges, 0, reason: '它也不是轴根，换不出根');
  });

  testWidgets('TC-TREE-031 点子节点交出去的是改地址，不是换根（SPEC-TREE-004）', (
    WidgetTester tester,
  ) async {
    String? drilled;
    int rootChanges = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
      onDrill: (String id) => drilled = id,
      onChangeRoot: (String _) => rootChanges += 1,
    );

    await tester.tap(find.byKey(treeRowKey('skeleton:d-01')));
    await tester.pump();

    expect(drilled, 'skeleton:d-01');
    expect(rootChanges, 0, reason: '子节点不是根 —— 两个回调不能混');
  });

  testWidgets('TC-TREE-032 全树态点别的轴根交出去的是换根（SPEC-TREE-004 / 005）', (
    WidgetTester tester,
  ) async {
    String? changedTo;
    int drills = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
      mode: TreeMode.fullTree,
      onDrill: (String _) => drills += 1,
      onChangeRoot: (String id) => changedTo = id,
    );

    await tester.tap(find.byKey(treeRowKey('skeleton:o')));
    await tester.pump();

    expect(changedTo, 'skeleton:o');
    expect(drills, 0);
  });

  testWidgets('TC-TREE-033 全树态点当前轴根什么都不交出去（SPEC-TREE-004）', (
    WidgetTester tester,
  ) async {
    String? drilled;
    int rootChanges = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
      mode: TreeMode.fullTree,
      onDrill: (String id) => drilled = id,
      onChangeRoot: (String _) => rootChanges += 1,
    );

    await tester.tap(find.byKey(treeRowKey('skeleton:d')));
    await tester.pump();

    expect(drilled, isNull, reason: '它已经展开了 —— 再点若改成「退回单轴」，地址与画面都不变，等于白点一次');
    expect(rootChanges, 0, reason: '它自己不是「别的轴根」');
  });

  testWidgets('TC-TREE-034 缩进从 `知识` 起每级加 14 px，与行高无关（SPEC-TREE-008）', (
    WidgetTester tester,
  ) async {
    await pump(tester, rootId: 'skeleton:d', selectedId: 'python:p1');

    final double rootGap =
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byKey(treeVirtualRootRowKey),
                        matching: find.byType(Container),
                      ),
                    )
                    .padding!
                as EdgeInsets)
            .left;
    expect(rootGap, treeRowLeadingGap, reason: '`知识` 行不缩进 —— 它是零点');

    expect(leftOf(tester, 'skeleton:d'), treeRowLeadingGap + treeLevelIndent);
    expect(
      leftOf(tester, 'skeleton:d-01'),
      treeRowLeadingGap + treeLevelIndent * 2,
    );
    expect(
      leftOf(tester, 'skeleton:d-0101'),
      treeRowLeadingGap + treeLevelIndent * 3,
    );
    expect(
      leftOf(tester, 'python:p1'),
      treeRowLeadingGap + treeLevelIndent * 5,
      reason: '载荷行星是第 5 段 —— 缩进跟着路径走，不因为它是可学节点就换一档',
    );
  });

  testWidgets('TC-TREE-035 行尾标签是可学节点的 layer，结构节点没有（SPEC-FND-003）', (
    WidgetTester tester,
  ) async {
    await pump(tester, rootId: 'skeleton:d', selectedId: 'python:p1');
    final String persistent = layerLabels[Layer.persistent]!;

    expect(
      find.descendant(
        of: find.byKey(treeRowKey('python:p1')),
        matching: find.text(persistent),
      ),
      findsOneWidget,
      reason: '`layer` 只在可学节点上有，行尾呈现',
    );
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d-0101')),
        matching: find.text(persistent),
      ),
      findsNothing,
    );
  });

  testWidgets('TC-TREE-036 全树态换根后退回单轴，仍在树里不新开页（SPEC-TREE-005）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: TreeScreen(contents: contents)));
    await tester.pump();

    expect(find.byType(TreeView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(treeRowKey('skeleton:m')),
      findsNothing,
      reason: '进来是单轴态，另两条轴根不在画面上',
    );

    await tester.tap(find.byKey(treeModeToggleKey));
    await tester.pump();
    expect(find.byKey(treeRowKey('skeleton:m')), findsOneWidget);

    await tester.tap(find.byKey(treeRowKey('skeleton:m')));
    await tester.pump();

    expect(
      find.byType(TreeView),
      findsOneWidget,
      reason: '换根不切视图 —— 判据是「还在树里」',
    );
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:m')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
      reason: '标记跟着当前根走',
    );
    expect(
      find.byKey(treeRowKey('skeleton:d')),
      findsNothing,
      reason: '换根后退回单轴态：画面里只剩新换的那一条轴',
    );
  });

  testWidgets('TC-TREE-037 没有轴根时给一句说明，不画空列表（SPEC-FND-014）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TreeScreen(contents: <PackContent>[])),
    );
    await tester.pump();

    expect(find.byType(TreeView), findsNothing);
    expect(find.text('树里没有根'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC-TREE-038 树立不起来时说出原因，不塌成「加载失败」（SPEC-FND-014）', (
    WidgetTester tester,
  ) async {
    final PackContent a = fixturePack(const <FixtureNode>[
      FixtureNode('dup/one', '甲'),
    ], pluginId: 'a');
    final PackContent b = fixturePack(const <FixtureNode>[
      FixtureNode('dup/one', '乙'),
    ], pluginId: 'b');

    await tester.pumpWidget(
      MaterialApp(home: TreeScreen(contents: <PackContent>[a, b])),
    );
    await tester.pump();

    expect(find.byType(TreeView), findsNothing);
    expect(find.text('这棵树立不起来'), findsOneWidget);
    expect(
      find.textContaining('dup/one'),
      findsOneWidget,
      reason: '要指名是哪条数据坏了',
    );
    expect(tester.takeException(), isNull);
  });
}
