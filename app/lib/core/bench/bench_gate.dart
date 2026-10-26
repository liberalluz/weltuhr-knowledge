/// 开测闸门（`C-33`）：什么时候可以开始采样。
///
/// 装置原来的写法是「装完包就等 3 s，然后无条件开测」——3 s 是给渲染管线热身
/// 的，不是给人调窗口的。而 `C-33` 要求读数在 `1920×1080` 客户区下取，`premiseOk`
/// 由实测尺寸现算：窗口没进基准就开测，跑完只会得到一组**按 `C-32` 解释不了**的
/// 数（`R1` 的受控对照里，同一份内容在 `1584×875` 上是「余量 57%」、在基准窗口上
/// 是「占预算 88%」，两个结论不能互换）。
///
/// 所以开测前先问这一句，答案只有三种：
///
/// - [BenchGate.start] —— 视口已在基准窗口内，可以开始预热。
/// - [BenchGate.wait] —— 还没到基准，也没等到耐心上限，继续等（装置应当把当前
///   尺寸与剩余时间显示出来，否则等人的人不知道在等什么）。
/// - [BenchGate.timeout] —— 等到上限仍然不是基准。**照测，但读数标不可解释**：
///   宁可给一组「带前提标注的参考数」，也不让一次真机运行白跑。
///
/// ## 为什么单独一个文件
///
/// 它不是读数算法（[framePremiseOk] 判的是「这个尺寸算不算基准」，本模块判的是
/// 「现在该不该开始」）。两件事合在一起写，验「该不该等」就得起一个真实的
/// `State`；而开测时机的错法与算法的错法完全不同 —— 算法取平均会让数字变小，
/// 开测太早会让人以为「帧预算掉下来了」。
library;

import 'frame_stats.dart';

/// 开测闸门的答案。三态，缺一都不行：没有 [wait] 就只剩「要么测要么不测」，
/// 而调窗口这件事本来需要时间。
enum BenchGate {
  /// 视口已进基准窗口（`C-33`），可以开始预热。
  start,

  /// 还不是基准窗口，但没到耐心上限 —— 继续等。
  wait,

  /// 等到上限仍不是基准窗口 —— 照测，读数不可按 `C-32` 解释。
  timeout,
}

/// 现在该不该开测。
///
/// [waited] 是从「进入等待」到此刻的时长，[patience] 是愿意等多久。
/// **顺序即判据**：先看窗口，再看耐心 —— 窗口一旦进入基准就立刻开测，不因为
/// 「已经等超时了」再犹豫一轮。反过来会把「刚调好窗口」的那一次也判成超时。
BenchGate benchGate({
  required double width,
  required double height,
  required Duration waited,
  required Duration patience,
}) {
  if (framePremiseOk(width: width, height: height)) {
    return BenchGate.start;
  }
  if (waited >= patience) {
    return BenchGate.timeout;
  }
  return BenchGate.wait;
}
