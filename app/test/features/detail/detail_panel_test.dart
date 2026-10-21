import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/view/detail.dart';
import 'package:project_knowledge/features/detail/detail_panel.dart';

import '../../support/pack_fixture.dart';

/// 笔 5c：`loadAlphaPack()` 随 α 包夹具一起删了，这里改成**自己搭一个形状可控
/// 的小包**。旧版靠 `_firstWhere` 在 α 包里翻「哪一项有可点关系 / 哪一项有缺口」
/// —— 那是拿真数据碰运气；形状由本文件给定之后，直接点名 `py-a` 就够。
const String _scopeRoot = 'python:lex';

/// 三区要能同时渲染，夹具就必须同时具备三件事：
/// - `sourceRefs` 指向一个**带 `segments`** 的源（否则来源区是空的）
/// - 一条两端都在包内的先修边（可点）
/// - 一条指向包外节点的先修边（缺口，点不动）
PackContent _pack() => fixturePack(
  <FixtureNode>[
    const FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    const FixtureNode(
      _scopeRoot,
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    const FixtureNode(
      'py-a',
      'Lambda 表达式',
      parentId: _scopeRoot,
      sourceRefs: <String>['src-official'],
    ),
    const FixtureNode(
      'py-b',
      '闭包',
      parentId: _scopeRoot,
      sourceRefs: <String>['src-official'],
    ),
    const FixtureNode('py-c', '装饰器', parentId: _scopeRoot),
  ],
  // (前置, 后继)：`py-b → py-a` 两端都在册 ⇒ 可点；`py-a → py-gone` ⇒ 缺口。
  prerequisites: <(String, String)>[('py-b', 'py-a'), ('py-a', 'py-gone')],
  sources: const <String, String>{'src-official': '官方文档'},
);

/// 三区分区 + 笔记区的显示顺序（按屏幕 y 坐标）。
List<Key> _sectionOrder(WidgetTester tester) {
  final List<Key> keys = <Key>[
    detailRelationsSectionKey,
    detailRequirementsSectionKey,
    detailProvenanceSectionKey,
    detailNotesSectionKey,
  ];
  final List<Key> present = keys
      .where((Key k) => find.byKey(k).evaluate().isNotEmpty)
      .toList();
  present.sort(
    (Key a, Key b) => tester
        .getTopLeft(find.byKey(a))
        .dy
        .compareTo(tester.getTopLeft(find.byKey(b)).dy),
  );
  return present;
}

Future<void> _pump(
  WidgetTester tester, {
  required ItemDetail? detail,
  bool compact = false,
  ValueChanged<String>? onSelectItem,
  VoidCallback? onBack,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          // 贴近真实的窄壳尺寸：分区顺序靠 element 树断，不靠滚动去凑。
          child: SizedBox(
            width: 360,
            height: 800,
            child: DetailPanel(
              detail: detail,
              compact: compact,
              onSelectItem: onSelectItem,
              onBack: onBack,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final PackContent pack = _pack();
  final ItemDetail detail = buildItemDetail(
    pack,
    'py-a',
    subtreeRoot: _scopeRoot,
  )!;

  group('详情面板（VIEW-012 / 014 / 017）', () {
    testWidgets('三区 + 笔记区齐，顺序为 关系 → 要件 → 来源 → 笔记（SPEC-VIEW-017）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, detail: detail);

      expect(find.byKey(detailPanelKey), findsOneWidget);
      expect(_sectionOrder(tester), <Key>[
        detailRelationsSectionKey,
        detailRequirementsSectionKey,
        detailProvenanceSectionKey,
        detailNotesSectionKey,
      ], reason: '两壳一套内容：字段与顺序由渲染模型定，不由 widget 布局定');
      expect(tester.takeException(), isNull);
    });

    testWidgets('未选中 ⇒ 空态一行字，三区一个都不渲染（SPEC-VIEW-012）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, detail: null);

      expect(find.byKey(detailPanelKey), findsOneWidget);
      expect(find.text('未选中知识项'), findsOneWidget);
      expect(find.byKey(detailRelationsSectionKey), findsNothing);
      expect(find.byKey(detailRequirementsSectionKey), findsNothing);
      expect(find.byKey(detailProvenanceSectionKey), findsNothing);
      expect(find.byKey(detailNotesSectionKey), findsNothing);
    });

    testWidgets('窄壳与宽壳的字段顺序完全一致（SPEC-VIEW-017）', (WidgetTester tester) async {
      await _pump(tester, detail: detail);
      final List<Key> wide = _sectionOrder(tester);

      await _pump(tester, detail: detail, compact: true);
      final List<Key> narrow = _sectionOrder(tester);

      expect(narrow, wide, reason: '只换布局断点，不动字段与顺序');
    });

    testWidgets('关系行点击回调对方 itemId，缺口行点不动（SPEC-VIEW-014）', (
      WidgetTester tester,
    ) async {
      final RelationRow tappable = detail.relations.firstWhere(
        (RelationRow r) => r.tappable,
      );
      final RelationRow gap = detail.relations.firstWhere(
        (RelationRow r) => r.kind == RelationKind.gap,
      );

      String? picked;
      await _pump(
        tester,
        detail: detail,
        onSelectItem: (String id) => picked = id,
      );
      await tester.tap(find.byKey(detailRelationRowKey(tappable)));
      await tester.pump();
      expect(picked, tappable.itemId);

      picked = null;
      await tester.tap(find.byKey(detailRelationRowKey(gap)));
      await tester.pump();
      expect(picked, isNull, reason: '缺口没有实体，点了不该跳');
      expect(tester.takeException(), isNull);
    });

    testWidgets('笔记区是可识别的空壳，不是能写字的输入框（SPEC-NOTE-007）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, detail: detail);

      expect(find.byKey(detailNotesSectionKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(detailNotesSectionKey),
          matching: find.byType(TextField),
        ),
        findsNothing,
        reason: '可输入的框会让人以为写完能存',
      );
    });

    testWidgets('返回按钮：给了回调才渲染，点了就原样交出去（SPEC-VIEW-015）', (
      WidgetTester tester,
    ) async {
      int taps = 0;

      await _pump(tester, detail: detail);
      expect(
        find.byKey(detailBackKey),
        findsNothing,
        reason: '没有可退的地方 ⇒ 按下去什么也不会变，所以不渲染',
      );

      await _pump(tester, detail: detail, onBack: () => taps++);
      expect(find.byKey(detailBackKey), findsOneWidget);
      expect(find.text(detailBackLabel), findsOneWidget);

      await tester.tap(find.byKey(detailBackKey));
      await tester.pump();
      expect(taps, 1, reason: '面板不算「能不能退」，只把点击交出去');
    });

    testWidgets('返回按钮在标题之上，不挤动三区的顺序（SPEC-VIEW-015 / 017）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, detail: detail, onBack: () {});

      final double backY = tester.getTopLeft(find.byKey(detailBackKey)).dy;
      final double titleY = tester.getTopLeft(find.text('Lambda 表达式')).dy;
      expect(backY, lessThan(titleY), reason: '返回是出口，放在标题上面才有「往出退」的方位感');
      expect(_sectionOrder(tester), <Key>[
        detailRelationsSectionKey,
        detailRequirementsSectionKey,
        detailProvenanceSectionKey,
        detailNotesSectionKey,
      ]);
    });
  });
}
