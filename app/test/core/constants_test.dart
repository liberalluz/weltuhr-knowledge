import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/errors.dart';

void main() {
  group('常量表（docs/reference/constants.md 的代码投影）', () {
    test('C-01 / C-02 记忆饱和常数与毕业阈值', () {
      expect(sZeroDays, 30);
      expect(graduationSDays, 180);
    });

    test('C-03 / C-25 为 2026-10-17 的裁定值', () {
      expect(fsrsTargetRetention, 0.90);
      expect(checkinCap, 0.5);
    });

    test('C-05…C-11 会话、配额与失败阈值', () {
      expect(sessionBudgetMinutes, 25);
      expect(reviewPoolCap, 20);
      expect(newPoolCap, 5);
      expect(failStreakToGap, 2);
      expect(skipStreakHint, 3);
      expect(skipEventsWritten, 0);
    });

    test('C-12 carryRatio = 1/n，且拒绝非法拆分数', () {
      expect(carryRatio(2), 0.5);
      expect(carryRatio(4), 0.25);
      expect(() => carryRatio(0), throwsArgumentError);
    });

    test('C-14…C-19 六类算子系数齐备且与枚举等长', () {
      expect(operatorMinutes.length, ExecutionOperator.values.length);
      expect(operatorMinutes[ExecutionOperator.read], 3);
      expect(operatorMinutes[ExecutionOperator.example], 2);
      expect(operatorMinutes[ExecutionOperator.recall], 1);
      expect(operatorMinutes[ExecutionOperator.practice], 5);
      expect(operatorMinutes[ExecutionOperator.teach], 5);
      expect(operatorMinutes[ExecutionOperator.build], 30);
    });

    test('C-20…C-23 界面阈值', () {
      expect(deepChainPhi, 5);
      expect(trailCap, 5);
      expect(viewTransitionMinMs, 180);
      expect(viewTransitionMaxMs, 220);
      expect(lodBrightnessFar, 3);
      expect(lodBrightnessNear, 7);
    });

    test('C-26 脚手架封顶到「合格」，熟练档关闭', () {
      expect(scaffoldCap, Grade.pass);
    });

    test('C-28 未裁定：读到即抛 TbdConstantError，而不是给默认值', () {
      expect(
        () => fuzzyMatchThreshold,
        throwsA(
          isA<TbdConstantError>().having((TbdConstantError e) => e.constantId, 'constantId', 'C-28'),
        ),
      );
    });
  });
}
