import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/frame/scene.dart';
import 'package:project_knowledge/core/view/fit.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/alpha_pack.dart';

void main() {
  test('α 包全量投影落在 1080×600 视口内且不退化（C-38）', () {
    final LoadedPack pack = loadAlphaPack();
    final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);
    final List<EdgeSpan> edges = buildEdgeSpans(pack, nodes);

    final Camera base = Camera(
      yawRadians: 0.35,
      pitchRadians: 0.42,
      distance: 3,
      focal: 1.6,
      radialSegments: pack.space.domainIds.length,
      sectorCount: 6,
      phiHeight: 1.6,
      minDepth: 0.05,
    );
    final Camera fitted = fitCameraToViewport(
      nodes: nodes,
      edges: edges,
      base: base,
      viewportWidth: 1080,
      viewportHeight: 600,
      // 与 `frame_painter` 一致：绘制层会再乘一次最短边 × 0.85。
      pixelsPerUnit: 600 * 0.85,
    );
    final ProjectedFrame frame = projectFrame(
      nodes: nodes,
      edges: edges,
      camera: fitted,
    );

    double maxX = 0, maxY = 0, minX = 0, minY = 0;
    for (final ProjectedNode n in frame.nodes) {
      if (n.x > maxX) maxX = n.x;
      if (n.x < minX) minX = n.x;
      if (n.y > maxY) maxY = n.y;
      if (n.y < minY) minY = n.y;
    }
    debugPrint('focal=${fitted.focal} x=[$minX, $maxX] y=[$minY, $maxY] '
        'screenX=[${minX + 540}, ${maxX + 540}] screenY=[${300 - maxY}, ${300 - minY}]');

    const double pxPerUnit = 600 * 0.85;
    expect((maxX - minX) * pxPerUnit, greaterThan(20), reason: '横向不能塌成一点');
    expect((maxY - minY) * pxPerUnit, greaterThan(20), reason: '纵向不能塌成一点');
    expect(maxX * pxPerUnit, lessThanOrEqualTo(540), reason: '屏幕内');
    expect(maxY * pxPerUnit, lessThanOrEqualTo(300), reason: '屏幕内');
  });
}
