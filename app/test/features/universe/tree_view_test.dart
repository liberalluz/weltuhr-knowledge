import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/tree.dart';
import 'package:project_knowledge/features/universe/tree_view.dart';

import '../../support/alpha_pack.dart';

Future<void> _pump(
  WidgetTester tester, {
  LoadedPack? pack,
  String? selectedItemId,
  ValueChanged<String>? onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 700,
          child: TreeView(
            pack: pack,
            selectedItemId: selectedItemId,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final LoadedPack pack = loadAlphaPack();
  final List<TreeRow> rows = buildTree(
    pack,
    expandedDomains: pack.space.domainIds.toSet(),
    expandToPhi: initialExpandPhi(maxPhiOf(pack)),
  );

  group('树视图（VIEW-006 / 007 / 008 / 012）', () {
    testWidgets('没有包 ⇒ 空态，不画一棵空树（SPEC-FND-014）', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byKey(treeEmptyKey), findsOneWidget);
      expect(find.byKey(treeViewKey), findsNothing);
      expect(find.text('没有可展开的树'), findsOneWidget);
    });

    testWidgets('首屏：域全展开，项只到 φ=2（SPEC-VIEW-008）', (WidgetTester tester) async {
      await _pump(tester, pack: pack);

      expect(find.byKey(treeViewKey), findsOneWidget);
      expect(
        find.textContaining('展开到 φ=${initialExpandPhi(maxPhiOf(pack))}'),
        findsOneWidget,
        reason: '首屏展开几层写在标题行上，用户看得见也能自己判断',
      );
      // 列表是惰性的：只断言最前面几行建出来了，不断言「所有域行都在」——
      // 那断言问的是「ListView 缓存多大」，不是「树对不对」。
      expect(find.byKey(treeRowKey(rows.first)), findsOneWidget);
      final List<TreeRow> head = rows.take(3).toList();
      for (final TreeRow row in head) {
        expect(find.byKey(treeRowKey(row)), findsOneWidget);
      }
      final Iterable<TreeRow> items = rows.where(
        (TreeRow r) => r.kind == TreeRowKind.item,
      );
      expect(items, isNotEmpty);
      for (final TreeRow item in items) {
        expect(item.phiLevel, lessThanOrEqualTo(2), reason: '首屏项都该在 φ≤2');
      }
    });

    testWidgets('点域行收起 ⇒ 该域的项行消失（SPEC-VIEW-006）', (WidgetTester tester) async {
      await _pump(tester, pack: pack);

      final int domainIndex = rows.indexWhere(
        (TreeRow r) => r.kind == TreeRowKind.domain,
      );
      final TreeRow domain = rows[domainIndex];
      final TreeRow first = rows[domainIndex + 1];
      expect(first.depth, 1, reason: '首屏域是展开的');

      expect(find.byKey(treeRowKey(first)), findsOneWidget);
      await tester.tap(find.byKey(treeRowKey(domain)));
      await tester.pump();

      expect(find.byKey(treeRowKey(first)), findsNothing);
      expect(find.byKey(treeRowKey(domain)), findsOneWidget, reason: '域行本身还在');
    });

    testWidgets('点圈内项行回调 itemId（SPEC-VIEW-012：点行等于聚焦）', (
      WidgetTester tester,
    ) async {
      String? picked;
      final TreeRow item = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item,
      );
      await _pump(tester, pack: pack, onSelect: (String id) => picked = id);

      await tester.tap(find.byKey(treeRowKey(item)));
      await tester.pump();
      expect(picked, item.id);
    });

    testWidgets('黑洞行不回调 —— 没有实体就没有详情可看（SPEC-VIEW-007）', (
      WidgetTester tester,
    ) async {
      String? picked;
      final TreeRow hole = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.blackHole,
      );
      await _pump(tester, pack: pack, onSelect: (String id) => picked = id);

      await tester.tap(find.byKey(treeRowKey(hole)));
      await tester.pump();
      expect(picked, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('选中项与未选中项的视觉可区分（SPEC-VIEW-014：六个入口落点一致）', (
      WidgetTester tester,
    ) async {
      final TreeRow item = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item,
      );
      final TreeRow other = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item && r.id != item.id,
      );
      await _pump(tester, pack: pack, selectedItemId: item.id);

      Color? colorOf(TreeRow row) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(treeRowKey(row)),
              matching: find.text(row.label),
            ),
          )
          .style
          ?.color;

      expect(colorOf(item), isNotNull);
      expect(colorOf(item), isNot(colorOf(other)), reason: '选中行与未选中行字色必须不同');
    });
  });
}
