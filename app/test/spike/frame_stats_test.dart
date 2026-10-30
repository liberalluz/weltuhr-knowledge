import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/spike/frame_stats.dart';

/// 帧率统计的用例。
///
/// spike 的结论全压在这两个分位数上，而分位取法本身有好几种（插值、最近秩、
/// 下中位…），取错了不会报错、只会给出一个看起来合理的错数 —— 所以它值得
/// 单测，且每条都对着原始样本核。
void main() {
  test('TC-SPIKE-001 空样本不抛，读数归零（ADR-0006 §3）', () {
    final FrameStats stats = summarize(const <double>[]);

    expect(stats.samples, 0);
    expect(stats.p50Ms, 0);
    expect(stats.p95Ms, 0);
    expect(stats.p50Fps, 0, reason: '没采到样本时帧率记 0，不拿除零后的无穷大冒充满分');
    expect(stats.passesGate, isFalse, reason: '没有读数就不能判过闸');
  });

  test('TC-SPIKE-002 偶数样本的 P50 取在下中位（ADR-0006 §3）', () {
    // n = 4，ceil(0.5 × 4) = 2 → 取排序后第 2 个，即 20 而不是 25。
    // 插值会给出 25 —— 一个样本里根本不存在的帧时间。
    expect(percentileMs(const <double>[10, 20, 30, 40], 0.5), 20);
    // n = 2，两样本的下中位就是较小那个。
    expect(percentileMs(const <double>[16, 34], 0.5), 16);
  });

  test('TC-SPIKE-003 P95 落在最近秩上，不到末位（ADR-0006 §3）', () {
    // n = 20，ceil(0.95 × 20) = 19 → 取第 19 个（倒数第二），不是最大值。
    final List<double> samples = List<double>.generate(
      20,
      (int i) => (i + 1).toDouble(),
    );
    expect(percentileMs(samples, 0.95), 19);
    // n = 3，ceil(0.95 × 3) = 3 → 越界时夹到末位。
    expect(percentileMs(const <double>[1, 2, 3], 0.95), 3);
  });

  test('TC-SPIKE-004 样本乱序进、按序出（ADR-0006 §3）', () {
    final FrameStats stats = summarize(const <double>[40, 10, 30, 20]);

    expect(stats.p50Ms, 20);
    expect(stats.samples, 4, reason: '排序是内部行为，不能改变样本数');
  });

  test('TC-SPIKE-005 闸门两条阈值都要满足才算过（ADR-0006 §3）', () {
    // P50 = 20 ms → 50 fps，P95 = 40 ms：两条都过。
    expect(summarize(const <double>[20, 20, 20, 40]).passesGate, isTrue);

    // P50 = 40 ms → 25 fps，P95 = 45 ms：P95 过但帧率不过。
    expect(
      summarize(const <double>[40, 40, 40, 45]).passesGate,
      isFalse,
      reason: '帧率不够就是不够，P95 好看也救不回来',
    );

    // P50 = 30 ms → 33.3 fps 过，P95 = 60 ms 不过。
    expect(
      summarize(const <double>[30, 30, 30, 60]).passesGate,
      isFalse,
      reason: '卡顿是另一条独立的失败路径',
    );
  });

  test('TC-SPIKE-006 帧时间换算成帧率是真倒数（ADR-0006 §3）', () {
    // 1000 / 20 = 50 fps。
    expect(summarize(const <double>[20]).p50Fps, 50);
    // 边界：33.33 ms 约合 30.0 fps，恰好压线。
    expect(summarize(const <double>[1000 / 30]).passesGate, isTrue);
  });
}
