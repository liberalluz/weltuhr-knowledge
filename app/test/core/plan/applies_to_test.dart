import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/plan/applies_to.dart';

import '../../support/node_fixture.dart';

/// 匹配器的契约测试。
///
/// 从 `candidates_test.dart` 拆出来（`B13a` 笔 5c-1）：那里 5 条用例靠 α 包造
/// `Item`，而匹配器收的是 `Node` —— 借旧实体搭桥会把「待删的东西」当依赖，
/// 而这一份应当在 5c-2 / 5c-3 换解析层时**原样存活**。
void main() {
  group('appliesTo 匹配', () {
    test('未给的键不构成限制，给了的键逐项相符才通过（SPEC-PLAN-020）', () {
      expect(appliesToNode(<String, Object?>{}, node: learnableNode()), isTrue);

      expect(
        appliesToNode(
          <String, Object?>{'type': 'declarative'},
          node: learnableNode(),
        ),
        isTrue,
      );
      expect(
        appliesToNode(
          <String, Object?>{'type': 'declarative'},
          node: learnableNode(type: LearnableType.procedural),
        ),
        isFalse,
      );
      // 给了**空数组**不是「不限」：`type: []` 读作「任何类型都不适用」。
      // 写入口 `normalizeAppliesTo` 会先把空容器丢掉，所以它只在手工构造的
      // map 上出现 —— 那正是要拦的情况。
      expect(
        appliesToNode(
          <String, Object?>{'type': <String>[]},
          node: learnableNode(),
        ),
        isFalse,
      );

      // `type` / `layer` 只对可学节点有意义。结构节点上声明了它们 ⇒ 不命中，
      // 不是「缺字段」：结构节点本来就不是可学的项（`ADR-0007` 决策 1）。
      expect(
        appliesToNode(
          <String, Object?>{'type': 'declarative'},
          node: structuralNode(),
        ),
        isFalse,
      );
      expect(
        appliesToNode(
          <String, Object?>{'layer': 'persistent'},
          node: structuralNode(),
        ),
        isFalse,
      );
      // 只声明 `axes` 时结构节点照常参与匹配 —— 四条轴不管「可学与否」。
      expect(
        appliesToNode(
          <String, Object?>{'axes': 'discipline'},
          node: structuralNode(),
        ),
        isTrue,
      );
    });

    test('数组取任一命中，单值需相符（SPEC-PLAN-020）', () {
      expect(
        appliesToNode(
          <String, Object?>{'type': <String>['declarative', 'procedural']},
          node: learnableNode(type: LearnableType.procedural),
        ),
        isTrue,
      );
      expect(
        appliesToNode(
          <String, Object?>{'type': <String>['declarative', 'skill']},
          node: learnableNode(type: LearnableType.procedural),
        ),
        isFalse,
      );
    });

    test('六轴与空间两个键都已不再被接受：传了就抛，不静默忽略（SPEC-PLAN-020 修订，笔 5c-1）', () {
      // `sixAxis` 随 `ADR-0005` 失效、`spaceId` 随「一空间一包已废」失效
      // （`entity-fields` §11 附注）。两者都落进「未认的键」那条判据：
      // **抛错，不静默放过** —— 静默忽略等于让作者以为约束还在生效。
      expect(
        () => appliesToNode(
          <String, Object?>{
            'sixAxis': <String, Object?>{'stack': 'Python'},
          },
          node: learnableNode(),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => appliesToNode(
          <String, Object?>{'spaceId': 'java'},
          node: learnableNode(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('axes 与节点轴相符才适用，轴不符即不适用（ADR-0005）', () {
      // `axes` 是 `spaceId` 的对家：一空间一包废掉之后，「适用哪条轴」才是
      // 作者与用户都说得出口的那一句（`entity-fields` §12）。
      expect(
        appliesToNode(<String, Object?>{'axes': 'occupation'}, node: learnableNode()),
        isTrue,
      );
      expect(
        appliesToNode(<String, Object?>{'axes': 'major'}, node: learnableNode()),
        isFalse,
      );
      expect(
        appliesToNode(
          <String, Object?>{
            'axes': <String>['discipline', 'occupation'],
          },
          node: learnableNode(),
        ),
        isTrue,
      );
      expect(
        appliesToNode(<String, Object?>{'axes': 'discipline'}, node: structuralNode()),
        isTrue,
      );
      expect(
        appliesToNode(<String, Object?>{'axes': 'occupation'}, node: structuralNode()),
        isFalse,
      );
    });

    test('未认的键与写错的形状都在比较之前就报，不静默忽略（无 SPEC：entity-fields 未列可用键，本笔补在附注里）', () {
      expect(
        () => appliesToNode(
          <String, Object?>{'relevance': 'high'},
          node: learnableNode(),
        ),
        throwsFormatException,
      );
      // 形状错与「匹配不上」不能压成同一个 `false`：前者是作者的错（应当当场报），
      // 后者是正常结论。`<int>[1]` 这种要在逐项比较之前就拦住。
      expect(
        () => appliesToNode(
          <String, Object?>{'type': <Object>[1]},
          node: learnableNode(),
        ),
        throwsFormatException,
      );
    });
  });
}
