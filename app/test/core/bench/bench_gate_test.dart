import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/bench/bench_gate.dart';
import 'package:project_knowledge/core/constants.dart';

/// 开测闸门（`C-33`）：什么时候可以开始采样。
///
/// 这一组守的是「**装置什么时候开测**」，不是「读数怎么算」（后者在
/// `frame_stats_test.dart`）。两件事的错法不同：算法取平均会让数字变小，
/// 开测太早会让人以为「帧预算掉下来了」—— 后者更贵，因为它看起来像是结论。
///
/// 闸门有两个分支（窗口 / 耐心），所以**每个分支都得有一条只靠它才红的用例**：
/// 删掉窗口那半，`054` / `055` 红；删掉耐心那半，`056` 红。两个分支各红一条，
/// 才说明它们不是互相掩护的（`R-08` 同族：断言要落在两条实现路径的差集上）。
void main() {
  const Duration patience = Duration(seconds: 90);

  test('TC-INF-054 视口进基准就开测，不因为「已经等超时」再犹豫一轮（无 SPEC：口径 `C-33`）', () {
    // 刚进等待：窗口合规 ⇒ 立刻 start。
    expect(
      benchGate(
        width: frameBenchWidth,
        height: frameBenchHeight,
        waited: Duration.zero,
        patience: patience,
      ),
      BenchGate.start,
    );

    // 等满了：窗口**仍然合规** ⇒ 仍是 start，不是 timeout。
    // 这条断言是「先看窗口、再看耐心」这个顺序的唯一证据 —— 反过来写（先判耐心）
    // 时本条会红，而 `056` / `057` 照样绿。
    expect(
      benchGate(
        width: frameBenchWidth,
        height: frameBenchHeight,
        waited: patience,
        patience: patience,
      ),
      BenchGate.start,
    );
  });

  test('TC-INF-055 容差边界：1 px 内算同一个窗口，超过就等（无 SPEC：口径 `C-33`）', () {
    BenchGate at(double extra) => benchGate(
          width: frameBenchWidth + extra,
          height: frameBenchHeight,
          waited: Duration.zero,
          patience: patience,
        );

    expect(at(frameBenchWindowTolerance), BenchGate.start);
    // 只多半个 px 就越界 —— 边界两侧各判一次，否则「差值写死成 0」也能过前半条。
    expect(at(frameBenchWindowTolerance + 0.5), BenchGate.wait);
    // 只差高度这一维：宽正好。两个维度一起差的输入，只判宽的实现照样全绿。
    expect(
      benchGate(
        width: frameBenchWidth,
        height: frameBenchHeight + frameBenchWindowTolerance + 0.5,
        waited: Duration.zero,
        patience: patience,
      ),
      BenchGate.wait,
    );
  });

  test('TC-INF-056 耐心边界：差一点还在等，到点才照测（无 SPEC：口径 `C-33`）', () {
    BenchGate at(Duration waited) => benchGate(
          width: 1584,
          height: 875,
          waited: waited,
          patience: patience,
        );

    expect(at(patience - const Duration(milliseconds: 1)), BenchGate.wait);
    expect(at(patience), BenchGate.timeout);
  });

  test('TC-INF-057 同一视口下答案随等待时间单调前进，不回摆（无 SPEC：口径 `C-33`）', () {
    // 窗口一直是 `1584×875`：wait 只可能变成 timeout，不会再变回 wait。
    // 「越等越没指望」是这组数的语义，写成断言比写成注释有用 —— 回摆会让装置
    // 在超时之后又停下来等，而人不一定看得见。
    const List<Duration> waits = <Duration>[
      Duration.zero,
      Duration(seconds: 30),
      patience,
      Duration(seconds: 180),
    ];
    final List<BenchGate> gates = <BenchGate>[
      for (final Duration w in waits)
        benchGate(width: 1584, height: 875, waited: w, patience: patience),
    ];
    expect(gates, <BenchGate>[
      BenchGate.wait,
      BenchGate.wait,
      BenchGate.timeout,
      BenchGate.timeout,
    ]);
  });
}
