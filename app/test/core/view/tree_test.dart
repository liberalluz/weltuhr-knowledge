import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/graph/levels.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/tree.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

void main() {
  group('树行模型（VIEW-006 / 007 / 008）', () {
    test('第一层是域，顺序与 manifest.domainIds 一致（SPEC-VIEW-006）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: const <String>{},
        expandToPhi: 0,
      );

      final List<TreeRow> domains = rows
          .where((TreeRow r) => r.kind == TreeRowKind.domain)
          .toList();
      expect(domains.length, pack.space.domainIds.length);
      expect(
        domains.map((TreeRow r) => r.id).toList(),
        pack.space.domainIds,
        reason: '域的先后由清单定，不由项数或标题定',
      );
      expect(rows.length, domains.length, reason: '未展开的域只出一行');
    });

    test('深链空间首屏只展开到 φ=2（SPEC-VIEW-008）', () {
      final LoadedPack pack = loadAlphaPack();
      final Map<String, int> levels = kahnLevels(
        nodeIds: pack.items.map((Item i) => i.id),
        edges: pack.edges,
      );
      final int maxPhi = levels.values.reduce((int a, int b) => a > b ? a : b);
      expect(maxPhi, 63);
      expect(initialExpandPhi(maxPhi), 2, reason: 'α 包 maxφ=63 属深链');

      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: pack.space.domainIds.toSet(),
        expandToPhi: initialExpandPhi(maxPhi),
      );
      final List<TreeRow> items = rows
          .where((TreeRow r) => r.kind == TreeRowKind.item)
          .toList();
      expect(items.length, 7, reason: 'φ=0 的 3 项 + φ=1 的 2 项 + φ=2 的 2 项');
      for (final TreeRow row in items) {
        expect(row.phiLevel, lessThanOrEqualTo(2));
      }
    });

    test('域内按 φ 升序、同层按标题（无 SPEC：域内排序属设计裁定）', () {
      final LoadedPack pack = loadAlphaPack();
      final Map<String, int> levels = kahnLevels(
        nodeIds: pack.items.map((Item i) => i.id),
        edges: pack.edges,
      );
      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: pack.space.domainIds.toSet(),
        expandToPhi: 63,
      );

      // 单调性只在**同一域内**成立：跨域时 φ 从该域自己的最小层重新起算。
      int previous = -1;
      String? domain;
      for (final TreeRow row in rows) {
        if (row.kind == TreeRowKind.domain) {
          domain = row.id;
          previous = -1;
          continue;
        }
        if (row.kind != TreeRowKind.item) {
          continue;
        }
        expect(
          row.phiLevel,
          greaterThanOrEqualTo(previous),
          reason: '域 $domain 内不允许 φ 回退',
        );
        previous = row.phiLevel;
        expect(levels[row.id], row.phiLevel, reason: '行的 φ 必须等于 Kahn 层号');
      }
    });

    test('指向未知的画成黑洞行：虚线、不可展开、恒在末位（SPEC-VIEW-007）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: pack.space.domainIds.toSet(),
        expandToPhi: 63,
      );
      final List<TreeRow> holes = rows
          .where((TreeRow r) => r.kind == TreeRowKind.blackHole)
          .toList();

      expect(holes.length, 3, reason: 'α 包 3 条边指向未知');
      for (final TreeRow hole in holes) {
        expect(hole.dashed, isTrue);
        expect(hole.expandable, isFalse, reason: '无实体 ⇒ 展开也没有内容');
        expect(hole.label, isNotEmpty, reason: '黑洞要有痕迹名，不能是空行');
      }
    });

    test('圈外邻项在树里是 outsideNeighbor 且虚线，不混进 item（无 SPEC：VIEW-004 的邻项口径）', () {
      // α 包**零圈外项**，这条分支在真包上不可达 —— 拿真包测它只能测到「没走
      // 到那条分支」。所以必须用夹具：它是唯一能造出 `inScope: false` 的地方。
      final LoadedPack pack = fixturePack(<FixtureItem>[
        const FixtureItem('python/lexical/inside', '圈内项'),
        const FixtureItem('python/lexical/outside', '圈外邻项', inScope: false),
      ]);
      final List<TreeRow> rows = buildTree(
        pack,
        expandedDomains: const <String>{'python/lexical'},
        expandToPhi: 0,
      );

      final TreeRow outside = rows.firstWhere(
        (TreeRow r) => r.id == 'python/lexical/outside',
      );
      expect(outside.kind, TreeRowKind.outsideNeighbor);
      expect(outside.dashed, isTrue, reason: '虚线是「存在但不是本空间的」的唯一视觉标记');
      expect(outside.depth, 1);
      expect(outside.expandable, isFalse, reason: '圈外项不给展开 —— 展开等于声称它有结构');
      expect(outside.label, '圈外邻项', reason: '仍要写原文标题，不能隐去');

      final TreeRow inside = rows.firstWhere(
        (TreeRow r) => r.id == 'python/lexical/inside',
      );
      expect(inside.kind, TreeRowKind.item);
      expect(inside.dashed, isFalse);
    });
  });
}
