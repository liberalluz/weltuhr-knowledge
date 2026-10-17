import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/detail.dart';

import '../../support/alpha_pack.dart';

void main() {
  group('详情渲染模型（VIEW-014 / VIEW-017）', () {
    test('关系区按边方向落：to 是前置、from 是后继（SPEC-VIEW-014）', () {
      final LoadedPack pack = loadAlphaPack();
      final Edge edge = pack.edges.firstWhere(
        (Edge e) => pack.itemOf(e.from) != null && pack.itemOf(e.to) != null,
      );

      final ItemDetail downstream = buildItemDetail(pack, edge.to)!;
      expect(
        downstream.relations.any(
          (RelationRow r) =>
              r.kind == RelationKind.prerequisite && r.itemId == edge.from,
        ),
        isTrue,
        reason: '${edge.to} 的前置里必须有 ${edge.from}',
      );

      final ItemDetail upstream = buildItemDetail(pack, edge.from)!;
      expect(
        upstream.relations.any(
          (RelationRow r) =>
              r.kind == RelationKind.successor && r.itemId == edge.to,
        ),
        isTrue,
        reason: '${edge.from} 的后继里必须有 ${edge.to}',
      );
    });

    test('端口不在册 ⇒ 缺口行：无 itemId、虚线、点不动（SPEC-VIEW-007）', () {
      final LoadedPack pack = loadAlphaPack();
      final Edge dangling = pack.edges.firstWhere(
        (Edge e) => pack.itemOf(e.to) == null,
      );

      final ItemDetail detail = buildItemDetail(pack, dangling.from)!;
      final RelationRow gap = detail.relations.firstWhere(
        (RelationRow r) => r.kind == RelationKind.gap,
      );
      expect(gap.itemId, isNull);
      expect(gap.tappable, isFalse, reason: '缺口没有实体可跳（VIEW-014 的六个入口不含它）');
      expect(gap.dashed, isTrue, reason: '指向未知在宇宙里也是虚线');
      expect(gap.label, isNotEmpty, reason: '缺口要有痕迹名');
      expect(detail.gapRelationCount, greaterThan(0));
    });

    test('六要件恒定六行，顺序 = RequirementKey.values（SPEC-FND-004）', () {
      final LoadedPack pack = loadAlphaPack();
      final ItemDetail detail = buildItemDetail(pack, pack.items.first.id)!;

      expect(detail.requirements.length, RequirementKey.values.length);
      expect(
        detail.requirements.map((RequirementRow r) => r.key).toList(),
        RequirementKey.values,
        reason: '要件区的顺序不能跟着 JSON 键序走',
      );
      expect(
        detail.gapCount,
        detail.requirements.where((RequirementRow r) => r.isGap).length,
      );
    });

    test('来源区按 sourceRefs 解析出源名、等级与摘录（SPEC-VIEW-004）', () {
      final LoadedPack pack = loadAlphaPack();
      final Item item = pack.items.firstWhere(
        (Item i) => i.sourceRefs.isNotEmpty,
      );

      final ItemDetail detail = buildItemDetail(pack, item.id)!;
      expect(detail.provenance.length, item.sourceRefs.length);
      for (final ProvenanceRow row in detail.provenance) {
        expect(row.missing, isFalse, reason: 'α 包里 sourceRefs 都指向真实 SourceRef');
        expect(row.name, isNotEmpty);
        expect(row.authorityLevel, isNotEmpty);
      }
      expect(
        detail.provenance.first.segments,
        isNotEmpty,
        reason: '离线可读要求摘录在包里（entity-fields §9）',
      );
    });

    test('缺源的等级标签写「缺源」，不写成空串（SPEC-VIEW-004）', () {
      const ProvenanceRow row = ProvenanceRow(
        name: 'gone',
        authorityLevel: '',
        segments: <ProvenanceSegment>[],
        missing: true,
      );
      expect(row.levelLabel, '缺源');
      expect(row.missing, isTrue);
    });

    test('项不在册 ⇒ null，不造空壳详情（无 SPEC：造空壳会让人以为这项存在）', () {
      final LoadedPack pack = loadAlphaPack();
      expect(buildItemDetail(pack, 'does-not-exist'), isNull);
    });
  });
}
