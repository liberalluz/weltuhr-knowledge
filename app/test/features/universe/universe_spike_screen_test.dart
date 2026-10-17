/// spike 页能不能起来 —— 这一条只证明「不崩」。
///
/// 它守的东西很少但很关键：`FramePainter.paint` 会在真实尺寸下跑完整的一套
/// 投影 + 300 多次绘制调用，`_select` 会换场景并重置统计窗口。这两条路径
/// 只要有一条抛异常，终端上的 `flutter run --profile` 就白跑一次 ——
/// 而在沙箱里跑不了 `flutter run`，所以只能靠 widget test 兜住。
///
/// **不在这里断言 fps**：headless 测试环境不产 `FrameTiming`，
/// 帧率只在真设备上有意义（`C-32` 的判据归终端实测）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/features/universe/universe_spike_screen.dart';

void main() {
  testWidgets('spike 页渲染不崩，三档切换可用（ADR-0002）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UniverseSpikeScreen()));
    await tester.pump(const Duration(milliseconds: 32));

    // 三个档位都在（顺序：合成 ×1 → 合成 ×2 → 真实 α 包）。
    expect(find.textContaining('合成 ×1'), findsOneWidget);
    expect(find.textContaining('合成 ×2'), findsOneWidget);
    expect(find.textContaining('真实 α 包'), findsOneWidget);

    // 切到 ×2：走合成，不触盘 —— 300 项 / 334 边的绘制路径也被跑过一遍。
    await tester.tap(find.textContaining('合成 ×2'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.takeException(), isNull);

    // 收尾：让 State 走 dispose（停 ticker、注销 timings 回调）。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('HUD 在没有帧时序时显示采样中，而不是编一个数（C-32）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UniverseSpikeScreen()));
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.textContaining('采样中'), findsOneWidget);
    // 没有样本就不出判据 —— 不许拿「0 帧」算出一个好看的 fps。
    expect(find.textContaining('需回写 adr/0002'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
