import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/cycle_check.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/alpha_pack.dart';

void main() {
  group('α 参考包（content/python）', () {
    test('可解析且图密度四个数与登记口径一致（SPEC-PACK-005）', () {
      final LoadedPack pack = loadAlphaPack();
      expect(pack.space.id, 'python');
      expect(pack.items.length, 150);
      expect(pack.edges.length, 170);
      expect(pack.space.domainIds.length, 10);
      expect(pack.itemById.length, 150);
      expect(pack.schemes, isNotEmpty);
      expect(pack.excerpts, isNotEmpty);
    });

    test('⪯ 无环 —— 构建期校验过，运行时这份也要过（SPEC-FND-005）', () {
      expect(findCycles(loadAlphaPack().edges), isEmpty);
    });

    test('全部 150 项用自己的标题自定位，唯一命中且命中自身（SPEC-FND-008）', () {
      final LoadedPack pack = loadAlphaPack();
      final Locator locator = Locator.single(pack);
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
      final LoadedPack pack = loadAlphaPack();
      final List<String> dangling = <String>[
        for (final Question question in pack.questions)
          if (pack.itemOf(question.itemId) == null) '${question.id} → ${question.itemId}',
      ];
      expect(dangling, isEmpty, reason: dangling.join('\n'));
    });
  });
}
