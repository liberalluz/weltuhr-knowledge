import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/graph/levels.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/tree.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

/// 只装一个包的树，空间与域都展开 —— 大多数用例要的是「看得见全部层级」。
List<TreeRow> _build(
  LoadedPack pack, {
  bool expandSpace = true,
  bool expandDomains = true,
  Set<String>? visibleIds,
}) => buildTree(
  <LoadedPack>[pack],
  spaceId: pack.space.id,
  expandedSpaces: <String>{if (expandSpace) pack.space.id},
  expandedDomains: expandDomains
      ? pack.space.domainIds.toSet()
      : const <String>{},
  visibleIds: visibleIds,
);

void main() {
  group('树行模型（VIEW-006 / 007 / 008）', () {
    test('四层：知识 → 空间 → 域 → 项，顺序与 manifest.domainIds 一致（SPEC-VIEW-006）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<TreeRow> rows = _build(pack);

      expect(rows.first.kind, TreeRowKind.root, reason: '第 1 行永远是 `知识`');
      expect(rows.first.depth, 0);
      expect(rows.first.label, '知识');
      expect(
        rows.first.expandable,
        isFalse,
        reason: '`知识` 恒展开 ⇒ 没有折叠箭头（`VIEW-006` 修订第 3 条）',
      );

      final List<TreeRow> spaces = rows
          .where((TreeRow r) => r.kind == TreeRowKind.space)
          .toList();
      expect(spaces.length, 1);
      expect(spaces.single.id, pack.space.id);
      expect(spaces.single.depth, 1);
      expect(spaces.single.label, spaceLabelOf(pack.space.id), reason: '与面包屑同一口径');

      final List<TreeRow> domains = rows
          .where((TreeRow r) => r.kind == TreeRowKind.domain)
          .toList();
      expect(domains.length, pack.space.domainIds.length);
      expect(
        domains.map((TreeRow r) => r.id).toList(),
        pack.space.domainIds,
        reason: '域的先后由清单定，不由项数或标题定',
      );
      for (final TreeRow domain in domains) {
        expect(domain.depth, 2);
      }
      for (final TreeRow item in rows.where(
        (TreeRow r) =>
            r.kind == TreeRowKind.item ||
            r.kind == TreeRowKind.outsideNeighbor ||
            r.kind == TreeRowKind.blackHole,
      )) {
        expect(item.depth, 3, reason: '项 / 黑洞 / 圈外邻项都在第 4 层');
      }
    });

    test('只有当前空间展开 —— 别的空间只出一行（SPEC-VIEW-006 修订）', () {
      final LoadedPack a = fixturePack(const <FixtureItem>[
        FixtureItem('python/a', '甲'),
      ]);
      final LoadedPack b = fixturePack(
        const <FixtureItem>[FixtureItem('go/b', '乙', domainId: 'go/base')],
        spaceId: 'go',
        spaceName: 'Go 语法分层',
      );

      final List<TreeRow> rows = buildTree(
        <LoadedPack>[a, b],
        spaceId: 'python',
        expandedSpaces: const <String>{'python'},
        expandedDomains: const <String>{'python/lexical'},
      );

      expect(
        rows.where((TreeRow r) => r.kind == TreeRowKind.space).length,
        2,
        reason: '`知识` = 所有空间，两个包就两行',
      );
      expect(
        rows.where((TreeRow r) => r.kind == TreeRowKind.domain).length,
        1,
        reason: '`go` 收着 ⇒ 它的域一行都不出',
      );
      expect(
        rows.where((TreeRow r) => r.spaceId == 'go').length,
        1,
        reason: '`go` 只剩空间行自己',
      );
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

      final List<TreeRow> rows = _build(pack);
      final List<TreeRow> items = rows
          .where((TreeRow r) => r.kind == TreeRowKind.item)
          .toList();
      expect(items.length, 7, reason: 'φ=0 的 3 项 + φ=1 的 2 项 + φ=2 的 2 项');
      for (final TreeRow row in items) {
        expect(row.phiLevel, lessThanOrEqualTo(2));
      }
    });

    test('域内按 φ 升序、同层按标题（无 SPEC：域内排序属设计裁定）', () {
      // 用夹具而不拿 α 包：α 包 maxφ=63，首屏只展到 φ=2，深层的顺序看不见。
      // 夹具 maxφ 小 ⇒ 一次展开到底，整条链都在。
      final LoadedPack pack = fixturePack(
        const <FixtureItem>[
          FixtureItem('python/lexical/c', '丙'),
          FixtureItem('python/lexical/a', '甲'),
          FixtureItem('python/lexical/b', '乙'),
          FixtureItem('python/lexical/d', '丁'),
        ],
        edges: const <List<String>>[
          <String>['python/lexical/a', 'python/lexical/b'],
          <String>['python/lexical/b', 'python/lexical/c'],
        ],
      );
      final Map<String, int> levels = kahnLevels(
        nodeIds: pack.items.map((Item i) => i.id),
        edges: pack.edges,
      );
      final List<TreeRow> rows = _build(pack);

      int previous = -1;
      for (final TreeRow row in rows.where(
        (TreeRow r) => r.kind == TreeRowKind.item,
      )) {
        expect(
          row.phiLevel,
          greaterThanOrEqualTo(previous),
          reason: '同域内不允许 φ 回退',
        );
        previous = row.phiLevel;
        expect(levels[row.id], row.phiLevel, reason: '行的 φ 必须等于 Kahn 层号');
      }
      // 同层按标题：`甲`（a）与 `丁`（d）都在 φ=0。
      final List<String> layer0 = <String>[
        for (final TreeRow row in rows)
          if (row.kind == TreeRowKind.item && row.phiLevel == 0) row.label,
      ];
      expect(layer0, <String>['丁', '甲'], reason: '同层按标题升序，与宇宙的深度一致');
    });

    test('指向未知的画成黑洞行：虚线、不可展开、恒在末位（SPEC-VIEW-007）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<TreeRow> rows = _build(pack);
      final List<TreeRow> holes = rows
          .where((TreeRow r) => r.kind == TreeRowKind.blackHole)
          .toList();

      expect(holes.length, 3, reason: 'α 包 3 条边指向未知');
      for (final TreeRow hole in holes) {
        expect(hole.dashed, isTrue);
        expect(hole.expandable, isFalse, reason: '无实体 ⇒ 展开也没有内容');
        expect(hole.label, isNotEmpty, reason: '黑洞要有痕迹名，不能是空行');
        expect(hole.spaceId, pack.space.id, reason: '黑洞也要知道往哪个空间里找');
      }
    });

    test('圈外邻项在树里是 outsideNeighbor 且虚线，不混进 item（无 SPEC：VIEW-004 的邻项口径）', () {
      // α 包**零圈外项**，这条分支在真包上不可达 —— 拿真包测它只能测到「没走
      // 到那条分支」。所以必须用夹具：它是唯一能造出 `inScope: false` 的地方。
      final LoadedPack pack = fixturePack(<FixtureItem>[
        const FixtureItem('python/lexical/inside', '圈内项'),
        const FixtureItem('python/lexical/outside', '圈外邻项', inScope: false),
      ]);
      final List<TreeRow> rows = _build(pack);

      final TreeRow outside = rows.firstWhere(
        (TreeRow r) => r.id == 'python/lexical/outside',
      );
      expect(outside.kind, TreeRowKind.outsideNeighbor);
      expect(outside.dashed, isTrue, reason: '虚线是「存在但不是本空间的」的唯一视觉标记');
      expect(outside.depth, 3);
      expect(outside.expandable, isFalse, reason: '圈外项不给展开 —— 展开等于声称它有结构');
      expect(outside.label, '圈外邻项', reason: '仍要写原文标题，不能隐去');

      final TreeRow inside = rows.firstWhere(
        (TreeRow r) => r.id == 'python/lexical/inside',
      );
      expect(inside.kind, TreeRowKind.item);
      expect(inside.dashed, isFalse);
    });

    test('筛选只作用于当前根（SPEC-VIEW-021）：别的空间的项不被当前空间的筛选藏掉', () {
      final LoadedPack a = fixturePack(const <FixtureItem>[
        FixtureItem('python/a', '甲'),
        FixtureItem('python/b', '乙'),
      ]);
      final LoadedPack b = fixturePack(
        const <FixtureItem>[FixtureItem('go/c', '丙', domainId: 'go/base')],
        spaceId: 'go',
        spaceName: 'Go 语法分层',
      );

      final List<TreeRow> rows = buildTree(
        <LoadedPack>[a, b],
        spaceId: 'python',
        expandedSpaces: const <String>{'python', 'go'},
        expandedDomains: const <String>{'python/lexical', 'go/base'},
        visibleIds: const <String>{'python/a'},
      );

      expect(
        rows
            .where(
              (TreeRow r) =>
                  r.spaceId == 'python' && r.kind == TreeRowKind.item,
            )
            .map((TreeRow r) => r.id),
        <String>['python/a'],
        reason: '当前根里只留筛中的那一项',
      );
      expect(
        rows
            .where(
              (TreeRow r) => r.spaceId == 'go' && r.kind == TreeRowKind.item,
            )
            .map((TreeRow r) => r.id),
        <String>['go/c'],
        reason: '另一个空间的项没被筛过，藏掉它等于替用户判了另一份数据',
      );
    });
  });
}
