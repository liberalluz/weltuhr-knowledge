import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

import '../../support/m2_pack.dart';

void main() {
  group('pack_reader（新格式解析层）', () {
    test('M2 六段齐全即可解析（SPEC-PACK-005）', () {
      final PackContent pack = loadM2Pack();
      expect(pack.pack.pluginId, 'm2-demo');
      expect(pack.nodes.length, 9);
      expect(pack.edges.length, 15);
      expect(pack.entries.length, 6);
      expect(pack.sources.length, 2);
      expect(pack.schemes.length, 2);
      expect(pack.methods.length, 1);
    });

    test('按 level_slot 分派：1 个 system + 8 个 planet（无 SPEC：ADR-0007 决策 3）', () {
      final PackContent pack = loadM2Pack();
      expect(pack.learnableNodes.length, 8);
      expect(
        pack.nodes.whereType<StructuralNode>().single.levelSlot,
        LevelSlot.system,
      );
      expect(pack.nodeOf('m2-demo:var'), isA<LearnableNode>());
      expect(pack.nodeOf('m2-demo:lang-core'), isA<StructuralNode>());
    });

    test('三类边按判别符分派，`⪯` 只由 required 先修边构成（SPEC-FND-005）', () {
      final PackContent pack = loadM2Pack();
      expect(pack.edges.whereType<ParentEdge>().length, 10);
      expect(pack.edges.whereType<WormholeEdge>().length, 1);
      expect(pack.prerequisites.length, 4);
      expect(pack.prerequisites.where((PrerequisiteEdge e) => e.isRequired).length, 2);
    });

    test('主父唯一：secondary 归属不冒充父（无 SPEC：entity-fields §3）', () {
      final PackContent pack = loadM2Pack();
      final List<ParentEdge> parents = pack.edges
          .whereType<ParentEdge>()
          .where((ParentEdge e) => e.childId == 'm2-demo:idiom')
          .toList();
      expect(parents.length, 2);
      expect(parents.where((ParentEdge e) => e.isMain).length, 1);
      expect(parents.singleWhere((ParentEdge e) => e.isMain).parentId, 'm2-demo:lang-core');
    });

    test('段内 id 唯一：nodes 重复即拒（SPEC-PACK-008）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> nodes = pack['nodes']! as List<Object?>;
        nodes.add(nodes.first);
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('id 重复'),
          ),
        ),
      );
    });

    test('entries 按 node_id 查重，不是按数组下标（SPEC-PACK-008）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> entries = pack['entries']! as List<Object?>;
        entries.add(entries.first);
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('m2-demo:var'),
          ),
        ),
      );
    });

    test('六段缺一即格式错误（SPEC-PACK-005）', () {
      final String json = mutateM2((JsonMap pack) => pack.remove('methods'));
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('`methods` 段'),
          ),
        ),
      );
    });

    test('顶层出现六段与清单字段之外的键即拒（SPEC-PACK-007）', () {
      final String json = mutateM2((JsonMap pack) {
        pack['notes'] = <String>['笔记模板不进包'];
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('`notes`'),
          ),
        ),
      );
    });

    test('counts 与 nodes 实扫不一致即拒 —— 摘要与正文不能各说各话（无 SPEC：B13a 笔 4 新增判据）', () {
      final String json = mutateM2((JsonMap pack) {
        final JsonMap payload = pack['payload']! as JsonMap;
        final JsonMap counts = payload['counts']! as JsonMap;
        counts['planet'] = 7;
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(contains('payload.counts.planet'), contains('8')),
          ),
        ),
      );
    });

    test('先修边成环即拒（SPEC-FND-005）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> edges = pack['edges']! as List<Object?>;
        edges.add(<String, Object?>{
          'type': 'prerequisite',
          'from_id': 'm2-demo:func',
          'to_id': 'm2-demo:var',
          'strength': 'required',
        });
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('出现环'),
          ),
        ),
      );
    });

    test('未知边类型不在册即报，允许值一并列出（无 SPEC：判别符口径）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> edges = pack['edges']! as List<Object?>;
        final JsonMap first = edges.first! as JsonMap;
        first['type'] = 'unknown';
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(contains('边类型不在册'), contains('prerequisite')),
          ),
        ),
      );
    });

    test('非法槽位组合当场抛，不静默存活（ADR-0007 决策 4）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> nodes = pack['nodes']! as List<Object?>;
        final JsonMap core = nodes.first! as JsonMap;
        // 学科轴没有 galaxy 槽位（`skeleton-catalog`：学科轴只占 group + star）。
        core['axis'] = 'discipline';
        core['level_slot'] = 'galaxy';
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('非法的节点槽位组合'),
          ),
        ),
      );
    });

    test('`edges` 段不按 id 查重：两端相同的 parent 与 wormhole 是两条边（无 SPEC：边无 id）', () {
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> edges = pack['edges']! as List<Object?>;
        edges.add(<String, Object?>{
          'type': 'wormhole',
          'from_id': 'm2-demo:var',
          'to_id': 'm2-demo:func',
          'kind': 'same_name',
        });
        edges.add(<String, Object?>{
          'type': 'wormhole',
          'from_id': 'm2-demo:var',
          'to_id': 'm2-demo:func',
          'kind': 'granularity',
        });
      });
      final PackContent pack = readPack(json);
      expect(pack.edges.length, 17);
      expect(pack.edges.whereType<WormholeEdge>().length, 3);
    });

    test('类方法与源可达（无 SPEC：README 级便利：三个索引都建好）', () {
      final PackContent pack = loadM2Pack();
      expect(pack.nodeById.length, 9);
      expect(pack.entryByNodeId.length, 6);
      expect(pack.sourceById.length, 2);
      expect(pack.schemeNodes('m2-official')!.length, 4);
      expect(pack.schemeNodes('nope'), isNull);
      expect(pack.sourceById['m2-catalog']!.isCatalog, isTrue);
    });
  });
}
