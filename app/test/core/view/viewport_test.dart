import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/view/viewport.dart';

void main() {
  group('绘制表面按面积封顶（C-33）', () {
    test('不超过基准窗口时按原尺寸画，scale = 1（C-33）', () {
      final ViewportPlan plan = planViewport(1280, 800);
      expect(plan.surfaceWidth, 1280);
      expect(plan.surfaceHeight, 800);
      expect(plan.scale, 1);
      expect(plan.isDownscaled, isFalse);

      final ViewportPlan exact = planViewport(
        frameBenchWidth,
        frameBenchHeight,
      );
      expect(exact.isDownscaled, isFalse, reason: '恰好等于基准不降分辨率');
    });

    test('4K 窗口缩到基准尺寸再放大：表面 1920×1080、scale 2（C-33）', () {
      final ViewportPlan plan = planViewport(3840, 2160);
      expect(plan.surfaceWidth, closeTo(frameBenchWidth, 1e-6));
      expect(plan.surfaceHeight, closeTo(frameBenchHeight, 1e-6));
      expect(plan.scale, closeTo(2, 1e-6));
      expect(plan.isDownscaled, isTrue);
    });

    test('按面积判而不是按单边：2560×1080 与 1920×1440 同分支（C-33）', () {
      final ViewportPlan wide = planViewport(2560, 1080);
      final ViewportPlan tall = planViewport(1920, 1440);
      expect(wide.scale, closeTo(tall.scale, 1e-6));
      expect(
        wide.surfaceWidth * wide.surfaceHeight,
        closeTo(frameBenchWidth * frameBenchHeight, 1e-6),
        reason: '两者面积相同 ⇒ 封顶后面积相同，与长宽比无关',
      );
    });
  });
}
