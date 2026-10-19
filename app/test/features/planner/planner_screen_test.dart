/// Planner 全屏承载的 Widget 回归（`SPEC-PLAN-017` 修订 / `SPEC-PLAN-016`）。
///
/// 夹具只要「三段各够选一次」：源一条、体系覆盖全部项、方法一套内置 ——
/// 这三件事在别处（`planner_panel_test`）已经验透，这里验的是**进出的边界**：
/// 打开之后是不是一整页、建完草稿有没有真的回到调用方、取消有没有变成 `null`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
Future<void> _pumpOpener(
  WidgetTester tester,
  void Function(PlanDraft? draft) onDone,
) async {
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
                  await PlannerScreen.open(context, pack: _pack()),
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
}
