import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

import '../../support/kind_packs.dart';
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
      expect(
        pack.prerequisites.where((PrerequisiteEdge e) => e.isRequired).length,
        2,
      );
    });

    test('主父唯一：secondary 归属不冒充父（无 SPEC：entity-fields §3）', () {
      final PackContent pack = loadM2Pack();
      final List<ParentEdge> parents = pack.edges
          .whereType<ParentEdge>()
          .where((ParentEdge e) => e.childId == 'm2-demo:idiom')
          .toList();
      expect(parents.length, 2);
      expect(parents.where((ParentEdge e) => e.isMain).length, 1);
      expect(
        parents.singleWhere((ParentEdge e) => e.isMain).parentId,
        'm2-demo:lang-core',
      );
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

    test('TC-PACK-069 顶层 domainNames 是清单字段，必须被接受（无 SPEC：entity-fields §1 `domainNames`）', () {
      final String json = mutateM2((JsonMap pack) {
        pack['domainNames'] = <String, String>{'dom-oop': '面向对象'};
      });
      expect(readPack(json).pack.domainNames, <String, String>{
        'dom-oop': '面向对象',
      });
    });

    test('TC-PACK-070 domainNames 写成空表同样合法 —— 空值不是坏值（无 SPEC：同上）', () {
      // 这一条盯的是白名单不能靠「有没有值」判断合法性：空表也是这个键，
      // 拒掉它就等于要求每个包都必须有域名，而 `english` / `german` 没有。
      final String json = mutateM2((JsonMap pack) {
        pack['domainNames'] = <String, String>{};
      });
      expect(readPack(json).pack.domainNames, isEmpty);
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

    test('TC-FND-015 环检测覆盖两类边：整环全是 `recommended` 也拒（SPEC-FND-005）', () {
      // m2 原本已有 `closure ⇢ module ⇢ refactor` 两条建议边，补上 `refactor ⇢ closure`
      // 就闭成一个**只由 `recommended` 构成**的环。
      // ⚠️ 这条用例是「环检测不得只筛 required」的唯一装置：`kahnLevels` 只沿
      // required 边走，所以这个环**不会**让任何层号算错 —— 把 `pack_reader` 的
      // 过滤改成 `requiredEdgesOf(...)`，`φ` 相关的用例全绿，只有本条会红。
      final String json = mutateM2((JsonMap pack) {
        final List<Object?> edges = pack['edges']! as List<Object?>;
        edges.add(<String, Object?>{
          'type': 'prerequisite',
          'from_id': 'm2-demo:refactor',
          'to_id': 'm2-demo:closure',
          'strength': 'recommended',
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

  group('pack_reader（非载荷两类包）', () {
    test('overlay 包六段齐全即可装载，六段内容可以为空（无 SPEC：kind 不决定段是否非空）', () {
      final PackContent pack = loadM3Pack();
      expect(pack.pack.kinds, <PackKind>[PackKind.overlay]);
      expect(pack.pack.overlay!.targetScope, Scope.s4);
      expect(pack.pack.overlay!.patchCount, 0);
      expect(pack.pack.payload, isNull);
      expect(pack.nodes, isEmpty);
      expect(pack.edges, isEmpty);
      expect(pack.entries, isEmpty);
    });

    test('terrain 包只带边不带节点，摘要与实扫相符（无 SPEC：terrain 只贡献地形）', () {
      final PackContent pack = loadM4Pack();
      expect(pack.pack.kinds, <PackKind>[PackKind.terrain]);
      expect(pack.nodes, isEmpty);
      expect(pack.prerequisites.length, 3);
      final int required = pack.prerequisites
          .where((PrerequisiteEdge e) => e.isRequired)
          .length;
      expect(required, 1);
      expect(pack.pack.terrain!.requiredCount, required);
      expect(
        pack.pack.terrain!.recommendedCount,
        pack.prerequisites.length - required,
      );
      expect(pack.pack.terrain!.axesCovered, <Axis>[Axis.major]);
    });

    test('声明了 kind 却没给特化字段即拒（无 SPEC：entity-fields §1）', () {
      final String json = mutateM3((JsonMap pack) => pack.remove('overlay'));
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(contains('m3-overlay'), contains('特化字段')),
          ),
        ),
      );
    });

    test('带了特化字段却没声明 kind 即拒 —— 那份数据不会被任何一方读取（无 SPEC：同上）', () {
      final String json = mutateM4((JsonMap pack) {
        pack['kinds'] = <String>[];
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(contains('m4-terrain'), contains('不会被任何一方读取')),
          ),
        ),
      );
    });

    test('TC-FND-016 terrain 的 `required` 条数与实扫不符即拒（无 SPEC：entity-fields §1 `edge_counts`）', () {
      final String json = mutateM4((JsonMap pack) {
        final JsonMap terrain = pack['terrain']! as JsonMap;
        final JsonMap counts = terrain['edge_counts']! as JsonMap;
        counts['required'] = 2;
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(
              contains('terrain.edge_counts.required'),
              contains('edges[]'),
            ),
          ),
        ),
      );
    });

    test('TC-FND-017 `recommended` 条数与 `required` 一多一少、总数不变时仍拒（无 SPEC：同上）', () {
      final String json = mutateM4((JsonMap pack) {
        final JsonMap terrain = pack['terrain']! as JsonMap;
        final JsonMap counts = terrain['edge_counts']! as JsonMap;
        // 声明 2 + 1 = 3、实扫 1 + 2 = 3 —— **总数一样**，只有分类不同。
        // 若解析器对「边总数」，这条会静默通过；而这两类在语义上不可互换
        // （一类构成 `⪯`，一类不构成），所以必须分开对。
        counts['required'] = 2;
        counts['recommended'] = 1;
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(
              contains('terrain.edge_counts.required'),
              contains('terrain.edge_counts.recommended'),
            ),
          ),
        ),
      );
    });

    test('TC-FND-018 `axes_covered` 为空即拒（无 SPEC：entity-fields §1）', () {
      final String json = mutateM4((JsonMap pack) {
        (pack['terrain']! as JsonMap)['axes_covered'] = <String>[];
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('不得为空'),
          ),
        ),
      );
    });

    test('TC-FND-019 `axes_covered` 出现 `axes[]` 之外的轴即拒（无 SPEC：entity-fields §1，两份声明互相打脸）', () {
      final String json = mutateM4((JsonMap pack) {
        // `occupation` 是合法轴名，但 M4 的 `axes[]` 只声明了 `major`。
        (pack['terrain']! as JsonMap)['axes_covered'] = <String>[
          'major',
          'occupation',
        ];
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            allOf(contains('occupation'), contains('里没有的轴')),
          ),
        ),
      );
    });

    test('TC-FND-020 `axes_covered` 元素重复即拒（无 SPEC：entity-fields §1）', () {
      final String json = mutateM4((JsonMap pack) {
        (pack['terrain']! as JsonMap)['axes_covered'] = <String>[
          'major',
          'major',
        ];
      });
      expect(
        () => readPack(json),
        throwsA(
          isA<PackContentException>().having(
            (PackContentException e) => e.problems.join('\n'),
            'problems',
            contains('重复'),
          ),
        ),
      );
    });
  });
}
