/// 帧时间统计。
///
/// spike 的全部结论都建立在这两个数上（`ADR-0006` §3），所以它不夹在渲染
/// 代码里，单独成文件、单独测 —— 算错了读数就整份作废，而读数错了看表面
/// 是看不出来的。
library;

/// 分位口径：**最近秩法**（nearest-rank）。
///
/// 取排序后第 `ceil(p × n)` 个样本（1 起数），即下标 `ceil(p × n) − 1`。
/// 偶数样本取 `p = 0.5` 时落在**下中位**（`n = 4` 取第 2 个），这是刻意
/// 选的：插值会造出一个样本里根本不存在的帧时间，而「至少一半样本不慢于
/// 这个值」这句话能直接对着原始数据核。
///
/// 空列表给 `0`，由调用方按「没采到样本」处理，不在这里抛。
double percentileMs(List<double> frameMs, double p) {
  if (frameMs.isEmpty) {
    return 0;
  }
  assert(p > 0 && p <= 1, 'p 取 (0, 1]');
  final List<double> sorted = <double>[...frameMs]..sort();
  final int rank = (p * sorted.length).ceil();
  final int index = (rank - 1).clamp(0, sorted.length - 1);
  return sorted[index];
}

/// 一次采集的读数。
class FrameStats {
  const FrameStats({
    required this.samples,
    required this.p50Ms,
    required this.p95Ms,
  });

  /// 参与统计的帧数。
  final int samples;

  /// 中位帧时间，毫秒。
  final double p50Ms;

  /// 95 分位帧时间，毫秒。
  final double p95Ms;

  /// 中位帧时间换成的帧率。`ADR-0006` §3 写的「P50 ≥ 30 fps」就是它。
  ///
  /// 只用于显示。**判闸不走它** —— 见 [passesGate] 的注释。
  double get p50Fps => p50Ms <= 0 ? 0 : 1000 / p50Ms;

  /// 两条阈值同时成立才算过闸：`P50 ≥ 30 fps` 且 `P95 帧时间 ≤ 50 ms`。
  ///
  /// 帧率那条**直接比帧时间**，不做「先换算成 fps 再比 30」。两者数学等价，
  /// 但 `1000 / (1000 / 30)` 在浮点下可能落在 `29.999999999999996`，让一个
  /// 恰好压线的读数翻成不通过。直接比 `p50Ms <= 1000 / 30` 时，左右是同一个
  /// double，相等成立 —— 这不是放宽判据，是去掉换算引入的假阴性。
  bool get passesGate => p50Ms > 0 && p50Ms <= 1000 / 30 && p95Ms <= 50;
}

/// 稳态采样的**时长下限**（秒）。
///
/// 笔 1 用的是「采满 300 帧」—— 那个判据在 30 fps 的机器上等于 10 秒，没问题；
/// 但在这台机器上 300 帧只要 **1.2 秒**，采样窗口比「把窗口拖到最大」还短，
/// 于是「改完分辨率再读一次」这个动作根本做不到，读数会在拖动过程中定格。
///
/// 改成按时长：**至少采 [kSampleSeconds] 秒**。帧率快的机器采到的样本更多
/// （这正好是我们要的 —— 分位数需要样本量），慢的机器也不会因为帧数不够而
/// 提前结束。
const double kSampleSeconds = 8.0;

/// 采样是否该停。
///
/// 两条都要满足：采到了样本（否则分位数无从谈起），且已过时长下限。
/// 只有时长没有样本 = 一帧都没跑起来，那种情况给的读数是 `0`，
/// 不能当成「极快」。
bool shouldStopSampling({
  required double elapsedSeconds,
  required int samples,
  double minSeconds = kSampleSeconds,
}) => samples > 0 && elapsedSeconds >= minSeconds;

/// 汇总一次采集。
FrameStats summarize(List<double> frameMs) => FrameStats(
  samples: frameMs.length,
  p50Ms: percentileMs(frameMs, 0.5),
  p95Ms: percentileMs(frameMs, 0.95),
);
