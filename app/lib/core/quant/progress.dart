/// 空间进度 —— `QUANT` 的取数层（`B6` 笔 3）。
///
/// 「进度」在本仓分两种，本文件只做**空间进度**那一种：
/// - 空间进度（本文件）：已学项 / 圈内项，**离散分数、只增不减**（`QUANT-001`
///   `002` `003`）；
/// - 计划进度（**不在本文件**）：已完成段与当前循环轮次（`QUANT-013`），分段要
///   解析方法的步骤结构（`QUANT-014`），形态仍记 `TBD-11` —— 先把纯计数的这半
///   落下来，另一半等形态定。
///
/// 本文件只做取数，不做展示：比例怎么算、进度条怎么画归 `VIEW`。**刻意不返回
/// `double`**：`total == 0` 时 `0 / 0` 在语义上是「无从计算」而不是「0%」，两者
/// 在界面上该长得不一样；把那个决定留在唯一需要它的展示层，才不会两处对同一个
/// 空态给出不同说法。
///
/// 因此不引 Flutter，也不引 `FoldedState` —— 调用方给项集合与已学集即可，与
/// `mastery.dart` 同一分层。
library;

import '../entities/entry.dart';
import '../entities/node.dart';
import '../plan/scope.dart';

/// 三个计数。**两档分开给**（`QUANT-015`）：`verified` 有可观测判据、`checked`
/// 是打卡来的。合成一个百分比就等于把「读完了一遍」与「验过能讲出来」画成同一
/// 种进度，而这两者的可信度不同是事实、不是偏好。
typedef ProgressCounts = ({int verified, int checked, int total});

/// 空间进度 = 已学项 / 圈内项，按 `verified` 与 `checked` 分计。
///
/// 四条口径各对应一条裁定，写错任何一条都会让读数悄悄偏掉：
/// - **[scope] 的 `denominator` 原样取，不自己数**（`QUANT-002`）：分母是「范围
///   规模」，与体系覆盖度无关。自己数 `scope.nodes.length` 会把两处口径拆开 ——
///   一旦 `PlanScope` 将来对分母加了修正，这里会安静地不同步。
/// - **分子只数圈内项**：`passed` 里可能还留着换体系后落到线外的旧项，算进去会
///   让「已学」超过「总数」。
/// - **[passed] 是唯一判定源**（`QUANT-003`）：不拿 `S`、不拿掌握度判已学 ——
///   那两者会回落，用了就会让进度倒退，而进度按裁定是**永不倒退**的。同一项
///   出现多次也只计 1（`Set` 天然去重；多设备各学一遍同理，`QUANT-002` 补记）。
/// - **[entryOf] 判两档**：`criteria` 非空 = `verified`、空 = `checked`。取不到
///   entry 的项按 `checked` 计 —— 没有 entry 就没有判据，与 `criteria` 为空同归
///   「无观测」；按 `verified` 计会把打卡项冒充成可验证项，而这两档在界面上
///   是要分开显示的。
///
/// 圈内为空（还没选体系、或体系覆盖 0）返回 `(0, 0, 0)`，**不抛**。这与
/// `depthOf` 抛 `StateError` 的口径不同，别照着改：那里分母为 0 是**数据坏了**
/// （六格全不可外化，构建期该拒收），这里是**合法空态** —— 用户本来就可能还没选。
ProgressCounts progressOf({
  required PlanScope scope,
  required Set<String> passed,
  required NodeEntry? Function(String nodeId) entryOf,
}) {
  int verified = 0;
  int checked = 0;
  for (final LearnableNode node in scope.nodes) {
    if (!passed.contains(node.id)) {
      continue;
    }
    final NodeEntry? entry = entryOf(node.id);
    if (entry == null || entry.isCheckin) {
      checked++;
    } else {
      verified++;
    }
  }
  return (verified: verified, checked: checked, total: scope.denominator);
}
