import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/view/detail.dart';

import '../../support/pack_fixture.dart';

const String _scopeRoot = 'python:func';

/// 『装饰器 ← 装饰器参数』是一条 `required` 先修边；『装饰器协议』的端口故意
/// 不建节点 ⇒ 缺口行。`quirk` 一项引用了包里没有的源 ⇒ 缺源行。
///
/// `python:fn-metaclass` 挂在另一个域下 ⇒ 它是「圈外邻项」（`VIEW-007`）。
PackContent _pack() => fixturePack(
  const <FixtureNode>[
    FixtureNode('python:root', '研究生目录', slot: LevelSlot.supercluster),
    FixtureNode(
      'python:func',
      '函数',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    FixtureNode(
      'python:lex',
      '词法',
      slot: LevelSlot.group,
      parentId: 'python:root',
    ),
    FixtureNode(
      'python:fn-decorator',
      '装饰器',
      parentId: 'python:func',
      sourceRefs: <String>['tutorial'],
      steps: <EntryStep>[
        EntryStep(
          operator: ExecutionOperator.read,
          instruction: '读完 §9.1。',
        ),
      ],
    ),
    FixtureNode(
      'python:fn-decorator-params',
      '装饰器参数',
      parentId: 'python:func',
    ),
    FixtureNode('python:fn-metaclass', '元类', parentId: 'python:lex'),
    FixtureNode(
      'python:fn-orphan-source',
      '孤儿源',
      parentId: 'python:func',
      sourceRefs: <String>['tutorial', 'gone'],
    ),
  ],
  prerequisites: const <(String, String)>[
    ('python:fn-decorator', 'python:fn-decorator-params'),
    ('python:fn-decorator', 'python:fn-decorator-protocol'),
  ],
  recommended: const <(String, String)>[
    ('python:fn-metaclass', 'python:fn-decorator'),
  ],
  sources: const <String, String>{'tutorial': 'The Python Tutorial'},
);

void main() {
  late PackContent pack;

  setUpAll(() {
    pack = _pack();
  });

  group('详情渲染模型（VIEW-014 / VIEW-017）', () {
    test('关系区按边方向落：to 是前置、from 是后继（SPEC-VIEW-014）', () {
      final ItemDetail downstream = buildItemDetail(
        pack,
        'python:fn-decorator-params',
        subtreeRoot: _scopeRoot,
      )!;
      expect(
        downstream.relations.any(
          (RelationRow r) =>
              r.kind == RelationKind.prerequisite &&
              r.itemId == 'python:fn-decorator',
        ),
        isTrue,
        reason: '装饰器参数的前置里必须有装饰器',
      );

      final ItemDetail upstream = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;
      expect(
        upstream.relations.any(
          (RelationRow r) =>
              r.kind == RelationKind.successor &&
              r.itemId == 'python:fn-decorator-params',
        ),
        isTrue,
        reason: '装饰器的后继里必须有装饰器参数',
      );
    });

    test('端口不在册 ⇒ 缺口行：无 itemId、虚线、点不动（SPEC-VIEW-007）', () {
      final ItemDetail detail = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;
      final RelationRow gap = detail.relations.firstWhere(
        (RelationRow r) => r.kind == RelationKind.gap,
      );
      expect(gap.itemId, isNull);
      expect(gap.tappable, isFalse, reason: '缺口没有实体可跳（VIEW-014 的六个入口不含它）');
      expect(gap.label, isNotEmpty, reason: '缺口要有痕迹名');
      expect(detail.gapRelationCount, greaterThan(0));
    });

    test('`recommended` 先修边画虚线，`required` 画实线（ADR-0005 决策 4）', () {
      final ItemDetail decorator = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;
      final RelationRow suggested = decorator.relations.firstWhere(
        (RelationRow r) => r.itemId == 'python:fn-metaclass',
      );
      expect(suggested.dashed, isTrue, reason: 'recommended 不构成 ⪯');

      final RelationRow requiredEdge = decorator.relations.firstWhere(
        (RelationRow r) => r.itemId == 'python:fn-decorator-params',
      );
      expect(requiredEdge.dashed, isFalse);
    });

    test('圈外的邻项标 outside，圈内的不标（SPEC-VIEW-007）', () {
      final ItemDetail detail = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;
      expect(
        detail.relations
            .firstWhere((RelationRow r) => r.itemId == 'python:fn-metaclass')
            .outside,
        isTrue,
        reason: '元类挂在另一个域下',
      );
      expect(
        detail.relations
            .firstWhere(
              (RelationRow r) => r.itemId == 'python:fn-decorator-params',
            )
            .outside,
        isFalse,
      );
    });

    test('六要件恒定六行，顺序 = RequirementKey.values（SPEC-FND-004）', () {
      final ItemDetail detail = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;

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
      final ItemDetail detail = buildItemDetail(
        pack,
        'python:fn-decorator',
        subtreeRoot: _scopeRoot,
      )!;
      expect(detail.provenance, hasLength(1));
      final ProvenanceRow row = detail.provenance.single;
      expect(row.missing, isFalse);
      expect(row.name, 'The Python Tutorial');
      expect(row.authorityLevel, AuthorityLevel.official);
      expect(row.levelLabel, '官方');
      expect(
        row.segments,
        isNotEmpty,
        reason: '离线可读要求摘录在包里（entity-fields §11）',
      );
    });

    test('引用了包里没有的源 ⇒ 缺源行，不静默跳过（SPEC-VIEW-004）', () {
      final ItemDetail detail = buildItemDetail(
        pack,
        'python:fn-orphan-source',
        subtreeRoot: _scopeRoot,
      )!;
      expect(detail.provenance, hasLength(2));
      final ProvenanceRow gone = detail.provenance.last;
      expect(gone.missing, isTrue);
      expect(gone.name, 'gone');
      expect(gone.levelLabel, '缺源');
    });

    test('缺源的等级标签写「缺源」，不写成空串（SPEC-VIEW-004）', () {
      const ProvenanceRow row = ProvenanceRow(
        name: 'gone',
        authorityLevel: null,
        segments: <ProvenanceSegment>[],
        missing: true,
      );
      expect(row.levelLabel, '缺源');
      expect(row.missing, isTrue);
    });

    test('有源但没标等级（`catalog`）⇒ 写「目录」，不写空串（无 SPEC：entity-fields §11）', () {
      const ProvenanceRow row = ProvenanceRow(
        name: '研究生目录',
        authorityLevel: null,
        segments: <ProvenanceSegment>[],
        missing: false,
      );
      expect(row.levelLabel, '目录');
    });

    test('项不在册 ⇒ null，不造空壳详情（无 SPEC：造空壳会让人以为这项存在）', () {
      expect(
        buildItemDetail(pack, 'does-not-exist', subtreeRoot: _scopeRoot),
        isNull,
      );
    });

    test('结构节点没有要件 ⇒ 也返回 null（ADR-0007 决策 1）', () {
      expect(
        buildItemDetail(pack, 'python:func', subtreeRoot: _scopeRoot),
        isNull,
      );
    });
  });
}
