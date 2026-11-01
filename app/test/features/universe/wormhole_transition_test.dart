/// 虫洞过渡的用例（`B17b` 笔 7）。
///
/// 守三件事：**相机走的是大圆最短弧**、**点层全程有亮度下界**（`ADR-0006:100`
/// 的「中途不出现空白帧」在这里落成一条可算的断言）、**换地址只发生一帧**。
///
/// 真机才判的是：转向的观感（0.55 s 够不够跟得上）、换片那一下有没有一闪、
/// 以及 `PopScope` 带回来的地址树屏认不认。前者是观感，后两者要真的构建
/// `UniverseScreen` —— 它一构建就要 `gpuContext()`，widget 测试里起不来。
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/features/universe/presentation/sky_image.dart';
import 'package:project_knowledge/features/universe/presentation/wormhole_transition.dart';

/// 与 `SkyCamera.direction` 同一算法，用来造已知姿态。
Vec3 _direction(double yawDeg, double pitchDeg) {
  final double yaw = yawDeg * math.pi / 180;
  final double pitch = pitchDeg * math.pi / 180;
  final double cosPitch = math.cos(pitch);
  return Vec3(
    math.sin(yaw) * cosPitch,
    math.sin(pitch),
    math.cos(yaw) * cosPitch,
  );
}

double _angleBetweenDeg(Vec3 a, Vec3 b) {
  final double dot = (a.x * b.x + a.y * b.y + a.z * b.z).clamp(-1.0, 1.0);
  return math.acos(dot) * 180 / math.pi;
}

/// 一帧的步长：60 fps。
const double _frame = 1 / 60;

void main() {
  test('TC-UNIVERSE-041 方向反解姿态与相机算法互逆（ADR-0006 修订十八）', () {
    for (final List<double> pose in <List<double>>[
      <double>[0, 0],
      <double>[37, -21],
      <double>[-152, 48],
      <double>[180, 0],
    ]) {
      final SkyPose back = poseOfDirection(_direction(pose[0], pose[1]));
      // 180° 与 -180° 是同一个方向，所以 yaw 只比较方向是否复原。
      final Vec3 restored = _direction(back.yawDeg, back.pitchDeg);
      expect(
        _angleBetweenDeg(restored, _direction(pose[0], pose[1])),
        lessThan(1e-6),
        reason: '反解出来的姿态要指回原方向，否则相机转到一半会偏',
      );
      expect(back.pitchDeg, closeTo(pose[1], 1e-6));
    }
  });

  test('TC-UNIVERSE-042 插值走的是大圆：中点与两端夹角相等（ADR-0006 修订十八）', () {
    // 起终点不在同一纬度，直线插值（yaw / pitch 各走各的）走的是「纬线」，
    // 中点与两端的夹角会不相等；大圆的两个夹角各自等于总夹角的一半。
    final Vec3 from = _direction(0, 0);
    final Vec3 to = _direction(90, 40);
    final Vec3 mid = slerpDirection(from, to, 0.5);
    final double total = _angleBetweenDeg(from, to);
    expect(_angleBetweenDeg(from, mid), closeTo(total / 2, 1e-6));
    expect(_angleBetweenDeg(mid, to), closeTo(total / 2, 1e-6));
    // 中点必须仍是单位向量 —— 归一化丢了，投影会把点推到屏幕外。
    final double length = math.sqrt(
      mid.x * mid.x + mid.y * mid.y + mid.z * mid.z,
    );
    expect(length, closeTo(1, 1e-9));
  });

  test('TC-UNIVERSE-043 两端几乎重合时不产生 NaN（点中正前方的点，ADR-0006 修订十八）', () {
    // 点中正前方的子级时 from ≈ to，`sin θ` 趋近 0 —— 不特判就会除出随机方向。
    final Vec3 from = _direction(30, 10);
    final Vec3 to = _direction(30, 10);
    final Vec3 mid = slerpDirection(from, to, 0.5);
    expect(mid.x.isNaN, isFalse);
    expect(mid.y.isNaN, isFalse);
    expect(mid.z.isNaN, isFalse);
    expect(_angleBetweenDeg(mid, to), lessThan(1e-6));
  });

  test('TC-UNIVERSE-044 转向阶段方向单调逼近目标，到站即等于目标（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(120, -30),
    );
    double previous = _angleBetweenDeg(transition.direction, transition.to);
    // 分 30 步走完转向段。
    const double step = universeWormholeTurnSeconds / 30;
    while (!transition.hasArrived) {
      transition.advance(step);
      final double remaining = _angleBetweenDeg(
        transition.direction,
        transition.to,
      );
      expect(
        remaining,
        lessThanOrEqualTo(previous + 1e-9),
        reason: '每一步都要更接近目标，中途回头说明插值方向反了',
      );
      previous = remaining;
    }
    expect(previous, lessThan(1e-6));
    expect(
      transition.phase,
      WormholePhase.fading,
      reason: '到站那一刻才进入淡入段，两段不能重叠',
    );
  });

  test('TC-UNIVERSE-045 换地址的信号只在到达那一帧给出一次（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(45, 10),
    );
    int arrivals = 0;
    // 走满两段 + 多给 10 帧，确认不会重复给信号。
    for (int i = 0; i < 10 + (0.8 / _frame).ceil(); i++) {
      if (transition.advance(_frame)) {
        arrivals++;
      }
    }
    expect(arrivals, 1, reason: '上层按这个信号换地址，给两次就会连着换两片天');
    expect(transition.isDone, isTrue);
  });

  test('TC-UNIVERSE-046 点层不透明度全程不低于下界（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(170, -45),
    );
    double lowest = 1;
    for (int i = 0; i < 300 && !transition.isDone; i++) {
      transition.advance(_frame);
      lowest = math.min(lowest, transition.nodeOpacity);
    }
    expect(
      lowest,
      greaterThanOrEqualTo(universeWormholeFadeFrom - 1e-9),
      reason:
          '下界就是这条判据的落地点：任何一帧都不能掉到 0，'
          '否则观感上就是「点全没了」',
    );
    expect(
      lowest,
      closeTo(universeWormholeFadeFrom, 1e-6),
      reason: '下界要真的被用到 —— 若从没接近过它，说明渐暗白写了',
    );
  });

  test('TC-UNIVERSE-047 淡入段把不透明度还回满值（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(45, 0),
    );
    while (!transition.hasArrived) {
      transition.advance(_frame);
    }
    expect(
      transition.nodeOpacity,
      closeTo(universeWormholeFadeFrom, 1e-6),
      reason: '到站瞬间接的是最暗值，之后才往上走 —— 不能在这里跳回 1',
    );
    double previous = transition.nodeOpacity;
    while (!transition.isDone) {
      transition.advance(_frame);
      final double current = transition.nodeOpacity;
      expect(current, greaterThanOrEqualTo(previous - 1e-9));
      previous = current;
    }
    expect(previous, closeTo(1, 1e-6));
  });

  test('TC-UNIVERSE-048 走完之后再推进不改变任何状态（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(30, 30),
    );
    for (int i = 0; i < 200; i++) {
      transition.advance(_frame);
    }
    final Vec3 direction = transition.direction;
    final double opacity = transition.nodeOpacity;
    expect(transition.advance(1), isFalse);
    expect(_angleBetweenDeg(transition.direction, direction), lessThan(1e-9));
    expect(transition.nodeOpacity, opacity);
    expect(transition.phase, WormholePhase.idle);
  });

  test('TC-UNIVERSE-049 零或负的 dt 不推进，首帧与卡顿时不倒退（ADR-0006 修订十八）', () {
    final WormholeTransition transition = WormholeTransition(
      from: _direction(0, 0),
      to: _direction(60, 0),
    );
    transition.advance(_frame);
    final Vec3 before = transition.direction;
    transition.advance(0);
    transition.advance(-1);
    expect(_angleBetweenDeg(transition.direction, before), lessThan(1e-9));
    expect(transition.hasArrived, isFalse);
  });
}
