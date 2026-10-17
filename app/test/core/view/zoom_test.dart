import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/view/zoom.dart';

CameraState _state({ZoomLevel zoom = ZoomLevel.z1}) =>
    CameraState(zoom: zoom, yawRadians: 0.7, pitchRadians: 0.3);

void main() {
  group('五档视距（SPEC-VIEW-001 / VIEW-009）', () {
    test('φ 定档：0→Z1 · 1–2→Z2 · ≥3→Z3，无子树→Z4（SPEC-VIEW-009）', () {
      expect(zoomForPhi(0), ZoomLevel.z1);
      expect(zoomForPhi(1), ZoomLevel.z2);
      expect(zoomForPhi(2), ZoomLevel.z2);
      expect(zoomForPhi(3), ZoomLevel.z3);
      expect(zoomForPhi(63), ZoomLevel.z3, reason: 'α 包 maxφ=63 仍落 Z3');
      expect(
        zoomForPhi(0, hasChildren: false),
        ZoomLevel.z4,
        reason: '仅选中无子树 ⇒ 单星，优先于 φ 判据',
      );
    });

    test('切档保留视角：yaw / pitch 一字不动（SPEC-VIEW-009）', () {
      final CameraState before = _state();
      final CameraState after = before.withZoom(ZoomLevel.z3);

      expect(after.zoom, ZoomLevel.z3);
      expect(after.yawRadians, before.yawRadians);
      expect(after.pitchRadians, before.pitchRadians);
      expect(before.zoom, ZoomLevel.z1, reason: '原实例不可变');
    });

    test('聚焦项只在 Z4 保留，离开 Z4 即清空（无 SPEC：避免档位与选中态不一致）', () {
      final CameraState atStar = _state(
        zoom: ZoomLevel.z4,
      ).withZoom(ZoomLevel.z4, selectedItemId: 'python/lexical');
      expect(atStar.selectedItemId, 'python/lexical');

      expect(atStar.withZoom(ZoomLevel.z2).selectedItemId, isNull);
      expect(
        atStar.withZoom(ZoomLevel.z3).selectedItemId,
        isNull,
        reason: '非 Z4 档位带着选中项会让「详情 = Z4 形态」这条裁定失真',
      );
    });
  });
}
