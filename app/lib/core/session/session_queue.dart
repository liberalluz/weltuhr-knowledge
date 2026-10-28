/// 修习队列 —— 「今天该学什么」的唯一入口（`SPEC-STEP-003` / `004`）。
///
/// ## 本笔只接一条源
///
/// `SPEC-STEP-003` 定三条入队源：体系序（新学）/ SRS 到期（保持）/ 缺口回补（检验）。
/// 本笔只接**体系序**。另两条的前提都还不存在 —— SRS 到期要 `fold` 产出 `due`
/// （归 `B6` 的 FSRS），缺口回补要 ⑤ 判出「前置缺」（本笔只走打卡分支，判不出未过）。
///
/// **不写空壳**：一个恒空的池子在界面上与「今天没有要复习的」长得一样，而后者是假话。
///
/// ## 前沿 = 前置全已过、自己未过
///
/// 候选集先按 `subtreeRoot` 圈定（`resolvePlanScope`），再取 `⪯` 前沿：全部
/// `required` 前置都在 `passed` 里。`recommended` 不构成门槛（`ADR-0005` 决策 4）。
///
/// ## 排序 = 层号升序，同层按 id
///
/// 层号取 `kahnLevels` 的 `φ`。同一层内谁先谁后没有语义，定成一个稳定序只是
/// 为了让同一份数据两次给出同一个队列 —— 与 `precedence.dart` 同一口径。
///
/// ## 队列里装的是「步骤」，不是 id
///
/// 这样 `SessionRun` 不必再拿一个 `PackContent` 才能推进，界面与测试都少一层
/// 依赖。条目在入队那一刻就把 `steps` 拷进来 —— 队列是一次性的快照，不随后续
/// 装载变化。
library;

import '../entities/entry.dart';
import '../entities/node.dart';
import '../graph/levels.dart';
import '../graph/precedence.dart';
import '../pack/pack_reader.dart';
import '../plan/scope.dart';

/// 队列里的一项。**只装会话要用到的东西**。
class QueueItem {
  const QueueItem({
    required this.nodeId,
    required this.name,
    required this.estMinutes,
    required this.steps,
    required this.hasCriteria,
  });

  final String nodeId;
  final String name;

  /// 该项的预计分钟数。包内没写就是 0 —— 0 与「不知道」在求和上没有区别，
  /// 但界面上要按「未知」呈现，不能显示成「0 分钟」。
  final int estMinutes;

  /// 该项的步骤序列，已按包内顺序展开。
  final List<EntryStep> steps;

  /// 项末判据是否非空。空 = 打卡项 ⇒ 走 `SPEC-STEP-015` 的空判据分支，
  /// 跳过 ⑤ 直接记 `checked`。
  final bool hasCriteria;
}

/// 一条队列。
class SessionQueue {
  const SessionQueue({required this.subtreeRoot, required this.items});

  /// 队列的范围根。概览页要显示它 —— 同一份数据在不同根下给出不同队列。
  final String subtreeRoot;

  final List<QueueItem> items;

  int get length => items.length;

  bool get isEmpty => items.isEmpty;

  /// 预计总时长。**只累加已知的**：包内没写 `estMinutes` 的项不进分母，
  /// 否则「未知」会被当成「0 分钟」把总量算小。
  int get knownMinutes {
    int sum = 0;
    for (final QueueItem item in items) {
      sum += item.estMinutes;
    }
    return sum;
  }

  /// 预计时长「读得出」的项数。与 [knownMinutes] 一起决定概览页怎么写 ——
  /// 一项都没写时长时，界面上不该出现「预计 0 分钟」。
  int get timedItems {
    int count = 0;
    for (final QueueItem item in items) {
      if (item.estMinutes > 0) {
        count += 1;
      }
    }
    return count;
  }
}

/// 建队列。纯函数：不读盘、不看时钟。
///
/// [passed] 来自 `fold(events).passed` —— 已学门槛只认事件，不另读一份表。
///
/// 没有 `entry` 的节点（结构节点）与没有步骤的项**不入队**：前者不是可学项，
/// 后者进会话会立刻「完成」，把分母灌水。
SessionQueue buildSessionQueue({
  required PackContent pack,
  required String subtreeRoot,
  required Set<String> passed,
}) {
  final PlanScope scope = resolvePlanScope(
    pack: pack,
    subtreeRoot: subtreeRoot,
    parents: pack.parents,
  );

  final Map<String, int> levels = kahnLevels(
    nodeIds: <String>[for (final LearnableNode node in scope.nodes) node.id],
    edges: pack.prerequisites,
  );

  final List<QueueItem> items = <QueueItem>[];
  for (final LearnableNode node in scope.nodes) {
    if (passed.contains(node.id)) {
      continue;
    }
    final NodeEntry? entry = pack.entryOf(node.id);
    if (entry == null || entry.steps.isEmpty) {
      continue;
    }
    final List<String> predecessors = requiredPredecessorsOf(
      nodeId: node.id,
      edges: pack.prerequisites,
    );
    if (!predecessors.every(passed.contains)) {
      continue;
    }
    items.add(
      QueueItem(
        nodeId: node.id,
        name: node.name,
        estMinutes: entry.estMinutes ?? 0,
        steps: List<EntryStep>.unmodifiable(entry.steps),
        hasCriteria: entry.criteria.isNotEmpty,
      ),
    );
  }

  items.sort((QueueItem a, QueueItem b) {
    final int byLevel = (levels[a.nodeId] ?? 0).compareTo(
      levels[b.nodeId] ?? 0,
    );
    return byLevel != 0 ? byLevel : a.nodeId.compareTo(b.nodeId);
  });

  return SessionQueue(
    subtreeRoot: subtreeRoot,
    items: List<QueueItem>.unmodifiable(items),
  );
}
