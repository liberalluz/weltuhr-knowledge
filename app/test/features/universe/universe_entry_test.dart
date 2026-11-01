/// 宇宙视图的产品入口（`B17b` 笔 2）。
///
/// 守两件事：**树屏标题栏上有这个入口且只有一个**；**采样面板默认关**。
///
/// ## 为什么不断言「点了会进入宇宙屏」
///
/// 宇宙屏一构建就要 `gpuContext()`，widget 测试没有 Impeller 后端，会抛
/// `Flutter GPU requires the Impeller rendering backend`，整棵子树构建失败。
/// 在那里断言「路由里有没有宇宙屏」，测到的只是这个环境限制，不是入口接得对
/// 不对 —— 一条会红、且红了也不说明代码有问题的用例，比没有更糟。
///
/// 「点进去能出、退出再进不崩」登记在 `ADR-0006` 修订十三的**未验**项里，由
/// 终端跑 `flutter run` 与真机各看一次。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';
import 'package:project_knowledge/features/universe/presentation/spike_scene.dart';

import '../../support/tree_fixture.dart';

void main() {
  testWidgets('TC-UNIVERSE-001 树屏标题栏有「宇宙视图」入口，且只出现一次（ADR-0006 修订十三）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TreeScreen(
          contents: <PackContent>[skeletonFixture(), payloadFixture()],
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(treeUniverseKey),
      findsOneWidget,
      reason: '入口挂在树屏标题栏 —— 从哪一行切过去，宇宙里就该是哪一片天',
    );
    expect(
      find.descendant(
        of: find.byKey(treeUniverseKey),
        matching: find.byIcon(Icons.blur_on),
      ),
      findsOneWidget,
      reason: '图标与按钮要一一对应，不能只有个空 IconButton',
    );
  });

  test('TC-UNIVERSE-002 采样面板默认关：新增调用点忘记传参时不会漏到产品里（ADR-0006 修订十三）', () {
    // 守的是「默认值落在安全的那一边」。不 `pumpWidget` 这个组件 —— 一旦
    // 走到 `build` 就要 `gpuContext()`，测试环境会抛错。这里只要那个 bool。
    expect(
      const SpikeSceneView().showReadout,
      isFalse,
      reason: '默认必须是关：产品入口 `UniverseScreen` 不传这个参数',
    );
  });

  test('TC-UNIVERSE-054 宇宙带回来的地址：没带 / 没变 / 变了三种处置（ADR-0006 修订十八）', () {
    // 真正走一遍「进宇宙 → 下钻 → 返回」要构建 `UniverseScreen`，而它一构建
    // 就要 `gpuContext()`。所以把回写判据抽成纯函数，在这里验三段分支；
    // 「pop 真的带回了值」只能真机看，已登记在 ADR 修订十八的未验项里。
    expect(
      adoptReturnedAddress(picked: null, current: 'a'),
      isNull,
      reason: '没带回来就什么都不做 —— 用户可能只是进去看了看',
    );
    expect(
      adoptReturnedAddress(picked: 'a', current: 'a'),
      isNull,
      reason: '带回来的还是进来那一行 ⇒ 没下钻，不该 setState（会让树滚动位置抖一下）',
    );
    expect(
      adoptReturnedAddress(picked: 'b', current: 'a'),
      'b',
      reason: '在宇宙里下钻过，树里那一行要跟着走（SPEC-TREE-007 同一份地址）',
    );
  });
}
