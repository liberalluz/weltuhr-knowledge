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

    test('清单里的空间级声明一路到 space —— 主取值默认轴、六轴、主题色（无 SPEC：ADR-0003 实施注记 §1）', () {
      final LoadedPack pack = loadAlphaPack();

      // 这三样**只在清单里**：`dist/pack.json` 的 `meta` 只带空间 id 与版本，
      // 所以打包链路少抄一段不会有任何东西变红 —— 只会让 `scene.dart` 把所有
      // 星落进越界扇区、颜色全落「未声明」，而画面看起来仍然正常。
      expect(
        pack.space.defaultPrimaryAxis,
        'ability',
        reason: 'α 包取 ability —— subject 在全空间只有一个取值，用它做扇区等于零信息',
      );
      expect(pack.space.sixAxis['topic'], '编程语言');
      expect(pack.space.sixAxis['stack'], 'Python');
      expect(pack.space.accent, isNotEmpty, reason: '主题色只在清单里');
      expect(pack.space.domainIds.length, 10);
    });

    test(
      '没有项级 primaryAxis 覆盖 —— 覆盖路径的判据只由夹具锁（无 SPEC：ADR-0003 修订 §1 的落地形态）',
      () {
        // 这条不是「要求永远没有覆盖」，而是把**当前事实**记下来：α 包 150 项全是
        // 双轴，挑不出唯一候选，所以走的是空间默认。等哪天真加了覆盖，这条会红，
        // 提醒同时把「覆盖优先于默认」告到场景侧用例里（`scene_test.dart` 已有）。
        final LoadedPack pack = loadAlphaPack();
        final List<String> offenders = <String>[
          for (final Item item in pack.items)
            if (item.primaryAxis != null) '${item.id} → ${item.primaryAxis}',
        ];
        expect(offenders, isEmpty, reason: offenders.join('\n'));
      },
    );
  });
}
