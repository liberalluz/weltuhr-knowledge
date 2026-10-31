import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/spike/sphere_shells.dart';

/// 同心球壳的用例。
///
/// 层数与半径比例是**结构判据**，不是观感参数：节点将来要落在这些壳上，
/// 半径比例错了，同层等距与层间距离这两件事就都不成立，而画面上只是
/// 「节点位置不太对」—— 没人看得出是错的。
///
/// **`TC-SPIKE-018` / `019` 已随经纬网格删除**（2026-10-31）：那两条测的是
/// `shellSegments()` 的线段数与端点半径，网格实现已整体移除，用例失去被测
/// 对象。壳本身仍成立，由 `017` / `020` 两条守。
void main() {
  test('TC-SPIKE-017 五层半径按固定倍数等比放大，且都在天球之内（ADR-0006 决策表·布局）', () {
    final List<double> radii = shellRadii();

    expect(radii.length, kShellCount);
    expect(radii.first, closeTo(kInnermostShellRadius, 1e-9));

    // 相邻两层的比值必须恒等于 kShellRadiusRatio —— 对数等比的定义就是这个。
    for (int i = 1; i < radii.length; i++) {
      expect(radii[i] / radii[i - 1], closeTo(kShellRadiusRatio, 1e-9));
      expect(radii[i], greaterThan(radii[i - 1]), reason: '层号越大越靠外');
    }

    // 最外层必须小于星空半径 100：节点在近处、星空在无穷远，这个层次不能反。
    expect(radii.last, lessThan(100));
  });

  test('TC-SPIKE-020 三轴深度按编目取 4/4/5，不为对称造层'
      '（无 SPEC：ADR-0006 决策表只写「同心球壳，半径按对数等比」，层数由编目深度决定）', () {
    expect(shellDepthForAxis('discipline'), 4);
    expect(shellDepthForAxis('major'), 4);
    expect(shellDepthForAxis('occupation'), 5);
    // 未知轴按最深给，不缩水 —— 缩水会让某个轴的点落到错的壳上。
    expect(shellDepthForAxis('unknown'), kShellCount);
    // 任何轴的深度都不得超过实际层数，否则节点会飘在壳外。
    for (final int depth in kAxisDepth.values) {
      expect(depth, lessThanOrEqualTo(kShellCount));
    }
  });
}
