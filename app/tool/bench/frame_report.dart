/// 帧预算读数的**行格式**（`R-22` 的「可复跑」那一半）。
///
/// ## 一行 JSON，前缀固定
///
/// `FRAME_BENCH {...}` —— 前缀让人在满屏的 `flutter run` 日志里 `grep` 得到，
/// JSON 让读数能被下一个人原样读回来复核。**没有第二种格式**：同一份读数既写
/// markdown 表又写日志行，两处必然漂移，而漂移的那一处不会被任何东西抓到。
///
/// ## 只写「量到了什么」，不写「判得怎么样」
///
/// 行里没有 `meetsTarget` / `meetsGood` / `premiseOk` 三个字段 —— 它们是
/// [BenchReport] 的 getter，由窗口尺寸与读数**现算**。理由：派生的判断一旦落到
/// 行里，就多了一份可能与读数矛盾的副本（改了窗口尺寸却忘了改 `premiseOk`），
/// 而读的人只看得见那一份。
///
/// ## 为什么本文件在 `tool/` 而不在 `lib/core/`
///
/// 它是**装置的输出契约**，不是产品运行时的一部分。放 `tool/` 还能避开 `R2`
/// （核心层不许裸字面量）—— 这里的数字是格式与容差（如小数位），进常量表只会
/// 把常量表变成第二份格式化参数表。
library;

import 'dart:convert';

import 'package:project_knowledge/core/bench/frame_stats.dart';

/// 读数行的前缀。`grep '^FRAME_BENCH '` 就是「本机跑过的全部读数」。
const String frameBenchLinePrefix = 'FRAME_BENCH';

/// 行格式的版本。字段增删**或口径变更**必须升它 —— 否则旧行会被按新口径读。
///
/// `v2` 的变更是**口径**：`window` 下原先只有一对宽高，语义是逻辑像素，而 `C-33`
/// 指的是物理客户区。两套尺寸现在各存各的（`physical*` 判前提、`logical*` 备查），
/// 字段名不再靠注释解释 —— `v1` 那种「叫 `width` 但其实是逻辑」的写法，在 100%
/// 缩放的机器上永远读不出问题，换台机器就整组数不可比。
const int frameBenchSchemaVersion = 2;

/// 一次实测的完整读数：场景 + 测量前提 + 三项读数。
class BenchReport {
  const BenchReport({
    required this.scenario,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.devicePixelRatio,
    required this.snapshot,
  });

  /// 场景标识（固定串，如 `tree-drill`）。换场景 = 换一组读数，不可混着比。
  final String scenario;

  /// 客户区宽（**物理像素**）—— `C-33` 的判据量的是它。
  final double physicalWidth;

  /// 客户区高（物理像素）。
  final double physicalHeight;

  /// 客户区宽（逻辑像素）—— 只作记录，不参与任何判据。
  final double logicalWidth;

  /// 客户区高（逻辑像素）。
  final double logicalHeight;

  /// 设备像素比。`physical / logical` 应当等于它，读行的人可以自行验算。
  final double devicePixelRatio;

  final FrameSnapshot snapshot;

  /// 这次读数是否落在 `C-33` 基准窗口下。
  ///
  /// 判的是**物理**尺寸。`false` 不等于「跑挂了」—— 它等于「这组数不能按 `C-32`
  /// 的 30 / 50 解释」。
  bool get premiseOk => framePremiseOk(
        physicalWidth: physicalWidth,
        physicalHeight: physicalHeight,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': frameBenchSchemaVersion,
        'scenario': scenario,
        'window': <String, Object?>{
          'physicalWidth': physicalWidth,
          'physicalHeight': physicalHeight,
          'logicalWidth': logicalWidth,
          'logicalHeight': logicalHeight,
          'dpr': devicePixelRatio,
        },
        'stats': <String, Object?>{
          'intervals': snapshot.intervals,
          'medianIntervalMs': snapshot.medianIntervalMs,
          'medianFps': snapshot.medianFps,
          'frameP95Ms': snapshot.frameP95Ms,
          'rasterP95Ms': snapshot.rasterP95Ms,
          'rasterBudgetShare': snapshot.rasterBudgetShare,
        },
      };

  /// 一行读数（含前缀，不含换行）。
  String toLine() => '$frameBenchLinePrefix ${jsonEncode(toJson())}';

  /// 读回一行读数；前缀不对、JSON 坏、版本不认、缺字段一律 `null`。
  ///
  /// 不抛错也不猜：这是一份**可以被手改**的文本，坏行应当被跳过而不是让整个
  /// 报告工具挂掉 —— 但跳过要留痕，由调用方决定怎么报。
  static BenchReport? parseLine(String line) {
    const String prefix = '$frameBenchLinePrefix ';
    if (!line.startsWith(prefix)) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(line.substring(prefix.length));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    if (decoded['schema'] != frameBenchSchemaVersion) {
      return null;
    }
    final Object? window = decoded['window'];
    final Object? stats = decoded['stats'];
    final Object? scenario = decoded['scenario'];
    if (window is! Map<String, Object?> ||
        stats is! Map<String, Object?> ||
        scenario is! String) {
      return null;
    }
    final double? physicalWidth = _num(window['physicalWidth']);
    final double? physicalHeight = _num(window['physicalHeight']);
    final double? logicalWidth = _num(window['logicalWidth']);
    final double? logicalHeight = _num(window['logicalHeight']);
    final double? dpr = _num(window['dpr']);
    final num? intervals = _int(stats['intervals']);
    final double? medianIntervalMs = _num(stats['medianIntervalMs']);
    final double? medianFps = _num(stats['medianFps']);
    final double? frameP95Ms = _num(stats['frameP95Ms']);
    final double? rasterP95Ms = _num(stats['rasterP95Ms']);
    final double? rasterBudgetShare = _num(stats['rasterBudgetShare']);
    if (physicalWidth == null ||
        physicalHeight == null ||
        logicalWidth == null ||
        logicalHeight == null ||
        dpr == null ||
        intervals == null ||
        medianIntervalMs == null ||
        medianFps == null ||
        frameP95Ms == null ||
        rasterP95Ms == null ||
        rasterBudgetShare == null) {
      return null;
    }
    return BenchReport(
      scenario: scenario,
      physicalWidth: physicalWidth,
      physicalHeight: physicalHeight,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: dpr,
      snapshot: FrameSnapshot(
        intervals: intervals.toInt(),
        medianIntervalMs: medianIntervalMs,
        medianFps: medianFps,
        frameP95Ms: frameP95Ms,
        rasterP95Ms: rasterP95Ms,
        rasterBudgetShare: rasterBudgetShare,
      ),
    );
  }

  static num? _int(Object? value) => value is num ? value : null;

  static double? _num(Object? value) => value is num ? value.toDouble() : null;

  @override
  String toString() => toLine();
}
