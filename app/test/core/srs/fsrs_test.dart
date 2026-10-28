import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/srs/fsrs.dart';

void main() {
  group('FSRS-5 纯函数（B6 笔 1）', () {
    test('TC-QUANT-010 三档映射到 1 / 3 / 4，没有 Hard 入口（SPEC-STEP-025）', () {
      expect(fsrsGradeOf(Grade.fail), 1);
      expect(fsrsGradeOf(Grade.pass), 3);
      expect(fsrsGradeOf(Grade.proficient), 4);
      // 表覆盖全部三档：漏一档会在取值时抛空断言，而那正是 runner 最热的路径。
      expect(fsrsGradeIndex.keys.toSet(), Grade.values.toSet());
    });

    test('TC-QUANT-011 初始稳定度按档位取 w0 / w2 / w3（C-98/C-100/C-101）', () {
      final ({double difficulty, double stability}) fail = fsrsInitial(
        Grade.fail,
      );
      final ({double difficulty, double stability}) pass = fsrsInitial(
        Grade.pass,
      );
      final ({double difficulty, double stability}) proficient = fsrsInitial(
        Grade.proficient,
      );
      expect(fail.stability, fsrsW0);
      expect(pass.stability, fsrsW2);
      expect(proficient.stability, fsrsW3);
      expect(proficient.stability, greaterThan(pass.stability));
      expect(pass.stability, greaterThan(fail.stability));
    });

    test('TC-QUANT-012 初始难度逆序：熟练 < 合格 < 未过，且落在 [1, 10]（SPEC-STEP-025）', () {
      final double fail = fsrsInitial(Grade.fail).difficulty;
      final double pass = fsrsInitial(Grade.pass).difficulty;
      final double proficient = fsrsInitial(Grade.proficient).difficulty;
      expect(proficient, lessThan(pass));
      expect(pass, lessThan(fail));
      for (final double value in <double>[fail, pass, proficient]) {
        expect(value, greaterThanOrEqualTo(fsrsDifficultyMin));
        expect(value, lessThanOrEqualTo(fsrsDifficultyMax));
      }
    });

    test('TC-QUANT-013 可提取率 t=0 为 1、随天数单调降、t=S 处恰为 0.9（SPEC-QUANT-005）', () {
      const double stability = 20;
      expect(
        fsrsRetrievability(stability: stability, elapsedDays: 0),
        closeTo(1, 1e-12),
      );
      // 目标保留率 0.90 落在 t = S 上：这是默认参数的自洽点，不是巧合。
      expect(
        fsrsRetrievability(stability: stability, elapsedDays: stability),
        closeTo(fsrsTargetRetention, 1e-12),
      );
      final double r10 = fsrsRetrievability(
        stability: stability,
        elapsedDays: 10,
      );
      final double r30 = fsrsRetrievability(
        stability: stability,
        elapsedDays: 30,
      );
      expect(r10, greaterThan(r30));
      // 负天数按 0 处理（时钟回拨不该让 `R` 超过 1）。
      expect(
        fsrsRetrievability(stability: stability, elapsedDays: -5),
        closeTo(1, 1e-12),
      );
      expect(
        () => fsrsRetrievability(stability: 0, elapsedDays: 1),
        throwsArgumentError,
      );
    });

    test('TC-QUANT-014 间隔反解退化到 t = S，且下界 1 天（C-03）', () {
      // r = 0.90 且 DECAY = −0.5 时，(r^(1/DECAY) − 1) 恰等于 FACTOR ⇒ 天数 = S。
      // 这条恒等式是断言而不是巧合：改 r 或 DECAY 任一个，它必须变红。
      expect(fsrsIntervalDays(stability: 10), closeTo(10, 1e-9));
      expect(fsrsIntervalDays(stability: 180), closeTo(180, 1e-9));
      // 反解出小数天时不排「今天学完今天到期」—— 脉动会在眼前闪一整天。
      expect(fsrsIntervalDays(stability: 0.1), 1);
      final DateTime lastReview = DateTime.utc(2026, 10, 28, 12);
      expect(
        fsrsDueAt(lastReviewAt: lastReview, stability: 10),
        lastReview.add(const Duration(days: 10)),
      );
    });

    test('TC-QUANT-015 同日复习走 w17 / w18，与隔天复习不是一个结果（SPEC-STEP-025）', () {
      final ({double difficulty, double stability}) base = fsrsInitial(
        Grade.proficient,
      );
      final ({double difficulty, double stability}) sameDay = fsrsNext(
        grade: Grade.proficient,
        difficulty: base.difficulty,
        stability: base.stability,
        elapsedDays: 0,
      );
      final ({double difficulty, double stability}) nextDay = fsrsNext(
        grade: Grade.proficient,
        difficulty: base.difficulty,
        stability: base.stability,
        elapsedDays: 1,
      );
      expect(sameDay.stability, greaterThan(base.stability));
      expect(nextDay.stability, greaterThan(base.stability));
      // 合成一支会让「刚学完再练一遍」看不到任何变化 —— 那正是 FSRS-4.5 的短板。
      expect(sameDay.stability, isNot(closeTo(nextDay.stability, 1e-6)));
    });

    test('TC-QUANT-016 打卡冻结：freeze 时 D / S 原样返回（SPEC-QUANT-007）', () {
      final ({double difficulty, double stability}) frozen = fsrsNext(
        grade: Grade.fail,
        difficulty: 6,
        stability: 12,
        elapsedDays: 30,
        freeze: true,
      );
      expect(frozen.difficulty, 6);
      expect(frozen.stability, 12);
    });

    test('TC-QUANT-017 难度始终夹在 [1, 10] 内（SPEC-STEP-025）', () {
      final double atMax = fsrsNext(
        grade: Grade.proficient,
        difficulty: fsrsDifficultyMax,
        stability: 1,
        elapsedDays: 0,
      ).difficulty;
      expect(atMax, lessThanOrEqualTo(fsrsDifficultyMax));
      final double afterForgot = fsrsNext(
        grade: Grade.fail,
        difficulty: fsrsDifficultyMin,
        stability: 1,
        elapsedDays: 90,
      ).difficulty;
      expect(afterForgot, greaterThanOrEqualTo(fsrsDifficultyMin));
      expect(afterForgot, lessThanOrEqualTo(fsrsDifficultyMax));
    });

    test('TC-QUANT-018 三档增量序：熟练 > 合格 > 未过（下降）（C-04）', () {
      const double difficulty = 5;
      const double stability = 10;
      final double pass = fsrsNext(
        grade: Grade.pass,
        difficulty: difficulty,
        stability: stability,
        elapsedDays: 1,
      ).stability;
      final double proficient = fsrsNext(
        grade: Grade.proficient,
        difficulty: difficulty,
        stability: stability,
        elapsedDays: 1,
      ).stability;
      final double fail = fsrsNext(
        grade: Grade.fail,
        difficulty: difficulty,
        stability: stability,
        elapsedDays: 1,
      ).stability;
      expect(pass, greaterThan(stability));
      expect(proficient, greaterThan(pass));
      // 未过必须真的往下压 —— 只「涨得少」等于遗忘没有代价。
      expect(fail, lessThan(stability));
    });
  });
}
