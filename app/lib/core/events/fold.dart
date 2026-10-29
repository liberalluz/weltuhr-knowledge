/// `fold(events, asOf)` —— 唯一的状态派生入口（`SPEC-FND-010`）。
///
/// 铁律：**everything 都是派生值**。会话游标、已学门槛、笔记版本、下线标记
/// 都在这里算出来，不存在第二份可写状态表。凡是「既能从表读、又能从事件算」
/// 的东西，都是两份可能不一致的真相。
///
/// 本文件只折叠**事件直接决定**的东西。两处边界：
/// - `S` / `D` / `due` —— `B6` 笔 1 起**在这里折**：算法在 `core/srs/fsrs.dart`
///   一处，本文件只负责「按事件序把上一次的状态喂进去」。
/// - 掌握度与 `Plan` 的 `progress` / `sessions` —— 派生自判定与学过的项，归
///   `QUANT`（`B6` 笔 2 / 笔 3）；这里只折出**意图**（子树根 / 主序轴 / 包版本 /
///   源 / 体系 / 方法）。
library;

import '../entities/plan.dart';
import '../entities/state.dart';
import '../enums.dart';
import '../json.dart';
import '../srs/advance.dart';
import '../srs/fsrs.dart';
import 'event.dart';
import 'migration.dart';

/// `item_graded.payload` 里判「打卡式」的键（`event-types.md` §二 A）。
///
/// **只在这一处写字符串**：`ProgressKind` 枚举定义在 `core/session/session_events.dart`，
/// 事件层引它会把依赖倒成「事件 → 会话」，而会话本就依赖事件。
///
/// ⚠️ 判冻结**只认 `checkin`**，不认 `progressKind`：后者管「谁判」（系统 /
/// 自评），自评但有判据的项照样涨 `S`。把两者当成一件事，会让所有自评项冻结 ——
/// 而本项目的项末验收全部是自评。
const String _checkinKey = 'checkin';

/// 一节笔记折叠后的样子。
class FoldedNote {
  const FoldedNote({required this.version, required this.text});

  /// 该节的 `note_revised` 计数 —— **回滚也计数**，历史只增不删。
  final int version;

  /// 当前生效正文（回滚已解析成具体文本，不是「指向某个版本」的指针）。
  final String text;
}

/// 折叠结果。**全部只读**，且只由 [fold] 构造。
class FoldedState {
  FoldedState({
    required Map<String, int> cursors,
    required Set<String> passed,
    required Set<String> graduated,
    required Map<String, SrsState> srs,
    required Map<String, int> skipStreaks,
    required Map<String, Grade> lastGrade,
    required Map<String, int> consecutiveFails,
    required Set<String> retired,
    required Map<String, FoldedNote> notes,
    required List<CarryLink> carries,
    required List<MergeLink> merges,
    required Map<String, Plan> plans,
  }) : cursors = Map<String, int>.unmodifiable(cursors),
       passed = Set<String>.unmodifiable(passed),
       graduated = Set<String>.unmodifiable(graduated),
       srs = Map<String, SrsState>.unmodifiable(srs),
       skipStreaks = Map<String, int>.unmodifiable(skipStreaks),
       lastGrade = Map<String, Grade>.unmodifiable(lastGrade),
       consecutiveFails = Map<String, int>.unmodifiable(consecutiveFails),
       retired = Set<String>.unmodifiable(retired),
       notes = Map<String, FoldedNote>.unmodifiable(notes),
       carries = List<CarryLink>.unmodifiable(carries),
       merges = List<MergeLink>.unmodifiable(merges),
       plans = Map<String, Plan>.unmodifiable(plans);

  /// 空态：一条事件都没有时用它，不必特判。
  FoldedState.empty()
    : cursors = const <String, int>{},
      passed = const <String>{},
      graduated = const <String>{},
      srs = const <String, SrsState>{},
      skipStreaks = const <String, int>{},
      lastGrade = const <String, Grade>{},
      consecutiveFails = const <String, int>{},
      retired = const <String>{},
      notes = const <String, FoldedNote>{},
      carries = const <CarryLink>[],
      merges = const <MergeLink>[],
      plans = const <String, Plan>{};

  /// 项 → **下一步**的步骤序号。折叠规则：`max(已完成 stepIndex) + 1`。
  ///
  /// 不建 `SessionCursor` 表（`event-types.md` §三）。也**不因回退而减小**：
  /// 回到上一步重看是纯视图操作，不写事件，游标不动。
  final Map<String, int> cursors;

  /// 已学门槛。`item_passed` 一写即**不可撤销** —— 复习未过只降 `S`、提前
  /// `due`，进度分母不动（`event-types.md` §二 A 第 3 条）。
  final Set<String> passed;

  /// 已毕业（`S ≥ 180`）。状态转换**不可逆**。
  final Set<String> graduated;

  /// 项 → 记忆状态（`D` / `S` / `due` / `reps`）。
  ///
  /// **只有评过分的项才在这张表里**：`D` / `S` 首次评分才初始化
  /// （`entity-fields` §14）。没评过分的项没有 `D` 可写 —— 硬造一条会让
  /// 「没学过」与「学过但忘了」在读数上分不开。
  final Map<String, SrsState> srs;

  /// 项 → 连续跳过次数（`C-10`）。**全量，含没评过分的项**。
  ///
  /// 单独一张表而不是只塞进 [srs]：新学项被跳过时 `D` / `S` 还不存在，
  /// 而「连续跳过 3 次」的提示恰恰从第一次跳过就要开始数。
  /// ⚠️ 它与 `consecutiveFails` **不可互相折算** —— 「没敢做」与「做了没过」
  /// 是两件事（`entity-fields` §14），任何一边清零都不带动另一边。
  final Map<String, int> skipStreaks;

  /// 项 → 最近一次验收成绩。`item_skipped` **不写这里**（`C-11`）。
  final Map<String, Grade> lastGrade;

  /// 项 → 最近一段**连续「未过」**的次数（`SPEC-STEP-021` / `C-09`）。
  ///
  /// 「连续」定义在事件序列上：从最近一次判定往前数，遇到 `pass` / `proficient`
  /// 立刻归零，不引入时间窗 —— 所以跨会话天然成立。序列的定序与去重**沿用本
  /// 函数开头那套**（HLC + `id` 兜底、`seenIds` 去重），不另算一遍。
  ///
  /// 缺口本身**不写事件**：`STEP-021` 原文写「生成缺口事件」，但事件表里没有
  /// 这个类型，而「连续两次未过」已经能从 `item_graded` 数出来 —— 再记一条会让
  /// 同一件事有两份真相。（2026-10-28 裁定，`std.md` 修订历史同日记）
  final Map<String, int> consecutiveFails;

  /// 已在包升级中下线。**这些项的进度仍然保留** —— 孤儿项的事件全部保留，
  /// 只标「已下线」（`SPEC-FND-012`）。
  final Set<String> retired;

  /// 笔记，键由 [noteKey] 生成。
  final Map<String, FoldedNote> notes;

  /// 拆分账本（按事件时间序）。
  final List<CarryLink> carries;

  /// 合并账本（按事件时间序）。
  final List<MergeLink> merges;

  /// 计划，键 = 那份计划的 `plan_created` 事件 `id`（`plan_events.dart` 头部）。
  ///
  /// **同空间可并存多份**（`SPEC-PLAN-003`）—— 所以这里不能按 `spaceId` 做键，
  /// 否则第二份会把第一份覆盖掉，而「两份独立存在」恰好是验收向量本身。
  final Map<String, Plan> plans;

  // `plansOf(spaceId)` 已删：`Plan` 不持有 `spaceId`（信封字段，payload 不写），
  // 而 `fold(spaceId:)` 已经按信封过滤过 —— fold 之后再按空间筛，筛不出任何
  // 新东西，只会让人以为「计划自带空间归属」。

  /// 下一步步骤序号；没学过返回 `0`（= 第一步）。
  int cursorOf(String itemId) => cursors[itemId] ?? 0;

  bool isPassed(String itemId) => passed.contains(itemId);

  bool isGraduated(String itemId) => graduated.contains(itemId);

  bool isRetired(String itemId) => retired.contains(itemId);

  /// 某项的记忆状态；**没评过分返回 `null`** —— 不造一条 `D = 0` 的假状态，
  /// 那会让「没学过」在排序里混进「学得很差」。
  SrsState? srsOf(String itemId) => srs[itemId];

  int skipStreakOf(String itemId) => skipStreaks[itemId] ?? 0;

  /// 某节笔记；没写过返回 `null`（**不返回空对象**，否则「没笔记」与「空笔记」
  /// 分不开，`SPEC-FND-014` 要求缺失表现为空位）。
  FoldedNote? noteOf({required String? itemId, required String sectionKey}) =>
      notes[noteKey(itemId: itemId, sectionKey: sectionKey)];
}

/// 笔记的折叠键。`itemId` 为空 = 空间级自由笔记（`entity-fields` §8）。
///
/// 用 `\u0000` 分隔：`itemId` 与 `sectionKey` 都允许含连字符，
/// 用 `-` / `:` 之类会把「a-b + c」与「a + b-c」折叠成同一节。
String noteKey({required String? itemId, required String sectionKey}) =>
    '${itemId ?? ''}\u0000$sectionKey';

/// 折叠：按 `hlc` 全序重放事件，得到派生状态。
///
/// - [asOf] 给出时**只折到那一刻**（含），用于「回看某天」与增量重放；
/// - [spaceId] 给出时只折该空间的事件；
/// - [userId] 给出时只折该用户的事件。**同一设备切账号必须传它**，否则 A 的
///   进度会算进 B（`SPEC-ACC-014`）。不传 = 全量折，只用于迁移与导出 ——
///   那里要的是「这条事件存在过」，不是「谁的进度」。
///
/// 幂等：同一 `id` 的事件出现多次只算一次（`event-types.md` §一）。
/// **但「两台设备各学一遍同一项」是两个不同 `id`，都要重放** —— 你确实
/// 复习了两次，`S` 就该变长。
FoldedState fold(
  Iterable<Event> events, {
  Hlc? asOf,
  String? spaceId,
  String? userId,
}) {
  final List<Event> ordered = <Event>[];
  final Set<String> seenIds = <String>{};

  for (final Event event in events) {
    if (spaceId != null && event.spaceId != spaceId) {
      continue;
    }
    if (userId != null && event.userId != userId) {
      continue;
    }
    if (asOf != null && event.hlc.compareTo(asOf) > 0) {
      continue;
    }
    ordered.add(event);
  }

  // HLC 已保证全序；同 `(physical, counter, deviceId)` 的两条不同事件是
  // 发号器的 bug，但排序仍要确定 —— 用 `id` 兜底，别让 `List.sort`
  // 的稳定性成为事实上的定序依据。
  ordered.sort((Event a, Event b) {
    final int byHlc = a.hlc.compareTo(b.hlc);
    return byHlc != 0 ? byHlc : a.id.compareTo(b.id);
  });

  final Map<String, int> cursors = <String, int>{};
  final Set<String> passed = <String>{};
  final Set<String> graduated = <String>{};
  final Map<String, Grade> lastGrade = <String, Grade>{};
  final Map<String, int> consecutiveFails = <String, int>{};
  final Set<String> retired = <String>{};
  final Map<String, List<String>> noteTexts = <String, List<String>>{};
  final List<CarryLink> carries = <CarryLink>[];
  final List<MergeLink> merges = <MergeLink>[];
  final Map<String, Plan> plans = <String, Plan>{};

  /// 每份计划名下重放了几条事件 —— 版本号的**唯一**来源。
  ///
  /// 不读 payload 的 `version`：那是第二份计数，重传或乱序时必然与重放条数打架。
  final Map<String, int> planRevisions = <String, int>{};

  /// 评分累计器：`D` / `S` / 上次评分时刻 / 评分次数。
  /// 只有评过分的项才有条目（见 [FoldedState.srs] 的说明）。
  final Map<String, SrsAdvance> srsAcc = <String, SrsAdvance>{};

  /// 连续跳过次数。**含没评过分的项** —— 与 [FoldedState.skipStreaks] 同一本账。
  final Map<String, int> skipStreaks = <String, int>{};

  for (final Event event in ordered) {
    if (!seenIds.add(event.id)) {
      continue;
    }

    switch (event.type) {
      case EventType.stepCompleted:
        final String itemId = _requireItem(event);
        final int stepIndex = requireInt(event.payload, 'stepIndex');
        final int next = stepIndex + 1;
        final int current = cursors[itemId] ?? 0;
        if (next > current) {
          cursors[itemId] = next;
        }

      case EventType.itemGraded:
        final String gradedItem = _requireItem(event);
        final Grade grade = Grade.fromWire(
          requireString(event.payload, 'score'),
        );
        lastGrade[gradedItem] = grade;
        // 连续数：未过 +1，**任何非未过**（合格 / 熟练）清零。写成 else 而不是
        // 只判 `pass` —— 熟练同样意味着「这一次会了」。
        consecutiveFails[gradedItem] = grade == Grade.fail
            ? (consecutiveFails[gradedItem] ?? 0) + 1
            : 0;
        // `D` / `S`：三种分支（无历史 / 有历史 / 打卡冻结）收在 [advanceSrs]
        // 一处，与判分写入点共用同一份 —— 判分侧要凭新 `S` 决定写不写
        // `graduated`，各写一份就会出现两个 `S`。
        final bool checkin = event.payload[_checkinKey] == true;
        srsAcc[gradedItem] = advanceSrs(
          previous: srsAcc[gradedItem],
          grade: grade,
          at: event.at,
          checkedOnly: checkin,
        );
        // 评分就是「这次做了」—— 连续跳过到此为止。反向不成立：
        // 跳过不清零 `failCount`（两件事，见 [FoldedState.skipStreaks]）。
        skipStreaks[gradedItem] = 0;

      case EventType.itemPassed:
        passed.add(_requireItem(event));

      case EventType.itemSkipped:
        // 跳过：不写判定、不计 fail、不计已学（`C-11`）。
        // **但连续跳过要数** —— `C-10` 的「连续 3 次」提示从第一次跳过就要开始数，
        // 而新学项此时还没有 `D` / `S`，所以这笔账独立于 [FoldedState.srs]。
        final String skippedItem = _requireItem(event);
        skipStreaks[skippedItem] = (skipStreaks[skippedItem] ?? 0) + 1;

      case EventType.graduated:
        graduated.add(_requireItem(event));

      case EventType.planCreated:
        // `Plan` 的身份 = 这条事件的 id（不在 payload 里再写一份 `planId`）。
        final String planId = event.id;
        plans[planId] = _planFromEvent(
          event,
          id: planId,
          version: _bumpVersion(planRevisions, planId),
        );

      case EventType.planRevised:
        final String planId = requireString(event.payload, 'planId');
        if (!plans.containsKey(planId)) {
          // 不静默补建（`SPEC-FND-014`）：一条指向不存在计划的修订，回放出来
          // 会凭空多出一份「从没建过」的计划，比报错更难查。
          throw FormatException(
            '事件 `${event.id}` 的 `planId` 为 `$planId`，但该计划尚未创建',
          );
        }
        plans[planId] = _planFromEvent(
          event,
          id: planId,
          version: _bumpVersion(planRevisions, planId),
        );

      case EventType.stateCarried:
        carries.add(
          CarryLink.fromPayload(eventId: event.id, payload: event.payload),
        );

      case EventType.stateMerged:
        merges.add(
          MergeLink.fromPayload(eventId: event.id, payload: event.payload),
        );

      case EventType.itemRetired:
        // 信封 `itemId` 可为空（迁移类），故先看 payload。
        final Object? fromPayload = event.payload['itemId'];
        final String itemId = fromPayload is String
            ? fromPayload
            : _requireItem(event);
        retired.add(itemId);

      case EventType.noteRevised:
        _applyNoteRevision(event, noteTexts);
    }
  }

  final Map<String, FoldedNote> notes = <String, FoldedNote>{};
  for (final MapEntry<String, List<String>> entry in noteTexts.entries) {
    notes[entry.key] = FoldedNote(
      version: entry.value.length,
      text: entry.value.last,
    );
  }

  // `due` 在收尾处一次算：它是 `lastReviewAt + 反解(S)`，与事件序无关；
  // 每来一条事件就重算一遍会在回放中途留下半截时刻，而那个值没有任何消费者。
  final Map<String, SrsState> srs = <String, SrsState>{};
  for (final MapEntry<String, SrsAdvance> entry in srsAcc.entries) {
    final SrsAdvance acc = entry.value;
    srs[entry.key] = SrsState(
      itemId: entry.key,
      difficulty: acc.difficulty,
      stability: acc.stability,
      lastReviewAt: acc.lastReviewAt,
      due: fsrsDueAt(lastReviewAt: acc.lastReviewAt, stability: acc.stability),
      failCount: consecutiveFails[entry.key] ?? 0,
      reps: acc.reps,
      skipStreak: skipStreaks[entry.key] ?? 0,
    );
  }

  return FoldedState(
    cursors: cursors,
    passed: passed,
    graduated: graduated,
    srs: srs,
    skipStreaks: skipStreaks,
    lastGrade: lastGrade,
    consecutiveFails: consecutiveFails,
    retired: retired,
    notes: notes,
    carries: carries,
    merges: merges,
    plans: plans,
  );
}

/// 从一条计划类事件折出一份 `Plan`。
///
/// [id] 与 [version] 都由 `fold` 给 —— 前者是创建事件的 id，后者是重放条数。
/// **payload 里没有这两个字段**，它们不是事件携带的事实，是重放的副产物。
Plan _planFromEvent(Event event, {required String id, required int version}) =>
    Plan(
      id: id,
      // ⚠️ **不取信封的 `spaceId`**：`Plan` 已经没有这个字段了。计划的范围由
      // `subtreeRoot` 表达，而「属于哪个空间」是信封的事 —— `fold(spaceId:)` 已经
      // 按它过滤过，实体再存一份就是第二份真相（`event-types.md` §二 B：`spaceId`
      // 不进 payload）。
      subtreeRoot: requireString(event.payload, 'subtreeRoot'),
      primaryAxis: Axis.fromWire(requireString(event.payload, 'primaryAxis')),
      packVersions: PackVersions.fromJson(
        requireMap(event.payload, 'packVersions'),
      ),
      sourcePolicy: requireMap(event.payload, 'sourcePolicy'),
      schemeId: requireString(event.payload, 'schemeId'),
      methodProfileId: requireString(event.payload, 'methodProfileId'),
      version: version,
    );

int _bumpVersion(Map<String, int> counts, String planId) {
  final int next = (counts[planId] ?? 0) + 1;
  counts[planId] = next;
  return next;
}

/// 收一条 `note_revised`。
///
/// 「版本 = 该节事件计数」由这里保证；回滚（带 `targetVersion`）**追加**一条
/// 事件并把目标版本的正文重新记到新版本上，历史一条不删。
void _applyNoteRevision(Event event, Map<String, List<String>> noteTexts) {
  final String key = noteKey(
    itemId: event.itemId,
    sectionKey: requireString(event.payload, 'sectionKey'),
  );
  final List<String> texts = noteTexts.putIfAbsent(key, () => <String>[]);

  final Object? rawTarget = event.payload['targetVersion'];
  if (rawTarget == null) {
    texts.add(requireString(event.payload, 'text'));
    return;
  }

  final int target = rawTarget is int
      ? rawTarget
      : _badTargetVersion(event, rawTarget);
  if (target < 1 || target > texts.length) {
    throw FormatException(
      '事件 `${event.id}` 的 `targetVersion` 为 $target，该节当前只有 ${texts.length} 个版本',
    );
  }
  texts.add(texts[target - 1]);
}

Never _badTargetVersion(Event event, Object? raw) =>
    throw FormatException('事件 `${event.id}` 的 `targetVersion` 不是整数：$raw');

/// 需要 `itemId` 的事件若没有它，就是坏事件 —— **不补默认值**（`SPEC-FND-014`）。
String _requireItem(Event event) {
  final String? itemId = event.itemId;
  if (itemId == null) {
    throw FormatException(
      '事件 `${event.id}`（${eventTypeWireName(event.type)}）缺 `itemId`',
    );
  }
  return itemId;
}
