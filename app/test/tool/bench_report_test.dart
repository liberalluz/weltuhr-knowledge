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

  /// 一台 125% 缩放机器上的基准读数：物理 `1920×1080`、逻辑 `1536×864`。
  BenchReport report({
    double physicalWidth = 1920,
    double physicalHeight = 1080,
    double devicePixelRatio = 1.25,
  }) =>
      BenchReport(
        scenario:
            'tree-scroll/root=skeleton:d/depth=3/rows=42/sweepMs=8000',
        physicalWidth: physicalWidth,
        physicalHeight: physicalHeight,
        logicalWidth: physicalWidth / devicePixelRatio,
        logicalHeight: physicalHeight / devicePixelRatio,
        devicePixelRatio: devicePixelRatio,
        snapshot: snapshot(),
      );

  /// 一份 `stats` 段（各条坏行用例共用，避免每处抄一遍）。
  const String statsJson = '"stats":{"intervals":25,'
      '"medianIntervalMs":16.667,"medianFps":60.0,"frameP95Ms":16.667,'
      '"rasterP95Ms":4.0,"rasterBudgetShare":0.24}';

  test('TC-INF-050 读数行能原样读回来，逐字段相等（`C-32`）', () {
    final BenchReport original = report();
    final String line = original.toLine();
    expect(line.startsWith('$frameBenchLinePrefix {'), isTrue);

    final BenchReport? parsed = BenchReport.parseLine(line);
    expect(parsed, isNotNull);
    final BenchReport back = parsed!;
    expect(back.scenario, original.scenario);
    expect(back.physicalWidth, original.physicalWidth);
    expect(back.physicalHeight, original.physicalHeight);
    expect(back.logicalWidth, original.logicalWidth);
    expect(back.logicalHeight, original.logicalHeight);
    expect(back.devicePixelRatio, original.devicePixelRatio);
    expect(back.snapshot.intervals, original.snapshot.intervals);
    expect(back.snapshot.medianFps, original.snapshot.medianFps);
    expect(back.snapshot.frameP95Ms, original.snapshot.frameP95Ms);
    expect(back.snapshot.rasterP95Ms, original.snapshot.rasterP95Ms);
    expect(back.snapshot.rasterBudgetShare, original.snapshot.rasterBudgetShare);
    expect(back.premiseOk, isTrue);
  });

  test('TC-INF-053 读不懂的行一律 null，前提由窗口尺寸现算（`C-33`）', () {
    expect(BenchReport.parseLine(''), isNull);
    expect(BenchReport.parseLine('$frameBenchLinePrefix 不是 JSON'), isNull);
    expect(
      BenchReport.parseLine(
        '$frameBenchLinePrefix {"schema":99,"scenario":"x",'
        '"window":{"physicalWidth":1920.0,"physicalHeight":1080.0,'
        '"logicalWidth":1536.0,"logicalHeight":864.0,"dpr":1.25},'
        '$statsJson}',
      ),
      isNull,
    );

    // 读数全部达标、但窗口是 `R1` 那次对照的尺寸 —— 行里没有 `premiseOk` 字段，
    // 前提只能由尺寸现算，所以它必须判 false。若哪天有人往行里塞一个自查字段，
    // 这条会红。
    const String narrowWindowLine = '$frameBenchLinePrefix '
        '{"schema":2,"scenario":"tree-scroll","window":'
        '{"physicalWidth":1584.0,"physicalHeight":875.0,'
        '"logicalWidth":1584.0,"logicalHeight":875.0,"dpr":1.0},'
        '$statsJson}';
    final BenchReport? narrow = BenchReport.parseLine(narrowWindowLine);
    expect(narrow, isNotNull);
    expect(narrow!.premiseOk, isFalse);
    expect(narrow.snapshot.meetsGood, isTrue);
  });

  test('TC-INF-058 旧版读数行拒收：口径一变就必须升 schema（`C-33`）', () {
    // `v1` 的行：`window` 下只有一对宽高，语义是**逻辑**像素。它是真跑出来过的行，
    // 存在磁盘上；升版后它必须读不懂 —— 读懂了就会把逻辑 `1536` 当成物理基准去判
    // `premiseOk`，得到「不达标」这个错误结论。
    //
    // ⚠️ 这一条故意写得**字段齐全**、只把 `schema` 留成 1：如果照 v1 的原始形态
    // 写（只有 `width` / `height`），那「字段缺失」本身就会让它返回 null，删掉
    // 版本判据它照样 null ⇒ 断言在两种实现下同答案，等于没验（`R-08` 同族）。
    // 字段齐、版本旧，才把判据逼到「认不认这个版本号」这一点上。
    const String fullFieldsV1 = '$frameBenchLinePrefix '
        '{"schema":1,"scenario":"tree-scroll","window":'
        '{"physicalWidth":1920.0,"physicalHeight":1080.0,'
        '"logicalWidth":1536.0,"logicalHeight":864.0,"dpr":1.25},'
        '$statsJson}';
    expect(BenchReport.parseLine(fullFieldsV1), isNull);

    // 只把 schema 改成 2 也救不了另一种坏行：字段名不对就是读不懂，不许猜
    // 「`width` 大概就是 `physicalWidth`」。真去猜，返回一个 `premiseOk=false`
    // 的报告比返回 `null` 更坏 —— 读的人会以为那是量出来的结论。
    const String renamedButSameShape = '$frameBenchLinePrefix '
        '{"schema":2,"scenario":"tree-scroll","window":'
        '{"width":1920.0,"height":1080.0,"dpr":1.0},'
        '$statsJson}';
    expect(BenchReport.parseLine(renamedButSameShape), isNull);

    // 反向：当前格式自己写的行必须读得回来，否则上面两条「读不懂」可能只是
    // 解析器全坏。
    expect(BenchReport.parseLine(report().toLine()), isNotNull);
  });

  test('TC-INF-059 逻辑尺寸冒充物理就判不达标（`C-33`）', () {
    // 同一台机器、同一份读数，两条输入只差 `physical*` 那两项：
    // 前者是视口真实的物理尺寸，后者是把逻辑尺寸误当物理塞进来。
    // **若实现改成拿 `logical*` 判前提，第一条会变 true、第二条仍是 false，
    // 本条即红** —— 这正是这个缺陷在 100% 缩放的机器上永远看不见的原因：
    // 那时 `logical == physical`，两种写法给出同一答案。
    final BenchReport correct = report();
    expect(correct.premiseOk, isTrue);
    expect(correct.logicalWidth, 1536);
    expect(correct.logicalHeight, 864);

    final BenchReport mistaken = BenchReport(
      scenario: 'tree-scroll',
      physicalWidth: 1536,
      physicalHeight: 864,
      logicalWidth: 1536,
      logicalHeight: 864,
      devicePixelRatio: 1.25,
      snapshot: snapshot(),
    );
    expect(mistaken.premiseOk, isFalse);
  });
}
