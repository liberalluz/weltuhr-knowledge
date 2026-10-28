import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/pack.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/errors.dart';
import 'package:project_knowledge/core/json.dart';

import '../../support/m2_pack.dart';

void main() {
  group('Pack（entity-fields §1）', () {
    late JsonMap raw;
    late Pack pack;

    setUp(() {
      raw = jsonDecode(m2PackJson()) as JsonMap;
      pack = Pack.fromJson(raw);
    });

    test('清单字段逐项落地（SPEC-PACK-001）', () {
      expect(pack.pluginId, 'm2-demo');
      expect(pack.name, 'M2 覆盖示例包');
      expect(pack.version, '2.1.0');
      expect(pack.namespace, 'm2-demo');
      expect(pack.schemaVersion, 1);
      expect(pack.skeletonRequires, '>=1.0.0 <2.0.0');
      expect(pack.license, 'MIT');
      expect(pack.reviewState, ReviewState.approved);
      expect(pack.signature, isNull);
      expect(pack.axes, <Axis>[Axis.major]);
    });

    test('kinds 可多值，四个特化字段按声明落地（无 SPEC：entity-fields §1 定形态）', () {
      expect(pack.kinds, <PackKind>[PackKind.payload, PackKind.method]);
      expect(pack.hasKind(PackKind.payload), isTrue);
      expect(pack.hasKind(PackKind.method), isTrue);
      expect(pack.hasKind(PackKind.terrain), isFalse);
      expect(pack.payload, isNotNull);
      expect(pack.method, isNotNull);
      expect(pack.terrain, isNull);
      expect(pack.overlay, isNull);
    });

    test('deps 跨包依赖带区间（无 SPEC：entity-fields §1 `deps[]`）', () {
      expect(pack.deps.length, 1);
      expect(pack.deps.single.pluginId, 'm2-terrain');
      expect(pack.deps.single.range, '>=1.0.0 <2.0.0');
    });

    test('payload 摘要：分级计数与装前可见项（SPEC-PACK-002）', () {
      final PayloadFacts facts = pack.payload!;
      expect(facts.attachTo, 'skeleton:major/080901');
      expect(facts.subtreeRoot, LevelSlot.system);
      expect(facts.levelRange, <LevelSlot>[LevelSlot.system, LevelSlot.planet]);
      expect(facts.counts.star, 0);
      expect(facts.counts.system, 1);
      expect(facts.counts.planet, 8);
      expect(facts.hasSteps, isTrue);
      expect(facts.hasCriteria, isTrue);
      expect(facts.hasQuiz, isTrue);
      expect(facts.quizTypes, <QuizType>[QuizType.choice, QuizType.fill]);
      expect(facts.estMinutesCoverage, 0.75);
      expect(facts.pathReservations.single.parentId, 'skeleton:major/080901');
      expect(facts.pathReservations.single.slug, 'lang-core');
    });

    test('method 摘要带 has_review_step —— 装前就能看出配方缺复习（SPEC-STEP-027）', () {
      final MethodSummary summary = pack.method!.methods.single;
      expect(summary.id, 'm2-recipe');
      expect(summary.stepCount, 4);
      expect(summary.hasReviewStep, isTrue);
      expect(summary.itemTypes, <LearnableType>[
        LearnableType.declarative,
        LearnableType.procedural,
        LearnableType.skill,
      ]);
    });

    test('声明了 kind 却没有特化字段 ⇒ 抛（无 SPEC：ADR-0007「非法状态不可表达」落到 Pack）', () {
      raw.remove('payload');
      expect(
        () => Pack.fromJson(raw),
        throwsA(
          isA<IllegalPackKindError>().having(
            (IllegalPackKindError e) => e.declared,
            'declared',
            isTrue,
          ),
        ),
      );
    });

    test('带了特化字段却没声明 kind ⇒ 抛，且报「不会被读」（无 SPEC：同上）', () {
      raw['kinds'] = <String>['method'];
      expect(
        () => Pack.fromJson(raw),
        throwsA(
          isA<IllegalPackKindError>()
              .having(
                (IllegalPackKindError e) => e.declared,
                'declared',
                isFalse,
              )
              .having(
                (IllegalPackKindError e) => e.kind,
                'kind',
                PackKind.payload,
              ),
        ),
      );
    });

    test('counts 缺一个键就报字段名，不给默认值（无 SPEC：counts 三键由 §1 定死）', () {
      final JsonMap payload = raw['payload']! as JsonMap;
      final JsonMap counts = payload['counts']! as JsonMap;
      counts.remove('planet');
      expect(
        () => Pack.fromJson(raw),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('planet'),
          ),
        ),
      );
    });

    test('TC-PACK-066 domainNames 缺省为空表 —— 不压平的包不需要它（无 SPEC：entity-fields §1 只定字段，未定必须存在）', () {
      // `english` / `german` 正是这个形态：它们的域是真节点、名字在 `name` 上。
      // 缺省若给 `null`，界面每处都要多一个判空分支。
      expect(pack.domainNames, isEmpty);
    });

    test('TC-PACK-067 domainNames 逐项落地，键是标签形态（无 SPEC：键的形态由装配器换键约定）', () {
      final JsonMap withNames = <String, Object?>{
        ...raw,
        'domainNames': <String, String>{'dom-oop': '面向对象', 'dom-func': '函数'},
      };
      expect(Pack.fromJson(withNames).domainNames, <String, String>{
        'dom-oop': '面向对象',
        'dom-func': '函数',
      });
    });

    test('TC-PACK-068 toJson 无条件写出 domainNames —— 条件写出会让空表被判非法键（无 SPEC：白名单由 toJson 派生）', () {
      // `pack_reader._checkTopLevelKeys` 的白名单取 `Pack.toJson().keys`。
      // 若这里改成「空表就不写」，那么一个写着 `"domainNames": {}` 的包会先被
      // 解析成空表、再因为 toJson 里没有这个键而被判成「六段与清单字段之外的键」。
      expect(pack.toJson().containsKey('domainNames'), isTrue);
      expect(pack.toJson()['domainNames'], isEmpty);
    });

    test('序列化往返：解析 → toJson → 再解析，清单字段不变（无 SPEC：自洽性）', () {
      final Pack again = Pack.fromJson(pack.toJson());
      expect(again.pluginId, pack.pluginId);
      expect(again.kinds, pack.kinds);
      expect(again.payload!.counts.planet, pack.payload!.counts.planet);
      expect(again.method!.methods.length, pack.method!.methods.length);
    });
  });
}
