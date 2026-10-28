/// 修习队列 —— 「今天该学什么」的唯一入口（`SPEC-STEP-003` / `004`）。
///
/// ## 本笔接两条源
///
/// `SPEC-STEP-003` 定三条入队源：体系序（新学）/ SRS 到期（保持）/ 缺口回补（检验）。
/// 当前接**两条**：体系序 + 缺口回补。SRS 到期仍缺 —— 它要 `fold` 产出 `due`
/// （归 `B6` 的 FSRS）。
///
/// **不写空壳**：一个恒空的池子在界面上与「今天没有要复习的」长得一样，而后者是假话。
///
/// ## 缺口项与新学项的入队条件不同
///
/// 新学项要求「前置全已过、自己未过」——它还没学过，前置不过就没法开始。缺口项
/// 两条都**不要求**：
/// - 不看 `passed`：它本可能是已学过的项，复习时连续未过 ⇒ 回补，`item_passed`
///   不可撤销但可以回补。
/// - 不看前置：缺口项自己往往就是别人的前置，把它挡住等于永远修不好那个缺口。
///
/// ## 排序 = 缺口在前，其后层号升序、同层按 id
///
/// 缺口排前面是因为它是「卡住后续的东西」：回补完才能解锁依赖它的项。同一组内
/// 谁先谁后没有语义，定成稳定序只是为了同一份数据两次给出同一个队列 —— 与
/// `precedence.dart` 同一口径。
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

/// 队列里的一项来自哪条源。
///
/// 只有两条源区分得出来：SRS 到期还没接（归 `B6`），接了再加第三值。
enum QueueItemKind {
  /// 体系序前沿 —— 从没学过、前置全过。
  newItem,

  /// 缺口回补 —— 连续未过达 `C-09` 的项，重跑修前置。
  gapFill,
}

/// 队列里的一项。**只装会话要用到的东西**。
class QueueItem {
  const QueueItem({
    required this.nodeId,
    required this.name,
    required this.estMinutes,
    required this.steps,
    required this.hasCriteria,
    this.kind = QueueItemKind.newItem,
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

  /// 这一项是被哪条源拉进来的。默认新学 —— 笔 1 的调用点与测试因此不用改。
  final QueueItemKind kind;

  bool get isGapFill => kind == QueueItemKind.gapFill;
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

  /// 缺口回补的项数。概览页只在它 > 0 时出「缺口」那一行。
  int get gapItems => items.where((QueueItem item) => item.isGapFill).length;

  /// 新学项数。概览页的「新学 M 项」读它 —— 不是 [length]，否则会把缺口项
  /// 算成新学，同一项在两个数里各算一次。
  int get newItems => items.length - gapItems;
}

/// 建队列。纯函数：不读盘、不看时钟。
///
/// [passed] 来自 `fold(events).passed` —— 已学门槛只认事件，不另读一份表。
/// [gaps] 来自 `gapItemIds(folded)`：连续未过达 `C-09` 的项，走缺口回补分支。
///
/// 没有 `entry` 的节点（结构节点）与没有步骤的项**不入队**：前者不是可学项，
/// 后者进会话会立刻「完成」，把分母灌水。缺口项同样受这一条约束 —— 一个在包里
/// 找不到步骤的缺口（包升级删了正文、事件还留着 id）不该出现在队列里，它会让
/// 「缺口 N 项」永远清不掉。
SessionQueue buildSessionQueue({
  required PackContent pack,
  required String subtreeRoot,
  required Set<String> passed,
  Set<String> gaps = const <String>{},
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
    // 缺口项优先判：它可能已 `passed`、也可能前置未过，两条新学的门都不适用。
    if (gaps.contains(node.id)) {
      final NodeEntry? gapEntry = pack.entryOf(node.id);
      if (gapEntry == null || gapEntry.steps.isEmpty) {
        continue;
      }
      items.add(
        QueueItem(
          nodeId: node.id,
          name: node.name,
          estMinutes: gapEntry.estMinutes ?? 0,
          steps: List<EntryStep>.unmodifiable(gapEntry.steps),
          hasCriteria: gapEntry.criteria.isNotEmpty,
          kind: QueueItemKind.gapFill,
        ),
      );
      continue;
    }
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
    final int byKind = _kindRank(a.kind).compareTo(_kindRank(b.kind));
    if (byKind != 0) {
      return byKind;
    }
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

/// 缺口排在最前。用具名函数而不是靠枚举声明顺序 —— 将来插第三类源时，
/// 声明顺序会变成一个没人注意的隐式判据。
int _kindRank(QueueItemKind kind) => kind == QueueItemKind.gapFill ? 0 : 1;
