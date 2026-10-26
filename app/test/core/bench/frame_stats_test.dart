import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/bench/frame_stats.dart';
import 'package:project_knowledge/core/constants.dart';

/// 帧时序统计的口径（`C-32`）。
///
/// 夹具是**合成的时序**，不是真机读数 —— 真机读数只在终端产生（`STP` §八.1），
/// 这里守的是「拿到时序之后怎么算」。两边分工与本仓对 Planner 那条同源：
/// 算法错了必须能在离线变红，否则装置每次都要上真机才能验一个除法。
///
/// ⚠️ **`046` 的夹具是刻意造的**：中位与平均在它上面给出不同的 fps。若把
/// `medianFps` 写成「逐帧 fps 的平均」或「平均间隔的倒数」，只有这一条会红 ——
/// 其余各条的夹具是等距的，两种写法给出同一个数（`R-08` 同族：断言必须落在两条
/// 实现路径的差集上）。
void main() {
  /// 一串等距帧：`frames` 帧、间隔 `gapUs`、光栅固定 `rasterUs`。
  FrameStats uniform({
    required int frames,
    required int gapUs,
    int rasterUs = 0,
    int startUs = 0,
    int capacity = frameStatsWindowCapacity,
  }) {
    final FrameStats stats = FrameStats(capacity: capacity);
    for (int i = 0; i < frames; i++) {
      stats.add(FrameSample(vsyncUs: startUs + i * gapUs, rasterUs: rasterUs));
    }
    return stats;
  }

  test('TC-INF-043 不足下限不出快照，不拿两帧编一个 fps（`C-32`）', () {
    final FrameStats stats = uniform(frames: 2, gapUs: 16667, rasterUs: 4000);
    expect(stats.intervals, 1);
    expect(stats.snapshot(), isNull);

    // 恰好到下限就出 —— 边界两侧各判一次，否则「总是 null」也能过。
    final FrameStats enough = uniform(
      frames: frameStatsMinIntervals + 1,
      gapUs: 16667,
      rasterUs: 4000,
    );
    expect(enough.snapshot(), isNotNull);
  });

  test('TC-INF-044 稳定 16 667 µs ⇒ 中位 16.667 ms、60 fps、光栅 p95 4 ms（`C-32`）', () {
    final FrameSnapshot snapshot =
        uniform(frames: 26, gapUs: 16667, rasterUs: 4000).snapshot()!;
    expect(snapshot.intervals, 25);
    expect(snapshot.medianIntervalMs, closeTo(16.667, 0.001));
    expect(snapshot.medianFps, closeTo(60, 0.01));
    expect(snapshot.frameP95Ms, closeTo(16.667, 0.001));
    expect(snapshot.rasterP95Ms, closeTo(4, 0.001));
    expect(snapshot.meetsTarget, isTrue);
    expect(snapshot.meetsGood, isTrue);
  });

  test('TC-INF-045 掉帧拉高 p95 但不改中位 fps，两个指标缺一不可（`C-32`）', () {
    // 25 帧里 5 个间隔是 50 ms，其余 19 个 16 667 µs。
    final FrameStats stats = FrameStats();
    int now = 0;
    for (int i = 0; i < 25; i++) {
      stats.add(FrameSample(vsyncUs: now, rasterUs: 4000));
      now += i < 5 ? 50000 : 16667;
    }
    final FrameSnapshot snapshot = stats.snapshot()!;
    expect(snapshot.medianFps, closeTo(60, 0.01));
    expect(snapshot.frameP95Ms, closeTo(50, 0.001));
  });

  test('TC-INF-046 中位取中位间隔的倒数，不取逐帧 fps 的平均（`C-32`）', () {
    // 100 帧 10 ms 一节 + 20 帧 50 ms 一节。中位间隔 10 ms ⇒ 100 fps；
    // 平均间隔 16.72 ms ⇒ 60 fps。两种写法在这组样上差 40 fps。
    final FrameStats stats = FrameStats();
    int now = 0;
    for (int i = 0; i < 100; i++) {
      stats.add(FrameSample(vsyncUs: now, rasterUs: 1000));
      now += 10000;
    }
    for (int i = 0; i < 20; i++) {
      stats.add(FrameSample(vsyncUs: now, rasterUs: 1000));
      now += 50000;
    }
    final FrameSnapshot snapshot = stats.snapshot()!;
    expect(snapshot.medianIntervalMs, closeTo(10, 0.001));
    expect(snapshot.medianFps, closeTo(100, 0.01));
  });

  test('TC-INF-047 低于 30 fps 判不过（`C-32`）', () {
    final FrameSnapshot snapshot = uniform(frames: 25, gapUs: 40000).snapshot()!;
    expect(snapshot.medianFps, closeTo(25, 0.01));
    expect(snapshot.meetsTarget, isFalse);
    expect(snapshot.meetsGood, isFalse);
  });

  test('TC-INF-048 光栅占预算的分母是中位帧间隔（`C-32`）', () {
    final FrameSnapshot snapshot =
        uniform(frames: 26, gapUs: 16667, rasterUs: 4000).snapshot()!;
    // 4 ms / 16.667 ms ≈ 0.24，与 `STR` 轮次 `R1` 那张表的算法同口径。
    expect(snapshot.rasterBudgetShare, closeTo(0.24, 0.001));
    expect(snapshot.rasterBudgetShare, closeTo(
      snapshot.rasterP95Ms / snapshot.medianIntervalMs,
      1e-9,
    ));
  });

  test('TC-INF-049 只有基准窗口才算数（`C-33`）', () {
    expect(framePremiseOk(width: 1920, height: 1080), isTrue);
    // 容差之内（浮点折算出来的 1919.6 之类）仍算基准窗口。
    expect(framePremiseOk(width: 1920.4, height: 1079.6), isTrue);
    // 宽正好、高不对 —— `R1` 那次对照放大的那个窗口（`1920×1109`）。这一条是
    // **故意只差一个维度**：两个维度一起差时，只判宽的实现照样全绿（本节首版
    // 就栽在这里，反证删掉判高的那半，9 条全绿）。
    expect(framePremiseOk(width: 1920, height: 1109), isFalse);
    // `R1` 那次对照的起始窗口：面积是它的 1.55 倍时读数从「余量 57%」变成「占预算 88%」。
    expect(framePremiseOk(width: 1584, height: 875), isFalse);
    // 只差 2 px 也要判不是 —— 容差是 1 px，不是「差不多」。
    expect(framePremiseOk(width: 1922, height: 1080), isFalse);
  });

  test('TC-INF-051 reset 之后回到无样本，热身帧不进读数（`C-32`）', () {
    final FrameStats stats = uniform(frames: 40, gapUs: 16667, rasterUs: 4000);
    expect(stats.snapshot(), isNotNull);
    stats.reset();
    expect(stats.intervals, 0);
    expect(stats.snapshot(), isNull);
  });

  test('TC-INF-052 滚动窗口有上界（无 SPEC：内存上界属实现约束，容量见 `C-32`）', () {
    final FrameStats stats =
        uniform(frames: 70, gapUs: 16667, capacity: 30);
    expect(stats.intervals, 30);
    expect(stats.snapshot()!.intervals, 30);
  });
}
