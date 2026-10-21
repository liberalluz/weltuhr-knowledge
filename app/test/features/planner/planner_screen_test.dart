/// Planner 全屏承载的 Widget 回归（`SPEC-PLAN-017` 修订 / `SPEC-PLAN-016`）。
///
/// 夹具只要「三段各够选一次」：源一条、体系覆盖全部项、方法一套内置 ——
/// 这三件事在别处（`planner_panel_test`）已经验透，这里验的是**进出的边界**：
/// 打开之后是不是一整页、建完草稿有没有真的回到调用方、取消有没有变成 `null`。
///
/// ## 笔 5c：范围由子树根表达
///
/// `PlanTarget` 已废。重规划（TC-PLAN-098）因此不再断言「selector 原样保留」，
/// 而断言**子树根沿用上次那份** —— 它现在就是范围的唯一载体，丢它就是悄悄
/// 把范围放大回整包（分母会从 1 变 2，正是这条用例的判据）。
library;

// `Axis`（三条容器轴）与 flutter 的布局方向同名，本文件只用前者。
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/features/planner/planner_screen.dart';

import '../../support/pack_fixture.dart';

/// 计划范围的根（`system` 槽位），i1 / i2 是它下面的两项。
const String _root = 'root-a';

const PackVersions _versions = PackVersions(
  skeleton: '1.0.0',
  payloads: <String, String>{'python': '0.1.0'},
);

PackContent _pack() => fixturePack(
  const <FixtureNode>[
    FixtureNode(_root, '甲', slot: LevelSlot.system),
    FixtureNode('i1', '一', parentId: _root, sourceRefs: <String>['src-a']),
    FixtureNode('i2', '二', parentId: _root, sourceRefs: <String>['src-a']),
  ],
  pluginId: 'python',
  packName: 'Python 语法分层',
  schemes: <String, List<String>>{
    'sch-full': <String>['i1', 'i2'],
  },
  sources: <String, String>{'src-a': 'src-a'},
);

/// 打开器的宿主：一个按钮 + 一件记录「路由回来了什么」的盒子。
///
/// [revising] 给了就是「重规划」那条路（`SPEC-PLAN-019`）。
Future<void> _pumpOpener(
  WidgetTester tester,
  void Function(PlanDraft? draft) onDone, {
  Plan? revising,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('opener'),
              onPressed: () async {
                onDone(
                  await PlannerScreen.open(
                    context,
                    pack: _pack(),
                    spaceId: 'python',
                    subtreeRoot: _root,
                    primaryAxis: Axis.major,
                    packVersions: _versions,
                    revising: revising,
                  ),
                );
              },
              child: const Text('打开规划'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TC-PLAN-068 打开的是整页，左栏与预览同在（SPEC-PLAN-017）', (
    WidgetTester tester,
  ) async {
    await _pumpOpener(tester, (PlanDraft? _) {});

    await tester.tap(find.byKey(const Key('opener')));
    await tester.pumpAndSettle();

    expect(find.byKey(plannerScreenKey), findsOneWidget);
    expect(find.byKey(const Key('planner-left')), findsOneWidget);
    expect(find.byKey(const Key('planner-preview')), findsOneWidget);
    // 标题带空间名：全屏之后页面上没有别的地方说得清「在给哪个空间做计划」。
    expect(find.text('规划 · Python 语法分层'), findsOneWidget);
    // 打开器那一页已被盖住（不是抽屉、不是弹层）。
    expect(find.byKey(const Key('opener')), findsNothing);
  });

  testWidgets('TC-PLAN-069 建计划后草稿回到调用方，页面自己关掉（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    PlanDraft? received;
    bool returned = false;
    await _pumpOpener(tester, (PlanDraft? draft) {
      received = draft;
      returned = true;
    });

    await tester.tap(find.byKey(const Key('opener')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('planner-method-method-bundle-memory')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(returned, isTrue, reason: '建完必须把草稿交回去，不能留在页面上');
    expect(received, isNotNull);
    expect(received!.spaceId, 'python');
    expect(received!.subtreeRoot, _root);
    expect(received!.schemeId, 'sch-full');
    expect(received!.sourcePolicy, <String, Object?>{'primary': 'src-a'});
    expect(find.byKey(plannerScreenKey), findsNothing, reason: '建完即走');
    expect(find.byKey(const Key('opener')), findsOneWidget);
  });

  testWidgets('TC-PLAN-070 返回按钮是取消：草稿为 null（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    PlanDraft? received;
    bool returned = false;
    await _pumpOpener(tester, (PlanDraft? draft) {
      received = draft;
      returned = true;
    });

    await tester.tap(find.byKey(const Key('opener')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(plannerScreenBackKey));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(
      received,
      isNull,
      reason: '取消不能悄悄造出一份「三段都没选」的计划',
    );
    expect(find.byKey(const Key('opener')), findsOneWidget);
  });

  testWidgets('TC-PLAN-098 传 revising 就是重规划：三段与范围都预填，planId 与预填同源（SPEC-PLAN-019）', (
    WidgetTester tester,
  ) async {
    // 上次那份计划的范围是 `i1` 一个节点 —— 与调用方给的 `_root` 不同，
    // 这样「重规划是否沿用旧范围」才有可观测的差别。
    const Plan revising = Plan(
      id: 'evt-created-1',
      subtreeRoot: 'i1',
      primaryAxis: Axis.major,
      packVersions: _versions,
      sourcePolicy: <String, Object?>{'primary': 'src-a'},
      schemeId: 'sch-full',
      methodProfileId: 'method-bundle-memory',
      // 版本只在 `fold` 那边数事件条数，面板这一层连碰都不碰（`P-6` 改的口径）。
      version: 3,
    );
    PlanDraft? received;
    await _pumpOpener(tester, (PlanDraft? draft) => received = draft,
        revising: revising);

    await tester.tap(find.byKey(const Key('opener')));
    await tester.pumpAndSettle();

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    // 三段都按上次的取值预填 —— 不新开「重规划界面」，就地改。
    expect(textOf('planner-confirm-source'), contains('src-a'));
    expect(textOf('planner-confirm-scheme'), contains('sch-full'));
    expect(textOf('planner-confirm-method'), contains('记忆优先'));
    // 范围也不能丢：只回填三段而把子树根换成整包，分母会从 1 变成 2。
    expect(textOf('preview-items'), '项数 1');
    expect(
      textOf('preview-denominator'),
      '分母 1',
      reason: '分母也是圈内 —— 沿用旧子树根，它不会跟着调用方的根放大',
    );
    // `planId` 与预填同源（同一个 `Plan`），不会出现「id 传 A、值来自 B」。
    expect(
      tester.widget<PlannerScreen>(find.byType(PlannerScreen)).planId,
      'evt-created-1',
    );

    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(
      received!.subtreeRoot,
      'i1',
      reason: '重规划沿用上次的范围，不是重新猜一个（也用回调用方传的整包根）',
    );
    expect(
      received!.primaryAxis,
      Axis.major,
      reason: '主序轴同样来自旧计划',
    );
  });
}
