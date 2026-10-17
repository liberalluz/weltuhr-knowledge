import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/cycle_check.dart';
import 'package:project_knowledge/core/pack/dart_io_pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/pack/pack_probe.dart';

/// 真实 α 包的加载：探测（找目录）→ 解析（两段文本）→ 实体。
///
/// **包不存在时明确失败，不 skip**：`dist/` 不入库（`SPEC-PACK-018`），
/// 所以这条用例的正确前提是先跑一次 `build.py`。跳过会让「CI 全绿」变成
/// 「一条真数据都没验过」，而这个包正是帧预算的输入口径 —— 静默跳过比红更贵。
LoadedPack _loadAlpha() {
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

void main() {
  group('α 参考包（content/python）', () {
    test('可解析且图密度四个数与登记口径一致（SPEC-PACK-005）', () {
      final LoadedPack pack = _loadAlpha();
      expect(pack.space.id, 'python');
      expect(pack.items.length, 150);
      expect(pack.edges.length, 170);
      expect(pack.space.domainIds.length, 10);
      expect(pack.itemById.length, 150);
      expect(pack.schemes, isNotEmpty);
      expect(pack.excerpts, isNotEmpty);
    });

    test('⪯ 无环 —— 构建期校验过，运行时这份也要过（SPEC-FND-005）', () {
      expect(findCycles(_loadAlpha().edges), isEmpty);
    });

    test('全部 150 项用自己的标题自定位，唯一命中且命中自身（SPEC-FND-008）', () {
      final LoadedPack pack = _loadAlpha();
      final Locator locator = Locator(pack);
      final List<String> failures = <String>[];
      for (final Item item in pack.items) {
        final LocateResult result = locator.locate(item.title);
        if (result.state != LocateState.located || result.top?.target != item.id) {
          failures.add(
            '${item.id}「${item.title}」⇒ ${result.state.name}'
            '（${result.top?.kind.name}:${result.top?.target ?? "-"}）',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('题库全部指向在册项 —— 声明式题不入空的 itemId（无 SPEC：约束见 entity-fields §4）', () {
      final LoadedPack pack = _loadAlpha();
      final List<String> dangling = <String>[
        for (final Question question in pack.questions)
          if (pack.itemOf(question.itemId) == null) '${question.id} → ${question.itemId}',
      ];
      expect(dangling, isEmpty, reason: dangling.join('\n'));
    });
  });
}
