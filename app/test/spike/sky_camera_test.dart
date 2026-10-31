import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:project_knowledge/spike/spike_scene.dart';

/// 球心相机的用例。
///
/// 真机画面在沙箱里采不到（`SceneView` 要 GPU），但「拖 100 像素转多少弧度」
/// 「俯仰夹不夹得住」「滚轮把视场角夹在哪」这些算术可以逐条断言 —— 而这正是
/// `B17b` 出口判据一「天球可旋转可缩放」在沙箱里唯一能留下的证据。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TC-SPIKE-029 初始视线指向 +Z，赤道面水平（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera();
    final vm.Vector3 direction = camera.direction;

    expect(direction.x, closeTo(0, 1e-12));
    expect(direction.y, closeTo(0, 1e-12));
    expect(direction.z, closeTo(1, 1e-12));
    expect(camera.fovDeg, 70);
    expect(camera.autoSpin, isTrue);
  });

  test('TC-SPIKE-030 横向拖动改偏航、纵向拖动改俯仰（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera(yaw: 1.0);

    // 手指往右拖：天球跟着往右走 = 视线左转 = 偏航减少。
    camera.drag(const ui.Offset(100, 0));
    expect(camera.yaw, closeTo(1.0 - 100 * kDragRadiansPerPixel, 1e-12));

    // 手指往下拖：看向下方 = 俯仰增加。
    final double pitchBefore = camera.pitch;
    camera.drag(const ui.Offset(0, 50));
    expect(
      camera.pitch,
      closeTo(pitchBefore + 50 * kDragRadiansPerPixel, 1e-12),
    );
  });

  test('TC-SPIKE-031 俯仰夹在 ±(π/2 − 0.01)，拖到顶也不会翻过去（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera();

    // 一路往下拖一万像素：没有夹紧的话俯仰会到 5 弧度，视线翻到背后。
    for (int i = 0; i < 100; i++) {
      camera.drag(const ui.Offset(0, 100));
    }
    expect(camera.pitch, lessThanOrEqualTo(math.pi / 2));
    expect(camera.pitch, closeTo(math.pi / 2 - 0.01, 1e-12));

    for (int i = 0; i < 200; i++) {
      camera.drag(const ui.Offset(0, -100));
    }
    expect(camera.pitch, greaterThanOrEqualTo(-math.pi / 2));
    expect(camera.pitch, closeTo(-math.pi / 2 + 0.01, 1e-12));
  });

  test('TC-SPIKE-032 偏航绕一圈回到原处，不累加成无限大（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera(yaw: 0.5);
    final double before = camera.yaw;

    // 转满一整圈（2π / kDragRadiansPerPixel 像素），方向应回到原处。
    const double pixels = 2 * math.pi / kDragRadiansPerPixel;
    for (int i = 0; i < 10; i++) {
      camera.drag(ui.Offset(pixels / 10, 0));
    }
    expect(camera.yaw, closeTo(before, 1e-6));
    expect(camera.yaw, inInclusiveRange(0, 2 * math.pi));
  });

  test('TC-SPIKE-033 滚轮改视场角并夹在 20°–100°（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera();

    // 往上滚（delta 为正）= 放大 = 视场角变小。
    camera.zoom(100);
    expect(camera.fovDeg, closeTo(70 - kZoomDegreesPerNotch, 1e-12));

    // 一直放大到夹住下限。
    for (int i = 0; i < 100; i++) {
      camera.zoom(100);
    }
    expect(camera.fovDeg, kMinFovDeg);

    // 一直缩小到夹住上限。
    for (int i = 0; i < 200; i++) {
      camera.zoom(-100);
    }
    expect(camera.fovDeg, kMaxFovDeg);
  });

  test('TC-SPIKE-034 自动绕行可推进，一旦用户拖动就永久停（ADR-0006 决策一·球心相机）', () {
    final SkyCamera camera = SkyCamera();

    expect(camera.spin(1.0), isTrue);
    expect(camera.yaw, closeTo(kAutoSpinRadiansPerSecond, 1e-12));

    // dt <= 0 不动。
    expect(camera.spin(0), isFalse);

    // 用户一碰，自转永久退出，之后 spin 一律不动。
    camera.drag(const ui.Offset(10, 0));
    expect(camera.autoSpin, isFalse);
    final double stopped = camera.yaw;
    expect(camera.spin(10.0), isFalse);
    expect(camera.yaw, stopped);
  });

  testWidgets('TC-SPIKE-035 手势层把拖动落到相机上（ADR-0006 决策一·球心相机）', (
    WidgetTester tester,
  ) async {
    final SkyCamera camera = SkyCamera(yaw: 1.0);
    int changes = 0;

    await tester.pumpWidget(
      SkyGestureLayer(
        camera: camera,
        onChanged: () => changes++,
        child: const SizedBox(width: 200, height: 200),
      ),
    );

    // 从手势层自身的中心拖 —— 内容 `SizedBox` 在 `GestureDetector` 之下，
    // 拿它当落点会被 hit test 判为「没打中目标」。
    await tester.dragFrom(
      tester.getCenter(find.byType(SkyGestureLayer)),
      const ui.Offset(40, 0),
    );
    await tester.pump();

    expect(changes, greaterThan(0), reason: '拖动要通知上层重绘');
    expect(
      camera.yaw,
      lessThan(1.0),
      reason: '往右拖 ⇒ 偏航减少；数值不要求精确，pan 的步长由框架决定',
    );
    expect(camera.autoSpin, isFalse);
  });

  testWidgets('TC-SPIKE-036 手势层把滚轮落到相机上（ADR-0006 决策一·球心相机）', (
    WidgetTester tester,
  ) async {
    final SkyCamera camera = SkyCamera();
    int changes = 0;

    await tester.pumpWidget(
      SkyGestureLayer(
        camera: camera,
        onChanged: () => changes++,
        child: const SizedBox(width: 200, height: 200),
      ),
    );

    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    final ui.Offset center = tester.getCenter(find.byType(SizedBox));
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const ui.Offset(0, 100)));
    await tester.pump();

    expect(changes, greaterThan(0), reason: '滚轮要通知上层重绘');
    expect(camera.fovDeg, lessThan(70), reason: '往上滚 = 放大');
  });
}
