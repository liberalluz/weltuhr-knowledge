import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/skeleton_pack.dart';

/// 小骨架夹具：**两轴四级**，够走完五项校验的每条分支。
///
/// 为什么不拿 `content/skeleton/pack.json` 来测：那份产物**不入库**
/// （`SPEC-PACK-005`：`pack.json` 不入库、tag 是唯一指针），CI 里没有它。
/// 用合成夹具覆盖形态，真实包由本笔另跑一次核读数 —— 两件事分开，
/// 免得「夹具绿」被当成「对真实 3,375 节点验过」。
Map<String, Object?> _node(
  String id,
  Axis axis,
  LevelSlot slot, {
  String? code,
}) {
  final List<String> parts = id.split(RegExp(r'[/:]'));
  return <String, Object?>{
    'id': id,
    'axis': axis.name,
    'level_slot': slot.name,
    'official_code': code,
    'name': id,
    'slug': parts.last,
    'scope': 'S0',
    'pack_id': 'skeleton',
    'status': 'live',
    'tags': <String>[],
    'catalog_refs': <String>[],
  };
}

Map<String, Object?> _parentEdge(String child, String parent) => <String, Object?>{
  'type': 'parent',
  'child_id': child,
  'parent_id': parent,
  'kind': 'main',
};

/// 标准的两轴骨架：discipline 三级、major 四级。
List<Map<String, Object?>> _baseNodes() => <Map<String, Object?>>[
  _node('skeleton:discipline', Axis.discipline, LevelSlot.supercluster),
  _node('skeleton:discipline/01', Axis.discipline, LevelSlot.group, code: '01'),
  _node('skeleton:discipline/0101', Axis.discipline, LevelSlot.star, code: '0101'),
  _node('skeleton:major', Axis.major, LevelSlot.supercluster),
  _node('skeleton:major/01', Axis.major, LevelSlot.group, code: '01'),
  _node('skeleton:major/0101', Axis.major, LevelSlot.galaxy, code: '0101'),
  _node('skeleton:major/010101', Axis.major, LevelSlot.star, code: '010101'),
];

List<Map<String, Object?>> _baseEdges() => <Map<String, Object?>>[
  _parentEdge('skeleton:discipline/01', 'skeleton:discipline'),
  _parentEdge('skeleton:discipline/0101', 'skeleton:discipline/01'),
  _parentEdge('skeleton:major/01', 'skeleton:major'),
  _parentEdge('skeleton:major/0101', 'skeleton:major/01'),
  _parentEdge('skeleton:major/010101', 'skeleton:major/0101'),
];

String _packJson({
  List<Map<String, Object?>>? nodes,
  List<Map<String, Object?>>? edges,
  List<String> axes = const <String>['discipline', 'major'],
}) {
  return jsonEncode(<String, Object?>{
    'plugin_id': 'skeleton',
    'name': 'Weltuhr 骨架',
    'version': '1.0.0',
    // 骨架不走插件（`ADR-0005` 决策 2）⇒ `kinds` 空、四个 facts 全无。
    'kinds': <String>[],
    'namespace': 'skeleton',
    'schema_version': 1,
    'skeleton_requires': '>=1.0.0',
    'deps': <Object?>[],
    'license': 'unspecified',
    'author': 'weltuhr',
    'origin': 'content/skeleton',
    'review_state': 'pending',
    'signature': null,
    'axes': axes,
    'nodes': nodes ?? _baseNodes(),
    'edges': edges ?? _baseEdges(),
    'entries': <Object?>[],
    'sources': <Object?>[],
    'schemes': <Object?>[],
    'methods': <Object?>[],
  });
}

void main() {
  test('两轴小骨架装载：`path` 含轴根段、轴根可查（无 SPEC：skeleton-catalog §六 步骤 4）', () {
    final SkeletonPack skeleton = loadSkeleton(_packJson());

    expect(skeleton.nodeCount, 7);
    expect(skeleton.content.pack.kinds, isEmpty);
    expect(skeleton.axisRoots[Axis.discipline], 'skeleton:discipline');
    expect(skeleton.axisRoots[Axis.major], 'skeleton:major');

    // 轴根段不可省：两个轴的 `01` / `0101` 同码，去掉轴段就撞在同一个 path 上。
    expect(skeleton.paths['skeleton:discipline'], 'discipline');
    expect(skeleton.paths['skeleton:discipline/0101'], 'discipline/01/0101');
    expect(skeleton.paths['skeleton:major'], 'major');
    expect(skeleton.paths['skeleton:major/010101'], 'major/01/0101/010101');
  });

  test('`official_code` 轴内重复即拒（无 SPEC：skeleton-catalog §六 步骤 4 ①）', () {
    final List<Map<String, Object?>> nodes = _baseNodes();
    // 同一轴内第二条同码：官方码是 `id` 的原料，重码 = 两条目录条目共用一个身份。
    nodes[1]['official_code'] = '0101';
    nodes[2]['official_code'] = '0101';

    expect(
      () => loadSkeleton(_packJson(nodes: nodes)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('`official_code` 在轴 `discipline` 内重复'),
        ),
      ),
    );
  });

  test('主父缺失即拒：非根节点必须恰好一条 `main` 父边（无 SPEC：entity-fields §3）', () {
    final List<Map<String, Object?>> edges = _baseEdges()
      ..removeWhere((Map<String, Object?> e) => e['child_id'] == 'skeleton:discipline/0101');

    expect(
      () => loadSkeleton(_packJson(edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('主父不唯一 / 缺失'),
        ),
      ),
    );
  });

  test('父边成环即拒（无 SPEC：`readPack` 只查 `⪯` 环，父边环无人查）', () {
    final List<Map<String, Object?>> edges = _baseEdges()
      ..removeWhere((Map<String, Object?> e) => e['child_id'] == 'skeleton:discipline/01')
      ..add(_parentEdge('skeleton:discipline/01', 'skeleton:discipline/0101'));

    expect(
      () => loadSkeleton(_packJson(edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('父边有环'),
        ),
      ),
    );
  });

  test('孤儿即拒：父边端点必须在 `nodes[]` 里（无 SPEC：skeleton-catalog §六 步骤 4 ④）', () {
    final List<Map<String, Object?>> edges = _baseEdges()
      ..removeWhere((Map<String, Object?> e) => e['child_id'] == 'skeleton:major/01')
      ..add(_parentEdge('skeleton:major/01', 'skeleton:major/99'));

    expect(
      () => loadSkeleton(_packJson(edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('孤儿'),
        ),
      ),
    );
  });

  test('`star` 父链停在他轴根即拒（无 SPEC：skeleton-catalog §六 步骤 4 ⑤）', () {
    final List<Map<String, Object?>> edges = _baseEdges()
      ..removeWhere((Map<String, Object?> e) => e['child_id'] == 'skeleton:discipline/0101')
      ..add(_parentEdge('skeleton:discipline/0101', 'skeleton:major'));

    expect(
      () => loadSkeleton(_packJson(edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('`star` 父链未到轴根'),
        ),
      ),
    );
  });

  test('派生 `path` 重复即拒（无 SPEC：`P-07` 是独立断言，不由同父 slug 唯一推出）', () {
    final List<Map<String, Object?>> nodes = _baseNodes();
    // 同父同 slug：`readPack` 不查这一层（那是三元校验器的活），骨架这里必须自己拦。
    nodes.add(_node('skeleton:discipline/0101x', Axis.discipline, LevelSlot.star, code: '0101X'));
    nodes.last['slug'] = '0101';
    final List<Map<String, Object?>> edges = _baseEdges()
      ..add(_parentEdge('skeleton:discipline/0101x', 'skeleton:discipline/01'));

    expect(
      () => loadSkeleton(_packJson(nodes: nodes, edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('`path` 重复'),
        ),
      ),
    );
  });

  test('清单声明的轴没有 `supercluster` 根即拒（无 SPEC：轴根是 `path` 的唯一起点）', () {
    final List<Map<String, Object?>> nodes = _baseNodes()
      ..removeWhere((Map<String, Object?> n) => n['id'] == 'skeleton:major')
      ..removeWhere((Map<String, Object?> n) => n['id'] == 'skeleton:major/01');
    final List<Map<String, Object?>> edges = <Map<String, Object?>>[
      _parentEdge('skeleton:discipline/01', 'skeleton:discipline'),
      _parentEdge('skeleton:discipline/0101', 'skeleton:discipline/01'),
    ];

    expect(
      () => loadSkeleton(_packJson(nodes: nodes, edges: edges)),
      throwsA(
        isA<SkeletonPackException>().having(
          (SkeletonPackException e) => e.problems.join('\n'),
          'problems',
          contains('没有 `supercluster` 根节点'),
        ),
      ),
    );
  });
}
