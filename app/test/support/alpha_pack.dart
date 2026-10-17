/// 测试共用的 α 包加载器。
///
/// 抽成一份的理由：`dist/` 不入库（`SPEC-PACK-018`），于每个读真实包的用例
/// 都要「探测 → 解析」，而失败文案决定了出问题的人能不能一眼修好。写两份
/// 就等于两套失败文案，改一处忘一处。
///
/// **包不存在时明确失败，不 skip。**`dist/` 由 `build.py` 生成，跳过会让
/// 「CI 全绿」变成「一条真数据都没验过」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/dart_io_pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/pack/pack_probe.dart';

/// 载入 `content/python` 的产物。
LoadedPack loadAlphaPack() {
  const PackFs fs = DartIoPackFs();
  final ProbeResult probe = const PackProbe(fs).scanRoots(devPackRoots());
  PackLocation? alpha;
  for (final PackLocation location in probe.locations) {
    if (location.spaceRoot.endsWith('/python')) {
      alpha = location;
      break;
    }
  }
  if (alpha == null) {
    fail(
      '找不到 α 包（候选根：${devPackRoots().join(" · ")}）。\n'
      '先跑 `python content/tools/build.py python` —— `dist/` 不入库（`SPEC-PACK-018`）。\n'
      '探测问题：${probe.problems.isEmpty ? "无（目录都不存在）" : probe.problems.join("; ")}',
    );
  }
  return parsePack(
    manifestJson: fs.readString(alpha.manifestPath)!,
    packJson: fs.readString(alpha.packPath)!,
  );
}
