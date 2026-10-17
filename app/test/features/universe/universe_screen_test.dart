import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/view/zoom.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';
import 'package:project_knowledge/features/universe/universe_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  // 场景缓慢自转 ⇒ `repeat()` 永不停，`pumpAndSettle` 永远等不到静止，
  // 只能用定长 pump 推进若干帧。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

void main() {
  group('宇宙视图的 HUD 七区块（SPEC-VIEW-018）', () {
    testWidgets('默认 Z1：①③⑤⑥⑦ 在，② 与 ④ 不在（SPEC-VIEW-018）', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UniverseScreen(scene: buildSyntheticScene())),
      );
      await _pump(tester);

      expect(find.byKey(hudBreadcrumbKey), findsOneWidget);
      expect(find.byKey(hudScopeSettingsKey), findsOneWidget);
      expect(find.byKey(hudFocusStarKey), findsOneWidget);
      expect(find.byKey(hudAxisCompassKey), findsOneWidget);
      expect(find.byKey(hudZoomScaleKey), findsOneWidget);

      expect(
        find.byKey(hudFilterChipsKey),
        findsNothing,
        reason: '② 是状态栏，激活才出现（VIEW-019）',
      );
      expect(
        find.byKey(hudDetailDrawerKey),
        findsNothing,
        reason: '④ 详情只在 Z4 出现（VIEW-013）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('切到 Z4 ⇒ ④ 出现、面包屑含 Z4（SPEC-VIEW-018）', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UniverseScreen(scene: buildSyntheticScene())),
      );
      await _pump(tester);

      await tester.tap(find.text('Z4 单星'));
      await _pump(tester);

      expect(find.byKey(hudDetailDrawerKey), findsOneWidget);
      expect(find.text('宇宙 › Z4 单星'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('五档刻度全在，且当前档可反复切换不崩（SPEC-VIEW-001）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: UniverseScreen(scene: buildSyntheticScene())),
      );
      await _pump(tester);

      for (final ZoomLevel level in ZoomLevel.values) {
        expect(find.text('${level.code} ${level.label}'), findsOneWidget);
      }
      for (final ZoomLevel level in ZoomLevel.values.reversed) {
        await tester.tap(find.text('${level.code} ${level.label}'));
        await _pump(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
