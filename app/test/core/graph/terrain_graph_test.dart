import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/terrain_graph.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

import '../../support/kind_packs.dart';
import '../../support/m2_pack.dart';

const String _closure = 'm2-demo:closure';
const String _func = 'm2-demo:func';
const String _module = 'm2-demo:module';
const String _typing = 'm2-demo:typing';
const String _var = 'm2-demo:var';

/// M2（载荷，自带 `var → func → closure` 的必学链）+ 一个地形包合图。
///
/// 地形边指向 **M2 的节点**，一条边两端分属两个包 —— 这正是「单包视角看不见」
/// 的形态，也是本类存在的理由。
TerrainGraph _graphOf({
  required List<({String from, String to, EdgeStrength strength})> terrainEdges,
}) {
  final PackContent m2 = readPack(m2PackJson());
  final PackContent terrain = readPack(
    m4VariantJson(pluginId: 'm4-terrain', edges: terrainEdges),
  );
  return TerrainGraph.of(<PackContent>[m2, terrain]);
}

void main() {
  group('TerrainGraph（跨包地形图）', () {
    test('TC-FND-021 跨包必学链可传递：地形包的 closure→typing 接上 M2 的 var→func→closure（SPEC-FND-005）', () {
      final TerrainGraph graph = _graphOf(
        terrainEdges: <({String from, String to, EdgeStrength strength})>[
          (from: _closure, to: _typing, strength: EdgeStrength.required),
        ],
      );

      // 第一跳来自地形包、其后三跳来自 M2 —— 少任何一边这条链都断。
      expect(graph.requiredPredecessorsOf(_typing), <String>[
        _closure,
        _func,
        _var,
      ]);
    });

    test(
      'TC-FND-022 `requiredEdges` 只留必学边，建议边仍在 `edges` 里但不进 `⪯`（SPEC-FND-005）',
      () {
        final TerrainGraph graph = _graphOf(
          terrainEdges: <({String from, String to, EdgeStrength strength})>[
            (from: _closure, to: _typing, strength: EdgeStrength.required),
            (from: _module, to: _var, strength: EdgeStrength.recommended),
          ],
        );

        // M2 自带 4 条先修边（`var→func` / `func→closure` 必学、`closure⇢module` /
        // `module⇢refactor` 建议），地形包再给 2 条 ⇒ 全集 6、其中必学 3。
        expect(graph.edges, hasLength(6));
        expect(graph.requiredEdges, hasLength(3));

        final List<String> requiredPairs = graph.requiredEdges
            .map((PrerequisiteEdge edge) => '${edge.fromId}→${edge.toId}')
            .toList();
        expect(requiredPairs, isNot(contains('$_module→$_var')));

        // 建议边指进 `var`，`var` 的前置仍为空 —— 建议不构成可达性约束。
        expect(graph.requiredPredecessorsOf(_var), isEmpty);
      },
    );
  });
}
