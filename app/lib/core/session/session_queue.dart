/// 修习队列 —— 「今天该学什么」的唯一入口（`SPEC-STEP-003` / `004`）。
///
/// ## 三条源已全部接上
///
/// `SPEC-STEP-003` 定三条入队源：体系序（新学）/ SRS 到期（保持）/ 缺口回补（检验）。
/// 三条都在这里判 —— `due` 由 `fold` 的 `SrsState` 给（`B6` 笔 1 的 FSRS）。
///
/// **不写空壳**：一个恒空的池子在界面上与「今天没有要复习的」长得一样，而后者是假话。
///
/// ## 复习池的门槛是「学过 + 到期」，两条都要
///
/// - **只收 `passed` 过**：`STEP-003` 把第三条源叫「保持」，保持的前提是已经学过。
///   评过分但没过的项仍走体系序（前置全过才进）—— 否则「复习」会变成绕开前置的
///   后门：一项从没学会，却能因为评过两次分而跳过前置校验直接进队。
/// - **不看前置**：学过就是学过。前置后来被清零（那项自己进了缺口）不该把已学项
///   退回新学池 —— 退回只会让同一个前置阻挡整条链。
///
/// 打卡项（进度档 `checked`）**进**复习池：它们的 `S` 冻结在初值，`due` 照样会到
/// （约 3 天一轮）。不进的话，打卡项学过一次就再不复现 —— 那与「打卡」这个动作的
/// 本意相反。
///
/// ## 时钟是入参，不是 `DateTime.now()`
///
/// 队列是纯函数，本文件不读时钟。`now` 由调用方给：概览页注入当下，测试注入定值
/// —— 否则「今天到期」这句话会跟着跑测试的那一天漂移，用例就成了随机数。
///
/// ## 缺口项与新学项的入队条件不同
///
/// 新学项要求「前置全已过、自己未过」——它还没学过，前置不过就没法开始。缺口项
/// 两条都**不要求**：
/// - 不看 `passed`：它本可能是已学过的项，复习时连续未过 ⇒ 回补，`item_passed`
///   不可撤销但可以回补。
/// - 不看前置：缺口项自己往往就是别人的前置，把它挡住等于永远修不好那个缺口。
///
/// ## 排序 = 缺口在前，其后复习（逾期久者先），最后新学
///
/// 缺口排前面是因为它是「卡住后续的东西」：回补完才能解锁依赖它的项。复习排在新学
/// 之前是 `STEP-004` 的「逾期天数降序 → 复习池 → 新学池」：到期项是**已经在忘的**
/// 东西，新学项晚一天没有代价。同一组内谁先谁后没有语义，定成稳定序只是为了同一份
/// 数据两次给出同一个队列 —— 与 `precedence.dart` 同一口径。
///
/// ## 池上限只削池尾，两池各削各的
///
/// 用量由 `daily_quota.dart` 按「当天已判分」算出，本文件只把超出余量的项挡在队列外
/// 并数清楚挡了几项 —— 不说就成了静默截断，用户会以为今天只有这些。
///
/// **缺口不参与截断**：额度管两个池子，缺口是第三条源（`SPEC-STEP-003`）。截断只发生
/// 在池尾 —— `STEP-004` 已定好池内顺序，余量用完时先挡掉的本来就该是排在后面的。
///
/// ## 队列里装的是「步骤」，不是 id
///
/// 这样 `SessionRun` 不必再拿一个 `PackContent` 才能推进，界面与测试都少一层
/// 依赖。条目在入队那一刻就把 `steps` 拷进来 —— 队列是一次性的快照，不随后续
/// 装载变化。
library;

import '../entities/entry.dart';
import '../entities/node.dart';
import '../entities/state.dart';
import '../graph/levels.dart';
import '../graph/precedence.dart';
import '../pack/pack_reader.dart';
import '../plan/scope.dart';

/// 队列里的一项来自哪条源（`SPEC-STEP-003` 的三条）。
enum QueueItemKind {
  /// 体系序前沿 —— 从没学过、前置全过。
  newItem,

  /// 缺口回补 —— 连续未过达 `C-09` 的项，重跑修前置。
  gapFill,

  /// SRS 到期 —— 已学过且到了 `due`，保持。
  review,
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

  bool get isReview => kind == QueueItemKind.review;
}

/// 一条队列。
class SessionQueue {
  const SessionQueue({
    required this.subtreeRoot,
    required this.items,
    this.reviewDeferred = 0,
    this.newDeferred = 0,
  });

  /// 队列的范围根。概览页要显示它 —— 同一份数据在不同根下给出不同队列。
  final String subtreeRoot;

  final List<QueueItem> items;

  /// 因复习额度用满而顺延到明天的项数（`C-06`）。**不进 [items]**。
  final int reviewDeferred;

  /// 因新学额度用满而顺延到明天的项数（`C-07`）。**不进 [items]**。
  final int newDeferred;

  /// 两池合计顺延数。0 = 没有东西被挡住。
  int get deferredTotal => reviewDeferred + newDeferred;

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

  /// 到期待复习的项数。概览页只在它 > 0 时出「复习」那一行 —— 一个恒为 0 的
  /// 「复习 0 项」与「今天确实没有要复习的」在屏幕上长得一样，而后者是假话。
  int get reviewItems => items.where((QueueItem item) => item.isReview).length;

  /// 新学项数。概览页的「新学 M 项」读它 —— 不是 [length]，否则会把缺口项与
  /// 复习项都算成新学。
  ///
  /// **按类数而不是拿总长减**：将来加第四类源时，减法会把它静默算进新学，
  /// 而这里会保持不变（少算）。少算是显眼的，静默多算是查不出来的。
  int get newItems => items
      .where((QueueItem item) => item.kind == QueueItemKind.newItem)
      .length;
}

/// 建队列。纯函数：不读盘；时钟由 [now] 给，本函数不自己取。
///
/// [passed] 来自 `fold(events).passed` —— 已学门槛只认事件，不另读一份表。
/// [gaps] 来自 `gapItemIds(folded)`：连续未过达 `C-09` 的项，走缺口回补分支。
/// [srs] 来自 `fold(events).srs`：只有评过分的项才有条目，`due` 由 `C-03` 反解。
/// [now] 是「今天」。[`srs`] 里 `due ≤ now` 且已学过的项进复习池。
///
/// [reviewAllowance] / [newAllowance] 是今天还剩下的额度（`C-06` / `C-07` 减去
/// `dailyQuotaUsage` 算出的已用量），`null` = 不限。0 与 `null` 不是一回事：0 表示
/// 「今天这一池排满了」，队列里一条这一池的项都不会有，但 [SessionQueue.reviewDeferred]
/// （或 `newDeferred`）会说明有几项被挡下 —— 界面据此区分「排满了」与「本来就没有」。
///
/// 没有 `entry` 的节点（结构节点）与没有步骤的项**不入队**：前者不是可学项，
/// 后者进会话会立刻「完成」，把分母灌水。缺口项同样受这一条约束 —— 一个在包里
/// 找不到步骤的缺口（包升级删了正文、事件还留着 id）不该出现在队列里，它会让
/// 「缺口 N 项」永远清不掉。
SessionQueue buildSessionQueue({
  required PackContent pack,
  required String subtreeRoot,
  required Set<String> passed,
  required DateTime now,
  Set<String> gaps = const <String>{},
  Map<String, SrsState> srs = const <String, SrsState>{},
  int? reviewAllowance,
  int? newAllowance,
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

  /// 复习项的逾期天数。排序要它，但它不是队列内容（[QueueItem] 不装 `due`）——
  /// 界面只显示「复习 N 项」，装进去就成了没人读的字段。
  final Map<String, int> overdueDays = <String, int>{};
  final Map<String, DateTime> dueAt = <String, DateTime>{};

  final List<QueueItem> items = <QueueItem>[];
  for (final LearnableNode node in scope.nodes) {
    // 缺口项优先判：它可能已 `passed`、也可能前置未过，两条新学的门都不适用。
    // 它同时也可能到期 —— 那时**只记缺口**，一项不进两次队。
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
    final bool learned = passed.contains(node.id);
    // 复习：学过 + 到期，两条都要（见文件头）。不看前置 —— 学过就是学过。
    final SrsState? state = learned ? srs[node.id] : null;
    final bool due = state != null && !state.due.isAfter(now);
    if (due) {
      final NodeEntry? reviewEntry = pack.entryOf(node.id);
      if (reviewEntry == null || reviewEntry.steps.isEmpty) {
        continue;
      }
      overdueDays[node.id] = now.difference(state.due).inDays;
      dueAt[node.id] = state.due;
      items.add(
        QueueItem(
          nodeId: node.id,
          name: node.name,
          estMinutes: reviewEntry.estMinutes ?? 0,
          steps: List<EntryStep>.unmodifiable(reviewEntry.steps),
          hasCriteria: reviewEntry.criteria.isNotEmpty,
          kind: QueueItemKind.review,
        ),
      );
      continue;
    }
    if (learned) {
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
    // 复习池：逾期天数降序（`STEP-004`）。同逾期再按 `due` 升序 —— 只差几小时的
    // 两项 `.inDays` 相同，按 `due` 比才分得出谁更早到期；最后按 id 兜底定序。
    if (a.isReview && b.isReview) {
      final int byOverdue = (overdueDays[b.nodeId] ?? 0).compareTo(
        overdueDays[a.nodeId] ?? 0,
      );
      if (byOverdue != 0) {
        return byOverdue;
      }
      final int byDue = (dueAt[a.nodeId] ?? now).compareTo(
        dueAt[b.nodeId] ?? now,
      );
      if (byDue != 0) {
        return byDue;
      }
      return a.nodeId.compareTo(b.nodeId);
    }
    final int byLevel = (levels[a.nodeId] ?? 0).compareTo(
      levels[b.nodeId] ?? 0,
    );
    return byLevel != 0 ? byLevel : a.nodeId.compareTo(b.nodeId);
  });

  // 截断在排序之后做：池内顺序已定，先被挡掉的必须是排在后面的那些。
  final List<QueueItem> kept = <QueueItem>[];
  int reviewsKept = 0;
  int newItemsKept = 0;
  int reviewDeferred = 0;
  int newDeferred = 0;
  for (final QueueItem item in items) {
    switch (item.kind) {
      case QueueItemKind.gapFill:
        kept.add(item);
      case QueueItemKind.review:
        if (reviewAllowance != null && reviewsKept >= reviewAllowance) {
          reviewDeferred += 1;
        } else {
          reviewsKept += 1;
          kept.add(item);
        }
      case QueueItemKind.newItem:
        if (newAllowance != null && newItemsKept >= newAllowance) {
          newDeferred += 1;
        } else {
          newItemsKept += 1;
          kept.add(item);
        }
    }
  }

  return SessionQueue(
    subtreeRoot: subtreeRoot,
    items: List<QueueItem>.unmodifiable(kept),
    reviewDeferred: reviewDeferred,
    newDeferred: newDeferred,
  );
}

/// 三类源的先后：缺口 → 复习 → 新学。
///
/// 写成一张**显式的表**而不是 `switch` 返回序号：序号得写字面量，而 `R2` 只豁免
/// `0` / `1`；更要紧的是这张表本身就是判据 —— 读的人一眼看到顺序，不必去数
/// `switch` 的分支。
///
/// 缺口排在复习之前是 `STEP-021` 的「优先补前置」：缺口项是卡住别人的那个，
/// 而复习项只是自己在忘。
const List<QueueItemKind> _kindOrder = <QueueItemKind>[
  QueueItemKind.gapFill,
  QueueItemKind.review,
  QueueItemKind.newItem,
];

/// 三类都在 [_kindOrder] 里，`indexOf` 不会返回 -1。
int _kindRank(QueueItemKind kind) => _kindOrder.indexOf(kind);
