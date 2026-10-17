import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/features/universe/frame_painter.dart';
import 'package:project_knowledge/features/universe/scene_pick.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';

/// 三颗分得很开的星：`r` 落三个不同环带、`θ` 落三个不同扇区、`φ` 也拉开。
///
/// 用自制场景而不是 α 包：这一层验的是**装配与拾取是否同一套坐标**，
/// 星挤在一起会让「点中了谁」同时取决于重叠顺序，两种失败混在一条用例里。
SceneBundle _scene() => SceneBundle(
  origin: SceneOrigin.synthetic,
  nodes: <SceneNode>[
    const SceneNode(
      id: 'a',
      radial01: 0.1,
      sector: 0,
      sectorFraction01: 0,
      phiLevel: 0,
      phiFraction01: 0.05,
      size01: 0.3,
      brightness01: 1,
      dashed: false,
      colorIndex: 0,
      ringFill01: 0,
      ringClosed: false,
      pulse: 0,
    ),
    const SceneNode(
      id: 'b',
      radial01: 0.5,
      sector: 2,
      sectorFraction01: 0,
      phiLevel: 5,
      phiFraction01: 0.5,
      size01: 0.6,
      brightness01: 1,
      dashed: false,
      colorIndex: 2,
      ringFill01: 0,
      ringClosed: false,
      pulse: 0,
    ),
    const SceneNode(
      id: 'c',
      radial01: 0.9,
      sector: 4,
      sectorFraction01: 0,
      phiLevel: 9,
      phiFraction01: 0.95,
      size01: 0.9,
      brightness01: 1,
      dashed: false,
      colorIndex: 4,
      ringFill01: 0,
      ringClosed: false,
      pulse: 0,
    ),
  ],
  edges: const <EdgeSpan>[],
  notes: const <String>[],
  radialSegments: 3,
);

const Size _viewport = Size(1200, 800);

/// 某颗星在屏幕上的位置。**走 `buildSceneFrame`** —— 与绘制同一条装配。
Offset _screenOf(SceneBundle scene, String id, double yaw) {
  final SceneFrame sceneFrame = buildSceneFrame(
    scene: scene,
    viewportWidth: _viewport.width,
    viewportHeight: _viewport.height,
    yawRadians: yaw,
  );
  for (final ProjectedNode node in sceneFrame.frame.nodes) {
    if (node.id == id) {
      return Offset(
        sceneFrame.originX + node.x * sceneFrame.pixelsPerUnit,
        sceneFrame.originY + node.y * sceneFrame.pixelsPerUnit,
      );
    }
  }
  throw StateError('场景里没有 $id');
}

String? _pickAt(SceneBundle scene, Offset point, {double yaw = 0}) =>
    pickSceneNode(
      scene: scene,
      viewport: _viewport,
      yawRadians: yaw,
      point: point,
    );

void main() {
  group('点星拾取的装配（SPEC-VIEW-014 入口 1）', () {
    test('点各自的位置 ⇒ 逐个命中自己（SPEC-VIEW-014）', () {
      final SceneBundle scene = _scene();
      for (final String id in <String>['a', 'b', 'c']) {
        final Offset at = _screenOf(scene, id, 0);
        expect(
          _pickAt(scene, at),
          id,
          reason: '绘制与拾取若算了不同的 origin / pixelsPerUnit，这里会整体偏',
        );
      }
    });

    test('点视口角落 ⇒ null（SPEC-VIEW-014）', () {
      final SceneBundle scene = _scene();
      expect(_pickAt(scene, const Offset(4, 4)), isNull);
    });

    test('偏航变了，同一个屏幕点不再命中原来那颗（SPEC-VIEW-014）', () {
      final SceneBundle scene = _scene();
      final Offset at = _screenOf(scene, 'a', 0);
      // 宇宙在自转：拾取必须用**这一刻**的偏航。沿用基准偏航的话，这里仍会
      // 命中 `a` —— 而那正是「看着点中了、选中的却是旁边」的来源。
      final String? picked = _pickAt(scene, at, yaw: math.pi / 2);
      expect(picked, isNot('a'));
    });

    test('空场景 / 零尺寸视口 ⇒ null，不抛（SPEC-FND-014）', () {
      final SceneBundle empty = SceneBundle(
        origin: SceneOrigin.synthetic,
        nodes: const <SceneNode>[],
        edges: const <EdgeSpan>[],
        notes: const <String>[],
      );
      expect(
        pickSceneNode(
          scene: empty,
          viewport: _viewport,
          yawRadians: 0,
          point: const Offset(600, 400),
        ),
        isNull,
      );
      expect(
        pickSceneNode(
          scene: _scene(),
          viewport: Size.zero,
          yawRadians: 0,
          point: Offset.zero,
        ),
        isNull,
        reason: '首帧尺寸可能是 0，点下去不该崩',
      );
    });
  });
}
