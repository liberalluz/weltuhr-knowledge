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
              onDrill: onDrill ?? (String _) {},
              onChangeRoot: onChangeRoot ?? (String _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('TC-TREE-030 三条轴根都画出来，只有当前根带「当前」（SPEC-TREE-003）', (
    WidgetTester tester,
  ) async {
    await pump(tester, rootId: 'skeleton:d', selectedId: 'skeleton:d');

    for (final String id in <String>['skeleton:d', 'skeleton:m', 'skeleton:o']) {
      expect(find.byKey(treeRowKey(id)), findsOneWidget);
    }
    expect(
      find.byKey(treeCurrentRootMarkKey),
      findsOneWidget,
      reason: '根只有一个，「当前」标记也就只有一个',
    );
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
    );
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

  testWidgets('TC-TREE-032 点别的轴根交出去的是换根（SPEC-TREE-004 / 005）', (
    WidgetTester tester,
  ) async {
    String? changedTo;
    int drills = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'skeleton:d',
      onDrill: (String _) => drills += 1,
      onChangeRoot: (String id) => changedTo = id,
    );

    await tester.tap(find.byKey(treeRowKey('skeleton:o')));
    await tester.pump();

    expect(changedTo, 'skeleton:o');
    expect(drills, 0);
  });

  testWidgets('TC-TREE-033 点当前根那一行是改地址，不是换根（SPEC-TREE-004）', (
    WidgetTester tester,
  ) async {
    String? drilled;
    int rootChanges = 0;
    await pump(
      tester,
      rootId: 'skeleton:d',
      selectedId: 'python:p1',
      onDrill: (String id) => drilled = id,
      onChangeRoot: (String _) => rootChanges += 1,
    );

    await tester.tap(find.byKey(treeRowKey('skeleton:d')));
    await tester.pump();

    expect(drilled, 'skeleton:d');
    expect(rootChanges, 0);
  });

  testWidgets('TC-TREE-034 缩进逐级加 14 px，与行高无关（SPEC-TREE-008）', (
    WidgetTester tester,
  ) async {
    await pump(tester, rootId: 'skeleton:d', selectedId: 'python:p1');

    expect(leftOf(tester, 'skeleton:d'), treeRowLeadingGap);
    expect(leftOf(tester, 'skeleton:d-01'), treeRowLeadingGap + treeLevelIndent);
    expect(
      leftOf(tester, 'skeleton:d-0101'),
      treeRowLeadingGap + treeLevelIndent * 2,
    );
    expect(
      leftOf(tester, 'python:p1'),
      treeRowLeadingGap + treeLevelIndent * 4,
      reason: '载荷行星是第 4 段 —— 缩进跟着路径走，不因为它是可学节点就换一档',
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

  testWidgets('TC-TREE-036 换根后仍在树里，不新开页（SPEC-TREE-005）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TreeScreen(contents: contents)),
    );
    await tester.pump();

    expect(find.byType(TreeView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
    );

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
      find.descendant(
        of: find.byKey(treeRowKey('skeleton:d')),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsNothing,
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
    final PackContent a = fixturePack(
      const <FixtureNode>[FixtureNode('dup/one', '甲')],
      pluginId: 'a',
    );
    final PackContent b = fixturePack(
      const <FixtureNode>[FixtureNode('dup/one', '乙')],
      pluginId: 'b',
    );

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
