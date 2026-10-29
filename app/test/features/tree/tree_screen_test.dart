/// 四类落点接进树界面（`SPEC-TREE-010` / `013` / `014`）。
///
/// 这一层验的不是「落点解析对不对」（那是 `landing_target_test.dart` 的纯函数
/// 用例），而是**解析结果真的被界面用上了**：根换没换、「当前」标记落在哪一行、
/// 面包屑段数跟不跟、筛选条出不出来。两条链路各写一份的价值就在这里 —— 纯函数
/// 全绿而界面没接线，是完全可能的。
library;

// `Axis` 两边都有（Flutter 的绘制轴 / `core/enums.dart` 的知识轴），这里要后者。
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/landing.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';
import 'package:project_knowledge/features/tree/tree_breadcrumb.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';

import '../../support/tree_fixture.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Landing? landing}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TreeScreen(
          contents: <PackContent>[skeletonFixture(), payloadFixture()],
          initialLanding: landing,
        ),
      ),
    );
    await tester.pump();
  }

  /// 当前根那一行是不是 [nodeId]。
  ///
  /// 「当前」标记全局只有一处（根的个数是 1），所以断言它落在哪一行，等价于
  /// 断言根是谁 —— 而根本身没有别的可观测形态。
  void expectCurrentRoot(String nodeId) {
    expect(
      find.descendant(
        of: find.byKey(treeRowKey(nodeId)),
        matching: find.byKey(treeCurrentRootMarkKey),
      ),
      findsOneWidget,
      reason: '「当前」标记应挂在 $nodeId 那一行',
    );
    expect(find.byKey(treeCurrentRootMarkKey), findsOneWidget);
  }

  testWidgets('TC-TREE-051 落到别的轴 ⇒ 打开时根已换到该轴根（SPEC-TREE-013）', (
    WidgetTester tester,
  ) async {
    await pump(tester, landing: const AxisLanding(Axis.occupation));

    expectCurrentRoot('skeleton:o');
    // `知识 › 职业` —— 2 段、1 个分隔符：地址就是轴根，收起到最浅一级。
    expect(find.text(breadcrumbSeparator), findsNWidgets(1));
  });

  testWidgets('TC-TREE-052 落点在当前根子树内 ⇒ 根不动，地址落到目标（SPEC-TREE-013）', (
    WidgetTester tester,
  ) async {
    await pump(tester, landing: const NodeLanding('python:p1'));

    expectCurrentRoot('skeleton:d');
    // 闭包在学科轴根下第 4 层 ⇒ 含 `知识` 共 6 段、5 个分隔符。
    expect(find.text(breadcrumbSeparator), findsNWidgets(5));
    expect(find.byKey(breadcrumbSegmentKey('python:p1')), findsOneWidget);
  });

  testWidgets('TC-TREE-053 标签值落点 ⇒ 出现筛选条，地址与根都不变（SPEC-TREE-014）', (
    WidgetTester tester,
  ) async {
    await pump(tester, landing: const TagLanding('green'));

    expect(find.byKey(treeFilterBarKey), findsOneWidget);
    expect(find.textContaining('green'), findsOneWidget);
    // 「不改地址」的可观测形态：根还是默认的学科轴根，面包屑仍是 2 段。
    expectCurrentRoot('skeleton:d');
    expect(find.text(breadcrumbSeparator), findsNWidgets(1));
  });

  testWidgets('TC-TREE-054 筛选条能撤掉，撤掉不改变地址（SPEC-TREE-014）', (
    WidgetTester tester,
  ) async {
    await pump(tester, landing: const TagLanding('green'));

    await tester.tap(find.byKey(treeFilterClearKey));
    await tester.pump();

    expect(find.byKey(treeFilterBarKey), findsNothing);
    expectCurrentRoot('skeleton:d');
    expect(find.text(breadcrumbSeparator), findsNWidgets(1));
  });

  testWidgets('TC-TREE-055 落点未命中 ⇒ 退回最外层，不换错误页（SPEC-TREE-010）', (
    WidgetTester tester,
  ) async {
    await pump(tester, landing: const NodeLanding('skeleton:不存在'));

    // 树仍然在（不是空白、也不是错误页），当前根是默认的学科轴根。
    expectCurrentRoot('skeleton:d');
    expect(find.byKey(treeRowKey('skeleton:d-01')), findsOneWidget);
    expect(find.byKey(treeFilterBarKey), findsNothing);
  });

  testWidgets('TC-TREE-056 不给落点时落在轴序第一根，且是单轴态（SPEC-TREE-003）', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expectCurrentRoot('skeleton:d');
    expect(find.text(breadcrumbSeparator), findsNWidgets(1));
    // 单轴态：只出当前那一条轴根，另两条要进全树态才看得见。
    expect(find.byKey(treeRowKey('skeleton:d')), findsOneWidget);
    expect(find.byKey(treeRowKey('skeleton:m')), findsNothing);
    expect(find.byKey(treeRowKey('skeleton:o')), findsNothing);
    // 首行是虚拟根，不是节点行。
    expect(find.byKey(treeVirtualRootRowKey), findsOneWidget);
    expect(find.byKey(treeRowKey('')), findsNothing);
  });

  testWidgets('TC-TREE-067 轴命中行有「按此轴看」，点后换根到该轴且退回单轴态（SPEC-TREE-010）', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    // 先切到全树态：不这么做的话「点完是单轴态」在本来就在单轴态时也成立，
    // 断言就验不出「退回」这个动作 —— 这三行是这一条的前提，不是装饰。
    await tester.tap(find.byKey(treeModeToggleKey));
    await tester.pump();
    expect(find.byKey(treeRowKey('skeleton:m')), findsOneWidget);

    await tester.tap(find.byKey(treeLocateKey));
    await tester.pump();
    // 夹具里 `skeleton:m` 的名字就是「专业」，而 `supercluster` 不是落点档位
    // （`locateKindOf` 只把 group / galaxy / cluster 读成域），所以这一句只会
    // 命中一条**轴**命中，不会顺带出一条同名项。
    await tester.enterText(find.byKey(locateFieldKey), '专业');
    await tester.pump();

    final Finder here = find.byKey(locateAxisHereKey(Axis.major.name));
    expect(here, findsOneWidget, reason: '轴落点没有界面入口，就等于这条落点不存在');
    await tester.tap(here);
    await tester.pump();

    expectCurrentRoot('skeleton:m');
    expect(find.byKey(locateOverlayKey), findsNothing, reason: '选完落点要收起浮层');
    expect(
      find.byKey(treeRowKey('skeleton:o')),
      findsNothing,
      reason: '换完根退回单轴态 —— 另两条轴根不该还各占一行',
    );
  });
}
