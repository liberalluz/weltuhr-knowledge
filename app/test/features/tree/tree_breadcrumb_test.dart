/// 面包屑（`SPEC-TREE-002` / `006` / `007`）。
///
/// 这里验三件事，一件一层：**段数与段名**（读的是树的地址，不是自己数的路径）、
/// **三种段的可点性**（虚拟根 / 中间段 / 末段各不相同）、**点完地址真的变了**
/// （面包屑与行集合同源，一处变另一处必须跟着变）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/features/tree/tree_breadcrumb.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';

import '../../support/tree_fixture.dart';

void main() {
  late TreeIndex tree;

  setUpAll(() {
    tree = TreeIndex.build(
      contents: <PackContent>[skeletonFixture(), payloadFixture()],
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required String nodeId,
    ValueChanged<String>? onJump,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: TreeBreadcrumb(
              tree: tree,
              nodeId: nodeId,
              onJump: onJump ?? (String _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('TC-TREE-039 段数 = 层深 + 2，段名取 name 不取 slug（SPEC-TREE-006）', (
    WidgetTester tester,
  ) async {
    // 闭包：学科轴根 0 → 哲学 1 → 马克思主义哲学 2 → 装饰器 3 → 闭包 4。
    expect(tree.depthOf('python:p1'), 4, reason: '夹具前提：载荷行星在第 4 层');

    await pump(tester, nodeId: 'python:p1');

    for (final String id in <String>[
      '',
      'skeleton:d',
      'skeleton:d-01',
      'skeleton:d-0101',
      'python:sys',
      'python:p1',
    ]) {
      expect(find.byKey(breadcrumbSegmentKey(id)), findsOneWidget);
    }
    // 段数 = 段与段之间的分隔符数 + 1 ⇒ 5 个分隔符就是 6 段（含 `知识`）。
    expect(find.text(breadcrumbSeparator), findsNWidgets(5));
    expect(
      find.text('马克思主义哲学'),
      findsOneWidget,
      reason: '段名是 `Node.name`；`slug` 是地址段，拿来显示会把 `d-0101` 摆在人眼前',
    );
    expect(find.text('d-0101'), findsNothing);
  });

  testWidgets('TC-TREE-040 点中间段交出去的是那一级的节点 id（SPEC-TREE-004）', (
    WidgetTester tester,
  ) async {
    String? jumped;
    await pump(
      tester,
      nodeId: 'python:p1',
      onJump: (String id) => jumped = id,
    );

    await tester.tap(find.byKey(breadcrumbSegmentKey('skeleton:d-01')));
    await tester.pump();

    expect(
      jumped,
      'skeleton:d-01',
      reason: '交出去的是节点 id —— 让上层按路径字符串再查一遍等于两套地址',
    );
  });

  testWidgets('TC-TREE-041 虚拟根段与末段都点不动（SPEC-TREE-002）', (
    WidgetTester tester,
  ) async {
    int jumps = 0;
    await pump(
      tester,
      nodeId: 'python:p1',
      onJump: (String _) => jumps += 1,
    );

    // `warnIfMissed: false`：不可点的那两段本来就是「点了什么都不发生」，
    // 这里要的是「没有回调」，不是「有东西接住了手势」。
    await tester.tap(
      find.byKey(breadcrumbSegmentKey('')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(jumps, 0, reason: '`知识` 不是节点、没有地址，点它不该改变什么');

    await tester.tap(
      find.byKey(breadcrumbSegmentKey('python:p1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(jumps, 0, reason: '末段就是当前地址，点了地址不变');
  });

  testWidgets('TC-TREE-042 点面包屑上移一层，行集合与段数同步收（SPEC-TREE-007）', (
    WidgetTester tester,
  ) async {
    final List<PackContent> contents = <PackContent>[
      skeletonFixture(),
      payloadFixture(),
    ];
    await tester.pumpWidget(MaterialApp(home: TreeScreen(contents: contents)));
    await tester.pump();

    // 点着往下走四层 —— 顺带证明「逐级可点」不是只有第一层能用。
    for (final String id in <String>[
      'skeleton:d-01',
      'skeleton:d-0101',
      'python:sys',
      'python:p1',
    ]) {
      await tester.tap(find.byKey(treeRowKey(id)));
      await tester.pump();
    }
    expect(
      find.byKey(breadcrumbSegmentKey('python:p1')),
      findsOneWidget,
      reason: '走到第 4 层，面包屑末段就是它',
    );
    expect(find.text(breadcrumbSeparator), findsNWidgets(5));

    // 回到 `哲学`：地址上移，深于它的行全部消失，段数与段名同步收。
    await tester.tap(find.byKey(breadcrumbSegmentKey('skeleton:d-01')));
    await tester.pump();

    // `知识 › 学科 › 哲学` —— 3 段、2 个分隔符；4 段时的 3 个已随地址一起收回。
    expect(find.text(breadcrumbSeparator), findsNWidgets(2));
    expect(find.byKey(breadcrumbSegmentKey('python:p1')), findsNothing);
    expect(
      find.byKey(treeRowKey('python:p1')),
      findsNothing,
      reason: '面包屑改了地址，行集合必须跟着收 —— 两者读同一份来源',
    );
    expect(
      find.byKey(treeRowKey('skeleton:d-0101')),
      findsOneWidget,
      reason: '收到 `哲学` 后，它自己的下一层就是新的最深一层',
    );
  });
}
