import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/frame/scene.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/alpha_pack.dart';

/// 六个要件全 `present` —— 让虚实判据只受被测的那一格影响。
ItemRequirements _allPresent({int notExternalizable = 0}) {
  final Map<RequirementKey, RequirementState> states =
      <RequirementKey, RequirementState>{
        for (final RequirementKey key in RequirementKey.values)
          key: RequirementState.present,
      };
  int left = notExternalizable;
  for (final RequirementKey key in RequirementKey.values) {
    if (left <= 0) {
      break;
    }
    states[key] = RequirementState.notExternalizable;
    left--;
  }
  return ItemRequirements(states);
}

Item _item(String id, String domainId, {String? primaryAxis}) => Item(
  id: id,
  title: id,
  sixAxis: <String, String>{'subject': '计算机科学', 'ability': '基础语法'},
  layer: Layer.persistent,
  type: ItemType.declarative,
  requirements: _allPresent(),
  sourceRefs: <String>['s'],
  domainId: domainId,
  inScope: true,
  primaryAxis: primaryAxis,
);

LoadedPack _pack({String? defaultPrimaryAxis, String? itemAxis}) => LoadedPack(
  space: KnowledgeSpace(
    id: 't',
    name: 't',
    version: '0.1.0',
    sixAxis: <String, String>{'subject': '计算机科学'},
    accent: '#000000',
    order: 1,
    domainIds: <String>['d1', 'd2'],
    defaultPrimaryAxis: defaultPrimaryAxis,
  ),
  items: <Item>[
    _item('t/a', 'd1', primaryAxis: itemAxis),
    _item('t/b', 'd2'),
  ],
  edges: <Edge>[
    const Edge(id: 'e1', from: 't/a', to: 't/b', type: EdgeType.strong),
    const Edge(id: 'e2', from: 't/b', to: 't/gone', type: EdgeType.unknown),
  ],
  schemes: const <Scheme>[],
  questions: const <Question>[],
  excerpts: const <SourceRef>[],
);

void main() {
  group('场景装配（ADR-0003）', () {
    test('r = 域带：段数 = 域数、每段等量、取环中线（ADR-0003）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);

      final Set<double> radii = <double>{
        for (final SceneNode node in nodes)
          if (!node.isPlaceholder) node.radial01,
      };
      expect(radii.length, 10, reason: '10 个域 ⇒ 10 条环带，不是 7 段');

      final Map<String, int> perDomain = <String, int>{};
      for (final Item item in pack.items) {
        final SceneNode node = nodes.firstWhere(
          (SceneNode n) => n.id == item.id,
        );
        final int index = pack.space.domainIds.indexOf(item.domainId);
        expect(
          node.radial01,
          (index + radialBandCenterOffset) / pack.space.domainIds.length,
          reason: '${item.id} 的环带序号应等于它的域序号',
        );
        perDomain[item.domainId] = (perDomain[item.domainId] ?? 0) + 1;
      }
      expect(perDomain.values.toSet(), <int>{15}, reason: '10 域 × 15 项');
    });

    test('φ 按层项数取累计分位，无零宽层（ADR-0003）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);

      final Map<int, double> fractionOfLevel = <int, double>{};
      for (final SceneNode node in nodes) {
        if (node.isPlaceholder) {
          continue;
        }
        fractionOfLevel[node.phiLevel] = node.phiFraction01;
      }
      final List<int> levels = fractionOfLevel.keys.toList()..sort();
      expect(fractionOfLevel[levels.first], 0, reason: 'φ=0 从 0 起');
      expect(fractionOfLevel[1], 3 / 150, reason: 'φ=1 的起点 = 0 层项数 / 总项数');
      for (int i = 1; i < levels.length; i++) {
        expect(
          fractionOfLevel[levels[i]]!,
          greaterThan(fractionOfLevel[levels[i - 1]]!),
          reason: '层 ${levels[i - 1]} → ${levels[i]} 的跨度必须 > 0',
        );
      }
    });

    test('虚实按 C-34：不可外化格 ≥ 3，命中集与 type=tacit 相同（C-34）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);

      final Set<String> dashed = <String>{
        for (final SceneNode node in nodes)
          if (node.dashed && !node.isPlaceholder) node.id,
      };
      expect(dashed.length, 3);
      expect(dashed, <String>{
        for (final Item item in pack.items)
          if (item.type == ItemType.tacit) item.id,
      }, reason: '两处标注在 α 包上是同一批，共线由 ADR-0003 §决策 2 记录');
    });

    test('端口不在册的边生成占位节点，有效边数不再减少（ADR-0003）', () {
      final LoadedPack pack = loadAlphaPack();
      final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);
      final List<SceneNode> placeholders = nodes
          .where((SceneNode node) => node.isPlaceholder)
          .toList();

      expect(placeholders.length, 3, reason: 'α 包 3 条边指向未知');
      for (final SceneNode node in placeholders) {
        expect(node.id.startsWith(placeholderIdPrefix), isTrue);
        expect(node.dashed, isTrue);
        expect(node.size01, 0);
      }
      expect(nodes.length, 153, reason: '150 项 + 3 个占位');

      final List<EdgeSpan> spans = buildEdgeSpans(pack, nodes);
      expect(spans.length, 170, reason: 'B2 时是 167（跳过的 3 条），现在由占位节点接住');
    });

    test('主轴缺省继承 manifest 默认，两者都缺则落「未声明」扇区（ADR-0003）', () {
      final int abilityIndex = sixAxisKeys.indexOf('ability');
      expect(abilityIndex, 3, reason: '六轴键序见 constants.sixAxisKeys');

      final List<SceneNode> inherited = buildSceneNodes(
        _pack(defaultPrimaryAxis: 'ability'),
        sectorCount: sixAxisKeys.length,
      );
      expect(inherited.first.sector, abilityIndex);

      final SceneNode overridden = buildSceneNodes(
        _pack(defaultPrimaryAxis: 'ability', itemAxis: 'stack'),
        sectorCount: sixAxisKeys.length,
      ).first;
      expect(
        overridden.sector,
        sixAxisKeys.indexOf('stack'),
        reason: '项级覆盖空间默认',
      );

      final SceneNode undeclared = buildSceneNodes(
        _pack(),
        sectorCount: sixAxisKeys.length,
      ).first;
      expect(
        undeclared.sector,
        sixAxisKeys.length,
        reason: '未声明用越界哨兵，不塞进任何一个轴',
      );
    });
  });
}
