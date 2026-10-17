import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/entities/state.dart';
import 'package:project_knowledge/core/enums.dart';

Map<String, Object?> _itemJson() => <String, Object?>{
  'id': 'py-lambda',
  'title': 'Lambda 表达式',
  'sixAxis': <String, String>{'subject': 'python', 'ability': 'programming'},
  'layer': 'persistent',
  'type': 'statement',
  'requirements': <String, Object?>{
    'boundary': 'complete',
    'justification': 'missing',
    'proposition': 'complete',
    'relation': 'missing',
    'how': 'notExternalizable',
    'tacit': 'missing',
  },
  'sourceRefs': <String>['src-official'],
  'domainId': 'py-basics',
  'inScope': true,
};

void main() {
  group('Item / 六要件', () {
    test('不可外化格不进深度分母（SPEC-QUANT-006）', () {
      final Item item = Item.fromJson(_itemJson());
      expect(item.requirements.completeCount, 2);
      expect(item.requirements.externalizableCount, 5);
    });

    test('fromJson(toJson()) 往返保真（无 SPEC：JSON 往返属契约层通用要求）', () {
      final Item original = Item.fromJson(_itemJson());
      final Item roundTrip = Item.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.sixAxis, original.sixAxis);
      expect(roundTrip.layer, Layer.persistent);
      expect(roundTrip.type, ItemType.statement);
      expect(roundTrip.requirements.toJson(), original.requirements.toJson());
    });

    test('六要件缺一格即格式错误，不补默认值（SPEC-PACK-009）', () {
      final Map<String, Object?> broken = _itemJson();
      final Map<String, Object?> requirements =
          Map<String, Object?>.of(broken['requirements']! as Map<String, Object?>)..remove('tacit');
      broken['requirements'] = requirements;
      expect(() => Item.fromJson(broken), throwsFormatException);
    });
  });

  group('MethodStep / 相位派生', () {
    test('读 → first；练 → both（SPEC-STEP-014）', () {
      final MethodStep read = MethodStep.fromJson(<String, Object?>{'operator': 'read'});
      final MethodStep practice = MethodStep.fromJson(<String, Object?>{'operator': 'practice'});
      expect(read.effectivePhase, StepPhase.first);
      expect(practice.effectivePhase, StepPhase.both);
    });

    test('作者可覆盖派生的 phase（SPEC-STEP-014）', () {
      final MethodStep step = MethodStep.fromJson(<String, Object?>{
        'operator': 'read',
        'phase': 'review',
      });
      expect(step.effectivePhase, StepPhase.review);
    });
  });

  group('MethodProfile 三条校验', () {
    test('至少一个 review 步骤；全为读/例则判否（SPEC-STEP-027）', () {
      final MethodProfile ok = MethodProfile.fromJson(<String, Object?>{
        'id': 'm1',
        'name': '间隔重复',
        'origin': 'pack',
        'appliesTo': <String, Object?>{'itemType': 'statement'},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read'},
          <String, Object?>{'operator': 'recall'},
        ],
      });
      final MethodProfile bad = MethodProfile.fromJson(<String, Object?>{
        'id': 'm2',
        'name': '只看不练',
        'origin': 'user',
        'appliesTo': <String, Object?>{},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read'},
          <String, Object?>{'operator': 'example'},
        ],
      });
      expect(ok.hasReviewStep, isTrue);
      expect(bad.hasReviewStep, isFalse);
    });

    test('全部步骤无判据 ⇒ 打卡式；任一步有 hint ⇒ 可给提示（SPEC-STEP-015 / SPEC-STEP-022）', () {
      final MethodProfile checkin = MethodProfile.fromJson(<String, Object?>{
        'id': 'm3',
        'name': '读一遍',
        'origin': 'user',
        'appliesTo': <String, Object?>{},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read', 'params': <String, Object?>{'minutes': 10}},
        ],
      });
      expect(checkin.isCheckin, isTrue);
      expect(checkin.hasAnyHint, isFalse);
    });
  });

  group('Note 三层显示优先级', () {
    test('authored > autoFilled > generated（SPEC-NOTE-008）', () {
      final Note note = Note.fromJson(<String, Object?>{
        'itemId': 'py-lambda',
        'sectionKey': 'lambda.basics',
        'layers': <String, String>{
          'generated': '生成层',
          'autoFilled': '自动补',
          'authored': '手写层',
        },
        'noteVersion': 3,
        'origin': 'standard',
      });
      expect(note.displayText, '手写层');
      expect(note.noteVersion, 3);
    });
  });

  group('Plan', () {
    test('target.count 由 resolved 派生，不单独存（无 SPEC：字段定义见 docs/reference/entity-fields.md）', () {
      final Plan plan = Plan.fromJson(<String, Object?>{
        'id': 'p1',
        'spaceId': 'python',
        'spaceVersion': '1.2.0',
        'target': <String, Object?>{
          'selector': <String, Object?>{'domainId': 'py-basics'},
          'resolved': <String>['a', 'b', 'c'],
        },
        'sourcePolicy': <String, Object?>{'primary': 'src-official'},
        'schemeId': 's1',
        'methodProfileId': 'm1',
        'version': 1,
      });
      expect(plan.target.count, 3);
      expect(plan.toJson()['target'], containsPair('count', 3));
    });
  });
}
