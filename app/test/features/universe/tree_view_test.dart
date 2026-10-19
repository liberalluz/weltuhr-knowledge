import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/tree.dart';
import 'package:project_knowledge/features/universe/tree_view.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

Future<void> _pump(
  WidgetTester tester, {
  List<LoadedPack> packs = const <LoadedPack>[],
  String? spaceId,
  String? selectedItemId,
  String? selectedDomainId,
  TreePick? onSelectItem,
  TreePick? onSelectDomain,
  ValueChanged<String>? onSwitchRoot,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 700,
          child: TreeView(
            packs: packs,
            spaceId: spaceId ?? (packs.isEmpty ? null : packs.first.space.id),
            selectedItemId: selectedItemId,
            selectedDomainId: selectedDomainId,
            onSelectItem: onSelectItem ?? (String _, String _) {},
            onSelectDomain: onSelectDomain ?? (String _, String _) {},
            onSwitchRoot: onSwitchRoot ?? (String _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 与 widget 里的默认展开态一致：空间展开、域全展开。
List<TreeRow> _rowsOf(LoadedPack pack) => buildTree(
  <LoadedPack>[pack],
  spaceId: pack.space.id,
  expandedSpaces: <String>{pack.space.id},
  expandedDomains: pack.space.domainIds.toSet(),
);

void main() {
  final LoadedPack pack = loadAlphaPack();
  final List<TreeRow> rows = _rowsOf(pack);

  group('树视图（VIEW-006 / 007 / 008 / 012）', () {
    testWidgets('没有包 ⇒ 空态，不画一棵空树（SPEC-FND-014）', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(treeEmptyKey), findsOneWidget);
      expect(find.byKey(treeViewKey), findsNothing);
      expect(find.text('没有可展开的树'), findsOneWidget);
    });

    testWidgets('四层都出现，缩进逐层 +14 px（SPEC-VIEW-006 修订）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, packs: <LoadedPack>[pack]);

      expect(find.text('知识'), findsOneWidget);
      expect(find.text(spaceLabelOf(pack.space.id)), findsOneWidget);

      // 取四个「每层一行」的代表，比较它们名字区的左边界。用**名字区**而不是
      // 整行：整行的左边界里还含着 8 px 统一内边距，比出来的差值一样是 14，
      // 但那让「第 3 层 = 28」这条判据没法直接量。
      final TreeRow root = rows.first;
      final TreeRow space = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.space,
      );
      final TreeRow domain = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.domain,
      );
      final TreeRow item = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item && r.phiLevel == 0,
      );

      double leftOf(TreeRow row) =>
          tester.getTopLeft(find.byKey(treeRowKey(row))).dx;

      expect(rowIndentOf(root), 0);
      expect(rowIndentOf(space), treeLevelIndent);
      expect(rowIndentOf(domain), treeLevelIndent * 2);
      expect(rowIndentOf(item), treeLevelIndent * 3,
          reason: 'φ=0 的项不追加项内缩进');
      expect(leftOf(space) - leftOf(root), treeLevelIndent);
      expect(leftOf(domain) - leftOf(space), treeLevelIndent);
      expect(leftOf(item) - leftOf(domain), treeLevelIndent);
    });

    testWidgets('项内按 φ 缩进，封顶 C-92 级（SPEC-VIEW-006 修订第 5 条）', (
      WidgetTester tester,
    ) async {
      // 夹具的 maxφ 只有 2 ⇒ 首屏全展开，深层项看得见。
      final LoadedPack deep = fixturePack(
        const <FixtureItem>[
          FixtureItem('python/lexical/a', '甲'),
          FixtureItem('python/lexical/b', '乙'),
          FixtureItem('python/lexical/c', '丙'),
        ],
        edges: const <List<String>>[
          <String>['python/lexical/a', 'python/lexical/b'],
          <String>['python/lexical/b', 'python/lexical/c'],
        ],
      );
      final List<TreeRow> deepRows = _rowsOf(deep);
      final TreeRow phi0 = deepRows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item && r.phiLevel == 0,
      );
      final TreeRow phi2 = deepRows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item && r.phiLevel == 2,
      );
      expect(rowIndentOf(phi2) - rowIndentOf(phi0), treeLevelIndent * 2);

      // 封顶：φ 超过 `C-92` 之后不再变深。
      final TreeRow capped = TreeRow(
        kind: TreeRowKind.item,
        id: 'x',
        label: 'x',
        depth: 3,
        expandable: false,
        dashed: false,
        phiLevel: treePhiIndentCap + 10,
      );
      expect(
        rowIndentOf(capped),
        rowIndentOf(phi2) + (treePhiIndentCap - 2) * treeLevelIndent,
        reason: '超出封顶的 φ 不再缩进 —— 再缩就把深层项推出屏幕',
      );
    });

    testWidgets('`知识` 没有折叠箭头，点它也没有回调（SPEC-VIEW-006 修订第 3 条）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, packs: <LoadedPack>[pack]);

      expect(find.byKey(treeArrowKey(rows.first)), findsNothing);

      // 点名字：不该有任何异常，也不该触发任何回调。回 `Z0` 的入口在面包屑第 1
      // 段，这里再放一个就是同一个去处开两个门。
      await tester.tap(find.byKey(treeRowKey(rows.first)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('首屏：域全展开，项只到 φ=2（SPEC-VIEW-008）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, packs: <LoadedPack>[pack]);

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

    testWidgets('点域的箭头收起 ⇒ 该域的项行消失、域行还在（SPEC-VIEW-006 修订第 3 条）', (
      WidgetTester tester,
    ) async {
      await _pump(tester, packs: <LoadedPack>[pack]);

      final int domainIndex = rows.indexWhere(
        (TreeRow r) => r.kind == TreeRowKind.domain,
      );
      final TreeRow domain = rows[domainIndex];
      final TreeRow first = rows[domainIndex + 1];
      expect(first.depth, 3, reason: '首屏域是展开的');

      expect(find.byKey(treeRowKey(first)), findsOneWidget);
      // **点箭头**而不是点整行：修订第 3 条把两个动作拆开了（箭头折叠、文字选中）。
      // 点整行从这一条起是「选中这个域」，不是「收起它」。
      await tester.tap(find.byKey(treeArrowKey(domain)));
      await tester.pump();

      expect(find.byKey(treeRowKey(first)), findsNothing);
      expect(find.byKey(treeRowKey(domain)), findsOneWidget, reason: '域行本身还在');
    });

    testWidgets('点域名 ⇒ 回传域名与它所属的空间，且不选中任何项（SPEC-VIEW-006 修订）', (
      WidgetTester tester,
    ) async {
      String? pickedDomain;
      String? pickedSpace;
      String? pickedItem;
      final TreeRow domain = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.domain,
      );
      await _pump(
        tester,
        packs: <LoadedPack>[pack],
        onSelectDomain: (String spaceId, String id) {
          pickedSpace = spaceId;
          pickedDomain = id;
        },
        onSelectItem: (String spaceId, String id) => pickedItem = id,
      );

      await tester.tap(find.byKey(treeRowKey(domain)));
      await tester.pump();

      expect(pickedDomain, domain.id);
      expect(pickedSpace, pack.space.id, reason: '域属于哪个空间必须一起回传');
      expect(pickedItem, isNull, reason: '选中域不是选中一项');
    });

    testWidgets('点空间名 ⇒ 换根回调，且不折叠那一行（SPEC-VIEW-006 修订第 2 条）', (
      WidgetTester tester,
    ) async {
      String? root;
      final TreeRow space = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.space,
      );
      await _pump(
        tester,
        packs: <LoadedPack>[pack],
        onSwitchRoot: (String id) => root = id,
      );

      await tester.tap(find.byKey(treeRowKey(space)));
      await tester.pump();

      expect(root, pack.space.id);
      expect(
        find.byKey(treeRowKey(rows.firstWhere((TreeRow r) => r.depth == 2))),
        findsOneWidget,
        reason: '换根不是折叠 —— 域行该照样在',
      );
    });

    testWidgets('点圈内项行回调 itemId（SPEC-VIEW-012：点行等于聚焦）', (
      WidgetTester tester,
    ) async {
      String? picked;
      String? pickedSpace;
      final TreeRow item = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.item,
      );
      await _pump(
        tester,
        packs: <LoadedPack>[pack],
        onSelectItem: (String spaceId, String id) {
          pickedSpace = spaceId;
          picked = id;
        },
      );

      await tester.tap(find.byKey(treeRowKey(item)));
      await tester.pump();
      expect(picked, item.id);
      expect(pickedSpace, pack.space.id);
    });

    testWidgets('黑洞行不回调 —— 没有实体就没有详情可看（SPEC-VIEW-007）', (
      WidgetTester tester,
    ) async {
      String? picked;
      final TreeRow hole = rows.firstWhere(
        (TreeRow r) => r.kind == TreeRowKind.blackHole,
      );
      await _pump(
        tester,
        packs: <LoadedPack>[pack],
        onSelectItem: (String _, String id) => picked = id,
      );

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
      await _pump(tester, packs: <LoadedPack>[pack], selectedItemId: item.id);

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

    testWidgets('选中域与未选中域的视觉可区分（SPEC-VIEW-006 修订第 3 条）', (
      WidgetTester tester,
    ) async {
      // 选中域不开抽屉（第 4 条）⇒ 「选上了」这件事只能在行上看见。看不见的话，
      // 用户点完域名唯一的反馈是面包屑多一段，而树里那一行毫无变化。
      final List<TreeRow> domains = rows
          .where((TreeRow r) => r.kind == TreeRowKind.domain)
          .toList();
      await _pump(
        tester,
        packs: <LoadedPack>[pack],
        selectedDomainId: domains.first.id,
      );

      Color? colorOf(TreeRow row) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(treeRowKey(row)),
              matching: find.text(row.label),
            ),
          )
          .style
          ?.color;

      expect(colorOf(domains.first), isNot(colorOf(domains[1])));
    });
  });
}
