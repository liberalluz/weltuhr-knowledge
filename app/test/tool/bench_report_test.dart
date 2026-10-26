import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/bench/frame_stats.dart';

import '../../tool/bench/frame_report.dart';

/// 读数行格式（`R-22` 的「可复跑」那一半）。
///
/// 行格式值得自测的理由不是「怕 JSON 写错」，而是**它是两个会话之间唯一的接口**：
/// 这一笔跑出的行，下一笔要能原样读回来复核；格式漂了没有任何东西会红，只会
/// 让后来的人读不出上一组读数，然后重新量一遍。
void main() {
  FrameSnapshot snapshot({double medianFps = 60, double rasterP95 = 4}) =>
      FrameSnapshot(
        intervals: 25,
        medianIntervalMs: 1000 / medianFps,
        medianFps: medianFps,
        frameP95Ms: 1000 / medianFps,
        rasterP95Ms: rasterP95,
        rasterBudgetShare: rasterP95 / (1000 / medianFps),
      );

  test('TC-INF-050 读数行能原样读回来，逐字段相等（`C-32`）', () {
    final BenchReport report = BenchReport(
      scenario: 'tree-scroll/root=skeleton:d/depth=3/rows=42/sweepMs=8000',
      windowWidth: 1920,
      windowHeight: 1080,
      devicePixelRatio: 1,
      snapshot: snapshot(),
    );
    final String line = report.toLine();
    expect(line.startsWith('$frameBenchLinePrefix {'), isTrue);

    final BenchReport? parsed = BenchReport.parseLine(line);
    expect(parsed, isNotNull);
    final BenchReport back = parsed!;
    expect(back.scenario, report.scenario);
    expect(back.windowWidth, report.windowWidth);
    expect(back.windowHeight, report.windowHeight);
    expect(back.devicePixelRatio, report.devicePixelRatio);
    expect(back.snapshot.intervals, report.snapshot.intervals);
    expect(back.snapshot.medianFps, report.snapshot.medianFps);
    expect(back.snapshot.frameP95Ms, report.snapshot.frameP95Ms);
    expect(back.snapshot.rasterP95Ms, report.snapshot.rasterP95Ms);
    expect(back.snapshot.rasterBudgetShare, report.snapshot.rasterBudgetShare);
    expect(back.premiseOk, isTrue);
  });

  test('TC-INF-053 读不懂的行一律 null，前提由窗口尺寸现算（`C-33`）', () {
    expect(BenchReport.parseLine(''), isNull);
    expect(BenchReport.parseLine('frame_bench {"schema":1}'), isNull);
    expect(BenchReport.parseLine('$frameBenchLinePrefix 不是 JSON'), isNull);
    expect(
      BenchReport.parseLine(
        '$frameBenchLinePrefix {"schema":99,"scenario":"x",'
        '"window":{"width":1920.0,"height":1080.0,"dpr":1.0},'
        '"stats":{"intervals":25,"medianIntervalMs":16.667,"medianFps":60.0,'
        '"frameP95Ms":16.667,"rasterP95Ms":4.0,"rasterBudgetShare":0.24}}',
      ),
      isNull,
    );

    // 读数全部达标、但窗口是 `R1` 那次对照的尺寸 —— 行里没有 `premiseOk` 字段，
    // 前提只能由尺寸现算，所以它必须判 false。若哪天有人往行里塞一个自查字段，
    // 这条会红。
    const String narrowWindowLine = '$frameBenchLinePrefix '
        '{"schema":1,"scenario":"tree-scroll","window":'
        '{"width":1584.0,"height":875.0,"dpr":1.0},"stats":'
        '{"intervals":25,"medianIntervalMs":16.667,"medianFps":60.0,'
        '"frameP95Ms":16.667,"rasterP95Ms":4.0,"rasterBudgetShare":0.24}}';
    final BenchReport? narrow = BenchReport.parseLine(narrowWindowLine);
    expect(narrow, isNotNull);
    expect(narrow!.premiseOk, isFalse);
    expect(narrow.snapshot.meetsGood, isTrue);
  });
}
