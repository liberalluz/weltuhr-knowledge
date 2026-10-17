/// 场景装配的两条路 —— 规模与形状是这一笔的输入口径，必须钉住。
///
/// 合成那一路的所有数字（150 / 167 / φ 63 / 0 层 3 项）都来自 `B2` 第 4 笔
/// 对 α 包的实测。它们写死在代码里，所以这里断言一遍：**改动了合成口径
/// 就是改动了帧率实测的输入**，得让测试叫出来。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';

void main() {
  group('合成场景的规模口径', () {
    test('×1 = 150 项 / 167 边（ADR-0002）', () {
      final SceneBundle scene = buildSyntheticScene();

      expect(scene.origin, SceneOrigin.synthetic);
      expect(scene.itemCount, 150);
      // 真包 170 条边里 3 条端点不在册 ⇒ 有效 167 条；合成按有效数量建。
      expect(scene.edgeCount, 167);
    });

    test('×2 = 300 项 / 334 边，且 id 不重复（ADR-0002）', () {
      final SceneBundle scene = buildSyntheticScene(copies: 2);
      final Set<String> ids = scene.nodes.map((node) => node.id).toSet();

      expect(scene.origin, SceneOrigin.syntheticDoubled);
      expect(scene.itemCount, 300);
      expect(scene.edgeCount, 334);
      expect(ids.length, 300, reason: '第二份必须改 id，否则边索引重映射后会指错');
    });

    test('层号 0…63，0 层恰好 3 项（ADR-0002）', () {
      final SceneBundle scene = buildSyntheticScene();
      int roots = 0;
      for (final SceneNode node in scene.nodes) {
        expect(node.phiLevel, inInclusiveRange(0, 63));
        if (node.phiLevel == 0) {
          roots += 1;
        }
      }

      expect(scene.maxPhi, 63);
      expect(roots, 3);
    });

    test('边索引全部落在节点范围内（ADR-0002）', () {
      final SceneBundle scene = buildSyntheticScene(copies: 2);
      for (final EdgeSpan edge in scene.edges) {
        expect(edge.fromIndex, inInclusiveRange(0, scene.itemCount - 1));
        expect(edge.toIndex, inInclusiveRange(0, scene.itemCount - 1));
        expect(edge.fromIndex, isNot(edge.toIndex), reason: '自环会让投影退化成零长线段');
      }
    });

    test('同一输入两次装配完全一致（无 SPEC：可复现读数属测量前提）', () {
      final SceneBundle first = buildSyntheticScene();
      final SceneBundle second = buildSyntheticScene();

      for (int i = 0; i < first.itemCount; i++) {
        expect(second.nodes[i].phiLevel, first.nodes[i].phiLevel);
        expect(second.nodes[i].radial01, first.nodes[i].radial01);
        expect(second.nodes[i].brightness01, first.nodes[i].brightness01);
      }
    });
  });

  group('真实 α 包装配', () {
    test('装出 150 节点 / 167 有效边 / 最大层号 63（SPEC-PACK-018）', () {
      final SceneResolution resolution = resolveAlphaScene();

      // 回落了就是回落了 —— 不当成「装配成功」放过去。
      expect(
        resolution.fellBack,
        isFalse,
        reason: resolution.fallbackReason ?? '',
      );
      expect(resolution.bundle.origin, SceneOrigin.alphaPack);
      expect(resolution.bundle.itemCount, 150);
      expect(resolution.bundle.edgeCount, 167);
      expect(resolution.bundle.maxPhi, 63);
    });
  });
}
