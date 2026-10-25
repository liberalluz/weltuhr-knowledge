import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/main.dart';

/// 详情页文案里**不许出现内部枚举**。
///
/// 这一组盯的不是「表里有没有值」，而是「拼出来的那一行里有没有英文标识」：
/// 表补得再全，只要 `build` 里还写 `step.effectivePhase.name`，界面上就是
/// `first`。所以负例一律打在 [stepLine] / [quizLine] 的输出上。

EntryStep stepWith(String operator, {String? phase}) {
  return EntryStep.fromJson(<String, Object?>{
    'operator': operator,
    'instruction': '指令原文',
    'phase': phase,
  });
}

QuizItem quizWith(String type, String judge) {
  return QuizItem.fromJson(<String, Object?>{
    'id': 'q-probe',
    'criterion_id': 'c-probe',
    'type': type,
    'prompt': '题干',
    'answer': '答案',
    'judge': judge,
  });
}

void main() {
  test('读算子 + 首学相位：写「读（首次）」，不出现 read / first（SPEC-STEP-012）', () {
    final String line = stepLine(stepWith('read'));

    expect(line, '· 读（首次）指令原文');
    expect(line.contains('read'), isFalse);
    expect(line.contains('first'), isFalse);
  });

  test('do 算子：写「做」，不出现 doStep 也不出现 do（SPEC-STEP-012）', () {
    // `doStep` 是本项目唯一「枚举名 ≠ 线上取值」的执行算子（`do` 是保留字，
    // 成员名只能叫 `doStep`，wire 是 `do`）。两个字符串都不能漏到界面上：
    // 漏 `doStep` 说明渲染的是 `name`，漏 `do` 说明渲染的是 `wire`，都不对。
    final String line = stepLine(stepWith('do'));

    expect(line, '· 做（首次与复习）指令原文');
    expect(line.contains('doStep'), isFalse);
    expect(line.contains('do'), isFalse);
  });

  test('作者覆盖的 review 相位：写「复习」，不出现 review（无 SPEC：phase 中文名）', () {
    final String line = stepLine(stepWith('recall', phase: 'review'));

    expect(line, startsWith('· 忆（复习）'));
    expect(line.contains('review'), isFalse);
  });

  test('题目来源括号写中文，不出现 freeform / self（无 SPEC：题型与判定方中文名）', () {
    final String line = quizLine(quizWith('freeform', 'self'));

    expect(line, '问：题干\n答：答案\n（自由作答 · 自评）');
    expect(line.contains('freeform'), isFalse);
    expect(line.contains('self'), isFalse);
  });

  test('四张中文名表覆盖枚举全集，新增枚举值不补表即红（无 SPEC）', () {
    // 兜底分支（`?? …wire` / `?? …name`）保证不会崩，但也保证「漏补表」不会
    // 崩 —— 只会在界面上悄悄退回英文。这条用例把「漏」挡在测试这一层。
    for (final ExecutionOperator value in ExecutionOperator.values) {
      expect(operatorLabels[value], isNotNull, reason: '算子 $value 没有中文名');
    }
    for (final StepPhase value in StepPhase.values) {
      expect(stepPhaseLabels[value], isNotNull, reason: '相位 $value 没有中文名');
    }
    for (final QuizType value in QuizType.values) {
      expect(quizTypeLabels[value], isNotNull, reason: '题型 $value 没有中文名');
    }
    for (final QuizJudge value in QuizJudge.values) {
      expect(quizJudgeLabels[value], isNotNull, reason: '判定方 $value 没有中文名');
    }
  });

  test('算子中文名与 SPEC-STEP-012 的表格逐字一致（SPEC-STEP-012）', () {
    // 规格表给的是「读 / 例 / 忆 / 练 / 讲 / 做」。这张表若另起一套译名，
    // 文档与界面就成了两套话 —— 而两边都「看起来像中文」，没人会去比。
    expect(operatorLabels[ExecutionOperator.read], '读');
    expect(operatorLabels[ExecutionOperator.example], '例');
    expect(operatorLabels[ExecutionOperator.recall], '忆');
    expect(operatorLabels[ExecutionOperator.practice], '练');
    expect(operatorLabels[ExecutionOperator.explain], '讲');
    expect(operatorLabels[ExecutionOperator.doStep], '做');
  });
}
