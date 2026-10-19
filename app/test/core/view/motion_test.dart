/// 运动时钟与减速停转的单元测试（`C-54` / `C-56` / `C-57` · `V-1i`）。
///
/// 三个函数都是纯函数，所以「转多快、什么时候停、相位连不连续」全部可算 ——
/// 这一笔不需要靠肉眼判断任何一条。
///
/// ⚠️ 这里**不测帧率**：`C-32` 只认真设备产生的 `FrameTiming`（`STP` §八），
/// 在 headless 里断言 fps 等于造一台跑不起来的机器。
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/view/motion.dart';

void main() {
  group('相位（C-54 / C-56）', () {
    test('相位是一个周期的分数：6 s 走完 24 s 的四分之一（C-54）', () {
      expect(orbitPhase(0, 24), 0);
      expect(orbitPhase(6, 24), closeTo(0.25, 1e-12));
      expect(orbitPhase(12, 24), closeTo(0.5, 1e-12));
      expect(orbitPhase(18, 24), closeTo(0.75, 1e-12));
    });

    test('走满一个周期回到原点，而不是停在 1.0（C-54）', () {
      // `1.0` 与 `0.0` 在画面上一样，在断言里不一样 —— 停在 1.0 会让
      // 「t=0 与 t=T 整帧相同」这条判据永远差一个浮点误差。
      expect(orbitPhase(24, 24), 0);
      expect(orbitPhase(48, 24), 0);
    });

    test('周期不必是整数倍关系：8 s 与 72 s 各算各的（C-56 / C-55）', () {
      // 这一条是「时钟不能取控制器进度」的理由本身：两个周期不整除，
      // 取 0→1 的进度就会在归零那一帧跳位。
      expect(orbitPhase(72, 8), closeTo(0, 1e-12));
      expect(orbitPhase(76, 8), closeTo(0.5, 1e-12));
      expect(orbitPhase(72, 72), closeTo(0, 1e-12));
    });

    test('跨过周期边界时相位连续 —— 不跳（C-54）', () {
      // 相位是环上的量：`0.9999` 与 `0.0001` 在屏幕上只差一小步。所以比的是
      // **环上的距离**，不是差值的绝对值（后者在边界处永远接近 1）。
      final double before = orbitPhase(23.999, 24);
      final double after = orbitPhase(24.001, 24);
      final double raw = (after - before).abs();
      final double gap = raw > 0.5 ? 1 - raw : raw;
      expect(gap < 1e-3, isTrue, reason: '边界处相位应连续，实际差 $gap');
    });

    test('时钟为负也折回正区间 —— 重启 ticker 那一帧不会算出负相位（C-57）', () {
      // `Ticker` 重启后 `elapsed` 从零重计，差值可能是负的。`advanceClock`
      // 会挡掉它，这里再保一层：即便漏进来，相位也有定义。
      final double phase = orbitPhase(-0.24, 24);
      expect(phase, closeTo(0.99, 1e-12));
    });

    test('周期为 0 或负数直接抛 —— 静默取 0 会让画面从此不动（C-54）', () {
      expect(() => orbitPhase(1, 0), throwsArgumentError);
      expect(() => orbitPhase(1, -24), throwsArgumentError);
      expect(() => orbitPhase(1, double.infinity), throwsArgumentError);
    });

    test('旋转角 = 相位 × 2π（C-54）', () {
      expect(spunRadians(6, 24), closeTo(math.pi / 2, 1e-12));
      expect(spunRadians(24, 24), closeTo(0, 1e-12));
      expect(spunRadians(12, 24), closeTo(math.pi, 1e-12));
    });
  });

  group('减速停转（C-57）', () {
    test('三档：贴住不动、中间线性、远处常速（C-57）', () {
      expect(governorFactor(distance: 0, stopRadius: 24, slowRadius: 60), 0);
      expect(governorFactor(distance: 24, stopRadius: 24, slowRadius: 60), 0);
      expect(
        governorFactor(distance: 42, stopRadius: 24, slowRadius: 60),
        closeTo(0.5, 1e-12),
      );
      expect(governorFactor(distance: 60, stopRadius: 24, slowRadius: 60), 1);
      expect(governorFactor(distance: 300, stopRadius: 24, slowRadius: 60), 1);
    });

    test('系数随距离单调不减 —— 反了就是「越近越快」，点不中（C-57）', () {
      // 单调性是收敛性的前提：物体靠近 ⇒ 慢下来 ⇒ 更靠不近 ⇒ 停在阈值外，
      // 不会来回振荡。阈值写反时这一条先红。
      double previous = -1;
      for (int d = 0; d <= 100; d++) {
        final double f = governorFactor(
          distance: d.toDouble(),
          stopRadius: 24,
          slowRadius: 60,
        );
        expect(f >= previous, isTrue, reason: '距离 $d 处系数反而变小了');
        previous = f;
      }
    });

    test('两个阈值写反或相等直接抛 —— 否则减速区间消失而无人报错（C-57）', () {
      expect(
        () => governorFactor(distance: 1, stopRadius: 60, slowRadius: 24),
        throwsArgumentError,
      );
      expect(
        () => governorFactor(distance: 1, stopRadius: 24, slowRadius: 24),
        throwsArgumentError,
      );
    });

    test('算不出距离（NaN）时按常速 —— 「不知道」不该读成「停住」（C-57）', () {
      expect(governorFactor(distance: double.nan, stopRadius: 24, slowRadius: 60), 1);
    });

    test('常量与规格一致：停 24、慢 60（C-57）', () {
      expect(governorStopRadiusPx, 24);
      expect(governorSlowRadiusPx, 60);
      expect(spinPeriodSeconds, 24);
    });
  });

  group('累计时钟（C-54 / C-55）', () {
    test('常速时按 dt 累加（C-54）', () {
      expect(advanceClock(10, 0.5, 1), closeTo(10.5, 1e-12));
    });

    test('停转不改时钟 —— 恢复时相位不跳（C-57）', () {
      // 速率乘在相位上就会在这里丢一段时间：抬起指针那一下画面往前蹿。
      expect(advanceClock(10, 0.5, 0), 10);
    });

    test('dt 为负或非有限一律丢弃 —— ticker 重启后第一帧不会倒转（C-57）', () {
      expect(advanceClock(10, -0.5, 1), 10);
      expect(advanceClock(10, double.nan, 1), 10);
      expect(advanceClock(10, double.infinity, 1), 10);
    });

    test('系数大于 1 被夹住 —— 算错了表现为速度不对，而不是时钟飞走（C-57）', () {
      expect(advanceClock(10, 1, 4), closeTo(11, 1e-12));
    });

    test('时钟只增：一千帧之后也不回卷（C-55）', () {
      // 这正是「不用 controller.value」的判据：`repeat()` 到点归零，
      // 而这里跑一千帧仍然是单调的。
      double clock = 0;
      for (int i = 0; i < 1000; i++) {
        final double next = advanceClock(clock, 1 / 60, 1);
        expect(next >= clock, isTrue);
        clock = next;
      }
      expect(clock, closeTo(1000 / 60, 1e-9));
    });
  });
}
