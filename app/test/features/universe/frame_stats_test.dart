/// 帧率判据的算法侧 —— fps 怎么算、p95 怎么取，得被断言住。
///
/// 这一笔的结论是「过 / 不过 `C-32`」，而判据本身若算错，所有读数都作废。
/// 尤其「中位 fps」与「p95 帧间隔」的分工：前者说稳态、后者说卡顿，
/// 混成一个数就会把「一直 45 fps」和「60 fps 但每 5 帧掉一次」判成同一件事。
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/features/universe/frame_stats.dart';

/// 一帧的时间片。默认 build 1 ms / raster 4 ms，间隔由相邻 `vsyncStart` 决定。
FrameTiming _frame(int vsyncUs, {int buildUs = 1000, int rasterUs = 4000}) {
  return FrameTiming(
    vsyncStart: vsyncUs,
    buildStart: vsyncUs + 50,
    buildFinish: vsyncUs + 50 + buildUs,
    rasterStart: vsyncUs + 100 + buildUs,
    rasterFinish: vsyncUs + 100 + buildUs + rasterUs,
    rasterFinishWallTime: vsyncUs + 100 + buildUs + rasterUs,
  );
}

/// 按固定间隔造 [count] 帧。
List<FrameTiming> _steady(int count, int intervalUs) {
  return <FrameTiming>[for (int i = 0; i < count; i++) _frame(i * intervalUs)];
}

void main() {
  test('样本不足时不出快照（C-32）', () {
    final FrameRateMonitor monitor = FrameRateMonitor();
    expect(monitor.snapshot(), isNull);

    monitor.add(<FrameTiming>[_frame(0), _frame(16667)]);
    expect(monitor.snapshot(), isNull, reason: '2 个间隔算不出帧率');
  });

  test('16.667 ms 稳定间隔 ⇒ 60 fps，UI 1 ms / 光栅 4 ms（C-32）', () {
    final FrameRateMonitor monitor = FrameRateMonitor();
    monitor.add(_steady(25, 16667));

    final FrameRateSnapshot snapshot = monitor.snapshot()!;
    expect(snapshot.fps, closeTo(60, 0.5));
    expect(snapshot.frameP50Ms, closeTo(16.667, 0.01));
    expect(snapshot.frameP95Ms, closeTo(16.667, 0.01));
    expect(snapshot.buildP95Ms, closeTo(1, 0.01));
    expect(snapshot.rasterP95Ms, closeTo(4, 0.01));
    expect(snapshot.meetsGood, isTrue);
    expect(snapshot.meetsTarget, isTrue);
  });

  test('掉帧拉高 p95 但不改变中位 fps —— 两个指标缺一不可（C-32）', () {
    final FrameRateMonitor monitor = FrameRateMonitor();
    final List<FrameTiming> timings = <FrameTiming>[];
    int vsync = 0;
    // 24 个间隔里 5 个是 50 ms（掉到 20 fps 的卡顿），其余 16.667 ms。
    for (int i = 0; i < 25; i++) {
      timings.add(_frame(vsync));
      vsync += i >= 15 && i < 20 ? 50000 : 16667;
    }
    monitor.add(timings);

    final FrameRateSnapshot snapshot = monitor.snapshot()!;
    expect(snapshot.fps, closeTo(60, 1), reason: '中位数仍在 16.667');
    expect(snapshot.frameP95Ms, closeTo(50, 0.01), reason: 'p95 必须看见那 5 次卡顿');
    expect(snapshot.meetsTarget, isTrue);
  });

  test('低于 30 fps 判不过（C-32）', () {
    final FrameRateMonitor monitor = FrameRateMonitor();
    // 40 ms 间隔 ⇒ 25 fps。
    monitor.add(_steady(25, 40000));

    final FrameRateSnapshot snapshot = monitor.snapshot()!;
    expect(snapshot.fps, closeTo(25, 0.5));
    expect(snapshot.meetsTarget, isFalse);
    expect(snapshot.meetsGood, isFalse);
  });

  test('reset 后回到无样本状态（C-32）', () {
    final FrameRateMonitor monitor = FrameRateMonitor();
    monitor.add(_steady(25, 16667));
    expect(monitor.snapshot(), isNotNull);

    monitor.reset();
    expect(monitor.snapshot(), isNull);
  });

  test('滚动窗口只保留最近 capacity 个间隔（无 SPEC：内存上界属实现约束）', () {
    final FrameRateMonitor monitor = FrameRateMonitor(capacity: 30);
    monitor.add(_steady(200, 16667));

    final FrameRateSnapshot snapshot = monitor.snapshot()!;
    expect(snapshot.samples, 30);
  });
}
