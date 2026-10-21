/// 三段「+ 自建」的核心层（`SPEC-PLAN-007` / `011`）。
///
/// 这里不 pump 任何 widget：自建的**难点不在表单，在「什么算一份合法的自建」**
/// —— 空 `appliesTo` 与空列表的区别、配方少一个 review 步会不会被静默放过、
/// 体系节点重复要不要报警。这些都能在纯函数上判，也只有在纯函数上才判得清。
///
/// ## 笔 5c 的三处切新
///
/// | 旧 | 新 |
/// |---|---|
/// | `MethodStep(operator:, criteria:, hint:)` | `EntryStep(operator:, instruction:, phase:, hint:)` —— 步骤上**没有** `criteria`，判据归 `NodeEntry.criteria[]` |
/// | `authorityLevel: 'L1'`…`'L4'` | `AuthorityLevel` 五档枚举（`official`…`community`） |
/// | `ItemType` | `LearnableType`；`bundle.coveredTypes` → `bundle.byType.keys` |
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/scheme.dart';
import 'package:project_knowledge/core/entities/source.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/plan/applies_to.dart';
import 'package:project_knowledge/core/plan/user_content.dart';

import '../../support/node_fixture.dart';

/// `instruction` 是必填项 —— 它取代了旧 `MethodStep` 上的 `criteria`
/// 位置，但语义完全不同：「这一步做什么」而不是「做到什么算过」。
EntryStep _step(
  ExecutionOperator op, {
  StepPhase? phase,
  String? hint,
}) => EntryStep(
  operator: op,
  instruction: '按 ${op.name} 做一步',
  phase: phase,
  hint: hint,
);

void main() {
  group('自建内容的 id 与 appliesTo 归一', () {
    test('TC-PLAN-079 自建 id 优先用前缀本身，撞了才追加序号（无 SPEC：id 生成属实现口径）', () {
      expect(uniqueContentId('user:src:内规', const <String>[]), 'user:src:内规');

      // 撞了之后从 `taken.length` 起步往后试；关键是**同输入同输出**，
      // 随机数会让「建了两次」与「改了一次」在事件流里分不开。
      final String first = uniqueContentId(
        'user:src:内规',
        <String>['user:src:内规'],
      );
      expect(
        uniqueContentId('user:src:内规', <String>['user:src:内规']),
        first,
        reason: '同一份输入必须给出同一个 id',
      );
      expect(first, isNot('user:src:内规'));
      expect(
        uniqueContentId('user:src:内规', <String>['user:src:内规', first]),
        isNot(first),
      );
    });

    test('TC-PLAN-080 空 appliesTo 读作「不限」，空列表与 null 必须丢掉（SPEC-PLAN-007）', () {
      // 表单里一个类型都没勾时给的是 `{'type': []}`。留着它，
      // `appliesToNode` 走「名单逐项比对」⇒ 空列表恒不命中 ⇒ 全部项被筛空。
      //
      // 笔 5b 起不再有「空 map」这个样本：`appliesTo` 的三个键（笔 5c-1 起是
      // `type` / `axes` / `layer`）没有一个是对象类型，`sixAxis` 键随 `ADR-0005`
      // 移除后，`normalizeAppliesTo` 里那条「空 Map 丢弃」分支永远进不去，已删。
      final JsonMap normalized = normalizeAppliesTo(<String, Object?>{
        'type': <String>[],
        'layer': null,
      });
      expect(normalized, isEmpty);
      expect(
        appliesToNode(normalized, node: learnableNode()),
        isTrue,
        reason: '归一后应读成「不限」，不是「任何类型都不适用」',
      );
    });

    test('TC-PLAN-081 未认的 appliesTo 键仍抛（无 SPEC：沿用 appliesToItem 的未认键口径）', () {
      expect(
        () => normalizeAppliesTo(<String, Object?>{'relevance': 'high'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('自建的源', () {
    test('TC-PLAN-082 自建的源没有摘录正文，名字与版本必填（SPEC-PLAN-007）', () {
      final SourceRef source = buildUserSource(
        id: 'user:src:内规',
        name: ' 内规 ',
        authorityLevel: AuthorityLevel.standard,
        version: '1',
      );
      expect(source.name, '内规', reason: '前后空白不该带进候选名');
      expect(source.kind, SourceKind.material, reason: '自建的没有官方码可依据');
      expect(source.authorityLevel, AuthorityLevel.standard);
      expect(
        source.segments,
        isEmpty,
        reason: '内容绑定落地前拿不到摘录 —— 这是登记状态，不是漏填',
      );
      // `SourceAppliesTo` 没有 `isEmpty`：两个键都是必填列表，判「空」要逐个看。
      expect(source.appliesTo.axes, isEmpty);
      expect(source.appliesTo.nodeScope, isEmpty);

      expect(
        () => buildUserSource(
          id: 'x',
          name: '   ',
          authorityLevel: AuthorityLevel.standard,
          version: '1',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildUserSource(
          id: 'x',
          name: '内规',
          authorityLevel: AuthorityLevel.standard,
          version: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('自建的体系', () {
    test('TC-PLAN-083 节点顺序就是学习次序，重复节点去重保首次（SPEC-PLAN-007）', () {
      final Scheme scheme = buildUserScheme(
        id: 'user:sch:先易后难',
        name: '先易后难',
        nodes: <String>['i3', 'i1', 'i3', 'i2'],
        authorityLevel: AuthorityLevel.textbook,
      );
      expect(
        scheme.nodes,
        <String>['i3', 'i1', 'i2'],
        reason: '顺序是规格的一部分（体系段选的就是「先学哪个」），不能排序',
      );
      expect(
        () => buildUserScheme(
          id: 'x',
          name: '空序',
          nodes: const <String>[],
          authorityLevel: AuthorityLevel.textbook,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('自建方法：只能自定配方', () {
    test('TC-PLAN-084 全「读 / 例」的配方被拒 —— 会静默绕过遗忘曲线（SPEC-PLAN-011）', () {
      expect(
        () => validateMethodRecipe(<EntryStep>[
          _step(ExecutionOperator.read),
          _step(ExecutionOperator.example),
        ]),
        throwsA(isA<ArgumentError>()),
        reason: 'entity-fields §9 校验 ②：至少一个 review 步',
      );

      // 同样是「读」，但作者显式把 phase 覆盖成 review ⇒ 满足 ②。
      validateMethodRecipe(<EntryStep>[
        _step(ExecutionOperator.read, phase: StepPhase.review),
      ]);
    });

    test('TC-PLAN-085 空配方被拒；一份自建只覆盖一个类型，bundle id 由 profile 派生（SPEC-PLAN-010）', () {
      expect(
        () => validateMethodRecipe(const <EntryStep>[]),
        throwsA(isA<ArgumentError>()),
      );

      final UserMethodDraft draft = UserMethodDraft(
        id: 'user:method:三遍法',
        name: '三遍法',
        type: LearnableType.procedural,
        steps: <EntryStep>[
          _step(ExecutionOperator.read),
          _step(ExecutionOperator.practice),
          _step(ExecutionOperator.practice),
        ],
      );
      final ({MethodProfile profile, MethodBundle bundle}) built =
          buildUserMethod(draft);

      expect(built.profile.origin, CandidateOrigin.user);
      expect(built.profile.appliesTo, <String, Object?>{'type': 'procedural'});
      // 旧 `bundle.coveredTypes` 已随旧 `MethodBundle` 删除：覆盖面就是 `byType`
      // 的键集，多留一个派生 getter 等于给「两者不一致」留一条路。
      expect(
        built.bundle.byType.keys.toSet(),
        <LearnableType>{LearnableType.procedural},
      );
      expect(
        built.bundle.id,
        userBundleIdOf('user:method:三遍法'),
        reason: '重入时只凭 Plan.methodProfileId 就要能反查是哪一份自建',
      );
      expect(built.bundle.byType[LearnableType.procedural], 'user:method:三遍法');
    });

    test('TC-PLAN-086 全步骤无 hint 时判得出来（不拦，但确认段要能说出来）（SPEC-PLAN-011）', () {
      final ({MethodProfile profile, MethodBundle bundle}) noHint =
          buildUserMethod(
            UserMethodDraft(
              id: 'user:method:无提示',
              name: '无提示',
              type: LearnableType.declarative,
              steps: <EntryStep>[
                _step(ExecutionOperator.read),
                _step(ExecutionOperator.recall),
              ],
            ),
          );
      expect(
        bundleHasAnyHint(noHint.bundle, <MethodProfile>[noHint.profile]),
        isFalse,
      );

      final ({MethodProfile profile, MethodBundle bundle}) withHint =
          buildUserMethod(
            UserMethodDraft(
              id: 'user:method:有提示',
              name: '有提示',
              type: LearnableType.declarative,
              steps: <EntryStep>[
                _step(ExecutionOperator.recall, hint: '先想标题'),
              ],
            ),
          );
      expect(
        bundleHasAnyHint(withHint.bundle, <MethodProfile>[withHint.profile]),
        isTrue,
      );
    });
  });
}
