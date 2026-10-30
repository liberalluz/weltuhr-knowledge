/// 树容器定位的作用域（`SPEC-VIEW-031`）。
///
/// 缺陷现场：选中「英语」后，窄态作用域落在骨架上 —— 因为英语这一行在骨架包里，
/// 而它下面的载荷域在 english 包里。判据不是「地址所在的包」，是「地址子树覆盖的
/// 包集合」；这组用例从界面这一层把两边的读数都钉住：
///
/// - 选中「英语」：只搜骨架 + english，德语一条都不该出现；
/// - 停在轴根：覆盖全部包，德语那条照常出现。
///
/// 两条都跑，才说明作用域真的跟着地址走，而不是碰巧恒等于全部。
library;

import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/features/locate/locate_overlay.dart';
import 'package:project_knowledge/features/tree/tree_screen.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';

import '../../support/pack_fixture.dart';

/// 骨架：一条轴，根下并排两个星 ——「英语」下挂 english 载荷，「德语」下挂 german。
PackContent _skeleton() => fixturePack(
  const <FixtureNode>[
    FixtureNode('sk:root', '学科', slot: LevelSlot.star),
    FixtureNode(
      'sk:en',
      '英语',
      slot: LevelSlot.star,
      parentId: 'sk:root',
      officialCode: '01',
    ),
    FixtureNode(
      'sk:de',
      '德语',
      slot: LevelSlot.star,
      parentId: 'sk:root',
      officialCode: '02',
    ),
  ],
  pluginId: 'skeleton',
  packName: '骨架',
  kinds: const <String>[],
  attachTo: '',
);

PackContent _english() => fixturePack(
  const <FixtureNode>[
    FixtureNode('en:np', '名词短语', slot: LevelSlot.system, parentId: 'sk:en'),
    FixtureNode('en:a1', '定冠词', parentId: 'en:np'),
    FixtureNode('en:a2', '不定冠词', parentId: 'en:np'),
  ],
  pluginId: 'english',
  packName: '英语',
  attachTo: 'sk:en',
);

PackContent _german() => fixturePack(
  const <FixtureNode>[
    FixtureNode('de:np', '名词短语', slot: LevelSlot.system, parentId: 'sk:de'),
    FixtureNode('de:a1', '德语定冠词', parentId: 'de:np'),
  ],
  pluginId: 'german',
  packName: '德语',
  attachTo: 'sk:de',
);

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: TreeScreen(
        contents: <PackContent>[_skeleton(), _english(), _german()],
      ),
    ),
  );
  await tester.pump();
}

Future<void> _searchArticle(WidgetTester tester) async {
  await tester.tap(find.byKey(treeLocateKey));
  await tester.pump();
  expect(find.byKey(locateOverlayKey), findsOneWidget);
  await tester.enterText(find.byKey(locateFieldKey), '冠词');
  await tester.pump();
}

void main() {
  testWidgets('选中「英语」：窄态只搜骨架 + english，德语一条不出现（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(treeRowKey('sk:en')));
    await tester.pump();

    await _searchArticle(tester);

    expect(find.text('定冠词'), findsOneWidget);
    expect(find.text('不定冠词'), findsOneWidget);
    expect(
      find.text('德语定冠词'),
      findsNothing,
      reason: 'de 分支不在 sk:en 的子树里，窄态不该搜到它',
    );
  });

  testWidgets('停在轴根：覆盖全部包，德语那条照常出现（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await _searchArticle(tester);

    expect(find.text('定冠词'), findsOneWidget);
    expect(find.text('德语定冠词'), findsOneWidget);
  });

  testWidgets('TC-VIEW-392 选中「英语」：三条命中全判圈内（SPEC-VIEW-031）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(treeRowKey('sk:en')));
    await tester.pump();

    await _searchArticle(tester);

    expect(find.text('定冠词'), findsOneWidget);
    expect(
      find.text('圈外'),
      findsNothing,
      reason:
          '圈定根 `sk:en` 在骨架包里、命中在 english 包里。单包父链到不了根，'
          '用合并表才连得上 —— 这里出一条「圈外」，就是父链还断着',
    );
  });

  testWidgets('TC-PLAN-109 选中「英语」：底部「按此范围建计划」出现（SPEC-PLAN-016）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(treeRowKey('sk:en')));
    await tester.pump();

    await _searchArticle(tester);

    expect(
      find.byKey(locatePlanHereKey),
      findsOneWidget,
      reason:
          '命中有落点、公共根在 english 包内。三条全判圈外时这个入口不出现，'
          'B4 的「三段跑通」就永远到不了',
    );
  });
}
