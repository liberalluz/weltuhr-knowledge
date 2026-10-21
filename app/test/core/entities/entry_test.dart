import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

import '../../support/m2_pack.dart';

void main() {
  group('NodeEntry（无 SPEC：entity-fields §9）', () {
    late PackContent pack;

    setUp(() => pack = loadM2Pack());

    test('载荷内容逐项落地（无 SPEC：§9 定字段集，非需求条）', () {
      final NodeEntry entry = pack.entryOf('m2-demo:var')!;
      expect(entry.nodeId, 'm2-demo:var');
      expect(entry.summary, isNotNull);
      expect(entry.outcomes.length, 2);
      expect(entry.resources.single.title, 'The Python Tutorial §7.2');
      expect(entry.aliases, <String>['变量']);
      expect(entry.keywords, contains('binding'));
      expect(entry.body, isNotNull);
      expect(entry.steps.length, 2);
      expect(entry.selfCheck.length, 1);
      expect(entry.criteria.length, 1);
      expect(entry.quiz.length, 1);
      expect(entry.estMinutes, 12);
      expect(entry.methodId, isNull);
    });

    test('source_refs 落地 —— 旧 Item.sourceRefs 的新落点（无 SPEC：B13a 笔 4 补裁）', () {
      expect(pack.entryOf('m2-demo:var')!.sourceRefs, <String>['m2-tutorial']);
      // 与 resources 是两个不同的东西：一个「引自哪份材料」，一个「推荐去哪学」。
      expect(pack.entryOf('m2-demo:typing')!.sourceRefs, isEmpty);
      expect(pack.entryOf('m2-demo:typing')!.resources, isEmpty);
    });

    test('骨架节点没有 entry —— 稀疏表，不是「每节点必有一份」（无 SPEC：§9 分离口径）', () {
      expect(pack.nodeOf('m2-demo:lang-core'), isNotNull);
      expect(pack.entryOf('m2-demo:lang-core'), isNull);
    });

    test('相位派生：read / example → first，其余四类 → both（无 SPEC：entity-fields §9.1）', () {
      final EntryStep read = EntryStep.fromJson(<String, Object?>{
        'operator': 'read',
        'instruction': 'x',
      });
      final EntryStep example = EntryStep.fromJson(<String, Object?>{
        'operator': 'example',
        'instruction': 'x',
      });
      final EntryStep recall = EntryStep.fromJson(<String, Object?>{
        'operator': 'recall',
        'instruction': 'x',
      });
      final EntryStep doStep = EntryStep.fromJson(<String, Object?>{
        'operator': 'do',
        'instruction': 'x',
      });
      expect(read.effectivePhase, StepPhase.first);
      expect(example.effectivePhase, StepPhase.first);
      expect(recall.effectivePhase, StepPhase.both);
      expect(doStep.effectivePhase, StepPhase.both);
      expect(doStep.operator, ExecutionOperator.doStep);
    });

    test('显式 phase 覆盖派生（无 SPEC：entity-fields §9.1「作者可覆盖」）', () {
      final EntryStep overridden = EntryStep.fromJson(<String, Object?>{
        'operator': 'read',
        'instruction': 'x',
        'phase': 'review',
      });
      expect(overridden.effectivePhase, StepPhase.review);
    });

    test('空 criteria = 打卡式：跳过 ⑤、S 永不增长（无 SPEC：entity-fields §9.2）', () {
      expect(pack.entryOf('m2-demo:typing')!.isCheckin, isTrue);
      expect(pack.entryOf('m2-demo:var')!.isCheckin, isFalse);
    });

    test('criteria 与 quiz 1:1 对齐（无 SPEC：entity-fields §9.3）', () {
      expect(pack.entryOf('m2-demo:var')!.isQuizAligned, isTrue);
      // 打卡式两边都空，也算对齐 —— 「没有验收」是合法形态，不是坏数据。
      expect(pack.entryOf('m2-demo:typing')!.isQuizAligned, isTrue);
    });

    test('criterion 少一题 ⇒ 对齐判据为假，但不抛（无 SPEC：坏数据归构建期）', () {
      final NodeEntry entry = NodeEntry.fromJson(<String, Object?>{
        'node_id': 'x',
        'summary': null,
        'outcomes': <String>[],
        'resources': <Object?>[],
        'aliases': <String>[],
        'keywords': <String>[],
        'body': null,
        'steps': <Object?>[],
        'selfCheck': <String>[],
        'criteria': <Object?>[
          <String, Object?>{'id': 'c1', 'statement': 'a'},
          <String, Object?>{'id': 'c2', 'statement': 'b'},
        ],
        'quiz': <Object?>[
          <String, Object?>{
            'id': 'q1',
            'criterion_id': 'c1',
            'type': 'choice',
            'prompt': 'p',
            'answer': 'a',
            'judge': 'auto',
          },
        ],
        'source_refs': <String>[],
      });
      expect(entry.isQuizAligned, isFalse);
    });

    test('judge 派生 progressKind：auto → 可系统判（无 SPEC：entity-fields §9.3「不入库」）', () {
      expect(pack.entryOf('m2-demo:var')!.quiz.single.isAutoJudged, isTrue);
      expect(pack.entryOf('m2-demo:debug')!.quiz.single.isAutoJudged, isFalse);
    });

    test('算子线上取值是裁定值：doStep 序列化成 `do`（无 SPEC：Dart 保留字约束）', () {
      final JsonMap json = <String, Object?>{
        'operator': 'do',
        'instruction': 'x',
      };
      final EntryStep step = EntryStep.fromJson(json);
      expect(step.toJson()['operator'], 'do');
      expect(step.toJson()['operator'], isNot('doStep'));
    });
  });
}
