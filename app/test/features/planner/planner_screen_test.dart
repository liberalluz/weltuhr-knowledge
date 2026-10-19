/// Planner 全屏承载的 Widget 回归（`SPEC-PLAN-017` 修订 / `SPEC-PLAN-016`）。
///
/// 夹具只要「三段各够选一次」：源一条、体系覆盖全部项、方法一套内置 ——
/// 这三件事在别处（`planner_panel_test`）已经验透，这里验的是**进出的边界**：
/// 打开之后是不是一整页、建完草稿有没有真的回到调用方、取消有没有变成 `null`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/features/planner/planner_screen.dart';

import '../../support/pack_fixture.dart';

Map<String, Object?> _source(String id) => <String, Object?>{
  'id': id,
  'name': id,
  'authorityLevel': 'L1',
  'version': '1.0',
  'segments': <Map<String, Object?>>[
    <String, Object?>{
      'text': '节选',
      'locator': 'p.1',
      'license': 'CC-BY-4.0',
    },
  ],
  'appliesTo': <String, Object?>{},
};

LoadedPack _pack() => fixturePack(
  <FixtureItem>[
    const FixtureItem('i1', '一', sourceRefs: <String>['src-a']),
    const FixtureItem('i2', '二', sourceRefs: <String>['src-a']),
  ],
  spaceName: 'Python 语法分层',
  schemes: <String, List<String>>{
    'sch-full': <String>['i1', 'i2'],
  },
  excerpts: <Map<String, Object?>>[_source('src-a')],
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
    const Plan revising = Plan(
      id: 'evt-created-1',
      spaceId: 'python',
      spaceVersion: '0.1.0',
      target: PlanTarget(
        selector: <String, Object?>{'kind': 'item', 'itemId': 'i1'},
        resolved: <String>['i1'],
      ),
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
    // 范围也不能丢：只回填三段而把 `target` 放大成整个空间，是悄悄扩大计划。
    expect(textOf('preview-items'), '项数 1');
    expect(textOf('preview-denominator'), '分母 2');
    // `planId` 与预填同源（同一个 `Plan`），不会出现「id 传 A、值来自 B」。
    expect(
      tester.widget<PlannerScreen>(find.byType(PlannerScreen)).planId,
      'evt-created-1',
    );

    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(
      received!.target.selector,
      <String, Object?>{'kind': 'item', 'itemId': 'i1'},
      reason: '重规划沿用上次的选择式，不是重新猜一个',
    );
    expect(
      received!.target.resolved,
      <String>['i1'],
      reason: 'resolved 按当前包重算，但与 selector 圈定的仍是同一项',
    );
  });
}
