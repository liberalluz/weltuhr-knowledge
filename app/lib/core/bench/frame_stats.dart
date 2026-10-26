/// 帧时序统计：`C-32` 的三项读数**怎么算**（`R-22` 的算法那一半）。
///
/// ## 只算，不采
///
/// 本文件不认识 `dart:ui`，也不认识 `FrameTiming` —— 它收的是「一帧的两段耗时」
/// 这个形状。理由有两条：`lib/core/**` 不许 import Flutter（`R1`）；更要紧的是
/// **采集要真机、算法要能离线验**。混在一个文件里，算法就只能靠「跑起来看数字
/// 像不像」验证，而那种验证在读数错的时候也是绿的。
///
/// 采集侧在 `tool/bench/`：那里把 `FrameTiming` 喂成 [FrameSample]。
///
/// ## 三项读数缺一项都会误判（`STP` §八）
///
/// 中位 fps 承载稳态、p95 帧间隔承载卡顿、光栅 p95 占预算承载「距阈值多远」。
/// 只报 fps 会把「一直 45」与「60 但每 5 帧掉一次」判成同一件事；只报「是否
/// ≥ 50」会把余量 57% 与占预算 88% 都记成通过。
///
/// ## 「占预算」的分母是**中位帧间隔**
///
/// 与 `STR` 轮次 `R1` 那张表同口径（该表原文写的正是「光栅 p95 ÷ 中位帧间隔」）。
/// 不改成 `1000 / frameTargetFps`：换了分母，新读数与 `R1` 就不可比，而 `R-22`
/// 要的正是「同一口径能重跑」。⚠️ 这个分母是自指的 —— 帧变慢时中位间隔一起变大，
/// 占比反而下降，故本项**必须**与中位 fps 并读，不能单独作为「有余量」的证据。
library;

import '../constants.dart';

/// 一帧的两段耗时（微秒）。
///
/// [vsyncUs] 是这一帧的起始时刻（判定间隔用），[rasterUs] 是光栅线程耗时。
/// 不设 `buildUs`：三项读数里没有一项读它，而多一个没人读的字段只会让人以为
/// 它参与计算。
class FrameSample {
  const FrameSample({required this.vsyncUs, required this.rasterUs});

  final int vsyncUs;

  /// 光栅耗时（微秒）。
  final int rasterUs;

  @override
  String toString() => 'FrameSample(vsync=$vsyncUs, raster=$rasterUs)';
}

/// 一次快照：三项读数 + 样本量。
class FrameSnapshot {
  const FrameSnapshot({
    required this.intervals,
    required this.medianIntervalMs,
    required this.medianFps,
    required this.frameP95Ms,
    required this.rasterP95Ms,
    required this.rasterBudgetShare,
  });

  /// 参与计算的帧间隔数。
  final int intervals;

  /// 中位帧间隔（ms）。三项读数里的第二项与第三项都以它为分母。
  final double medianIntervalMs;

  /// 中位 fps —— 中位帧间隔的倒数，不是逐帧 fps 的平均（见 [FrameStats]）。
  final double medianFps;

  /// p95 帧间隔（ms）：卡顿线。
  final double frameP95Ms;

  /// 光栅耗时 p95（ms）。
  final double rasterP95Ms;

  /// 光栅 p95 占中位帧间隔的比例（`R1` 口径）。
  final double rasterBudgetShare;

  /// 是否达到 `C-32` 达标线。
  bool get meetsTarget => medianFps >= frameTargetFps;

  /// 是否达到 `C-32` 优线。
  bool get meetsGood => medianFps >= frameGoodFps;

  @override
  String toString() => 'FrameSnapshot(intervals=$intervals, '
      'medianMs=$medianIntervalMs, fps=$medianFps, p95Ms=$frameP95Ms, '
      'rasterP95Ms=$rasterP95Ms, share=$rasterBudgetShare)';
}

/// 滚动窗口的帧统计。
///
/// ## 为什么中位 fps 取「中位间隔的倒数」而不取「逐帧 fps 的中位」
///
/// 两者的差别不在数学而在**能读到什么**：一帧 50 ms 之后跟着一帧 8 ms，逐帧 fps
/// 是 20 与 125，中位往外一挑就跳档；而中位间隔 29 ms 只说明「这段时间的典型
/// 节奏」。`STP` §八 的口径写的是「中位 fps」对「p95 帧间隔」，前者是稳态、后者
/// 是卡顿 —— 把稳态也算成逐帧 fps 的中位，两者会互相污染。
///
/// ## 样本不足就不出快照
///
/// 少于 [frameStatsMinIntervals] 个间隔一律返回 `null`。这不是「保守」，是
/// 「读数会被引用」：一个 n=2 的 fps 一旦进了报告，读的人看不出样本量。
class FrameStats {
  FrameStats({this.capacity = frameStatsWindowCapacity});

  /// 保留的最多帧数。
  final int capacity;

  final List<int> _intervalsUs = <int>[];
  final List<int> _rasterUs = <int>[];
  int? _prevVsyncUs;

  /// 当前参与统计的帧间隔数。
  int get intervals => _intervalsUs.length;

  /// 加一帧。
  ///
  /// 非正间隔（时钟回拨、重复回调、同一微秒两帧）整帧丢弃：它算不出 fps，
  /// 混进排序里还会把中位往下拽。
  void add(FrameSample sample) {
    final int? prev = _prevVsyncUs;
    _prevVsyncUs = sample.vsyncUs;
    if (prev != null) {
      final int delta = sample.vsyncUs - prev;
      if (delta <= 0) {
        return;
      }
      _intervalsUs.add(delta);
      if (_intervalsUs.length > capacity) {
        _intervalsUs.removeAt(0);
      }
    }
    _rasterUs.add(sample.rasterUs);
    if (_rasterUs.length > capacity) {
      _rasterUs.removeAt(0);
    }
  }

  /// 清空 —— 装置侧在热身结束时调用，让热身帧不进读数。
  void reset() {
    _intervalsUs.clear();
    _rasterUs.clear();
    _prevVsyncUs = null;
  }

  /// 出快照；样本不足返回 `null`。
  FrameSnapshot? snapshot() {
    if (_intervalsUs.length < frameStatsMinIntervals) {
      return null;
    }
    final double medianUs = _percentile(_intervalsUs, frameMedianFraction);
    final double frameP95Us = _percentile(_intervalsUs, frameP95Fraction);
    final double rasterP95Us = _percentile(_rasterUs, frameP95Fraction);
    final double microsPerMs = Duration.microsecondsPerMillisecond.toDouble();
    final double medianMs = medianUs / microsPerMs;
    final double rasterP95Ms = rasterP95Us / microsPerMs;
    return FrameSnapshot(
      intervals: _intervalsUs.length,
      medianIntervalMs: medianMs,
      medianFps: Duration.microsecondsPerSecond / medianUs,
      frameP95Ms: frameP95Us / microsPerMs,
      rasterP95Ms: rasterP95Ms,
      rasterBudgetShare: rasterP95Ms / medianMs,
    );
  }

  /// 最近秩分位：口径写在 `STP` §八，值来自常量表。
  static double _percentile(List<int> values, double fraction) {
    final List<int> sorted = List<int>.of(values)..sort();
    final int rank = (fraction * sorted.length).ceil() - 1;
    final int index = rank < 0
        ? 0
        : (rank >= sorted.length ? sorted.length - 1 : rank);
    return sorted[index].toDouble();
  }
}

/// 这个视口是不是 `C-33` 的基准窗口（**物理像素**，容差 [frameBenchWindowTolerance]）。
///
/// **读数必须在基准窗口下取**：光栅成本随覆盖面积走（`R1` 的受控对照：面积
/// 1.55 倍 ⇒ 光栅 2.02 倍），同一个数在 1584×875 上读出来是「余量 57%」，在基准
/// 窗口上是「占预算 88%」。故装置先问这一句，答「不是」就把读数标成不可解释，
/// 而不是照样按 30 / 50 去判。
///
/// ⚠️ **参数按名字写成 `physicalWidth` / `physicalHeight`，是因为单位错了不会有
/// 任何东西变红**：`C-33` 与 `ADR-0002` 修订三都指物理面积，而 `MediaQuery` 给的
/// 是逻辑像素。两者在 100% 缩放下恰好相等，于是「传错了单位」这个缺陷在 100%
/// 缩放的机器上永远看不见 —— 到 125% 缩放的机器上，逻辑宽 `1536` 永远够不到基准
/// `1920`，装置只会安静地等到超时。名字带 `physical`，误传的那一行就得自己写出
/// `physicalWidth: 逻辑值`，读代码的人一眼能看见。
bool framePremiseOk({
  required double physicalWidth,
  required double physicalHeight,
}) {
  final double dw = (physicalWidth - frameBenchWidth).abs();
  final double dh = (physicalHeight - frameBenchHeight).abs();
  return dw <= frameBenchWindowTolerance &&
      dh <= frameBenchWindowTolerance;
}
